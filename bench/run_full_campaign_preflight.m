function report = run_full_campaign_preflight(cfg)
%RUN_FULL_CAMPAIGN_PREFLIGHT Execute and package the frozen NC10 preflight.

validate_preflight_config(cfg);
ensure_folder(cfg.preflight_dir);
catalog = full_campaign_catalog(cfg.mcode_root);
selectedEntries = select_entries(catalog,cfg.preflight_problem_labels);
chunks = sort(cfg.chunk_candidates);
sourceChunk = chunks(1);
stores = strings(numel(chunks),1);
for k = 1:numel(chunks)
    stores(k) = fullfile(cfg.preflight_dir,"chunk_"+string(chunks(k)));
    campaignstore.initialize(stores(k), ...
        full_campaign_manifest(cfg,chunks(k),catalog));
end

start_pool(cfg.parallel_workers);
run_source_blocks(stores(1),sourceChunk,selectedEntries,cfg);
for k = 2:numel(chunks)
    repack_source_blocks(stores(1),sourceChunk,stores(k),chunks(k), ...
        selectedEntries,cfg);
end

summary = summarize_candidates(stores,chunks,cfg.parallel_workers);
selection = select_full_campaign_chunk(summary,cfg);
if selection.passed
    match = chunks==selection.selected_chunk;
    selection.store_root = char(stores(match));
else
    selection.store_root = '';
end
writetable(summary,fullfile(cfg.preflight_dir,'preflight_summary.csv'));
save(fullfile(cfg.preflight_dir,'preflight_report.mat'), ...
    'summary','selection','-v7.3');
report = struct('summary',summary,'selection',selection,'stores',stores);
end

function run_source_blocks(root,chunkSize,entries,cfg)
for methodIndex = 1:numel(cfg.methods)
    method = cfg.methods{methodIndex};
    for entryIndex = 1:numel(entries)
        entry = entries(entryIndex);
        groups = trial_groups(cfg.trials,chunkSize);
        for groupIndex = 1:numel(groups)
            trials = groups{groupIndex};
            blockKey = full_campaign_block_key('pf',method,entry.problem,trials);
            if isfile(fullfile(root,'blocks',['block_' blockKey '.mat']))
                continue
            end
            payloads = cell(1,numel(trials));
            if cfg.parallel_workers > 1
                parfor q = 1:numel(trials)
                    payloads{q} = one_payload(entry,method,trials(q),cfg);
                end
            else
                for q = 1:numel(trials)
                    payloads{q} = one_payload(entry,method,trials(q),cfg);
                end
            end
            [runs,iterations,extras] = combine_full_campaign_payloads(payloads);
            campaignstore.write_block(root,blockKey,runs,iterations,extras);
            fprintf('preflight computed: %s %s starts %d-%d\n', ...
                method,entry.problem,trials(1),trials(end));
        end
    end
end
end

function repack_source_blocks(sourceRoot,sourceChunk,targetRoot,targetChunk, ...
    entries,cfg)
ratio = targetChunk/sourceChunk;
if fix(ratio) ~= ratio
    error('mcode:InvalidChunkCandidates', ...
        'Every candidate must be a multiple of the smallest candidate.');
end
for methodIndex = 1:numel(cfg.methods)
    method = cfg.methods{methodIndex};
    for entryIndex = 1:numel(entries)
        entry = entries(entryIndex);
        targetGroups = trial_groups(cfg.trials,targetChunk);
        for groupIndex = 1:numel(targetGroups)
            trials = targetGroups{groupIndex};
            blockKey = full_campaign_block_key('pf',method,entry.problem,trials);
            if isfile(fullfile(targetRoot,'blocks',['block_' blockKey '.mat']))
                continue
            end
            sourceGroups = trial_groups(trials,sourceChunk);
            payloads = cell(1,numel(sourceGroups));
            for q = 1:numel(sourceGroups)
                sourceKey = full_campaign_block_key( ...
                    'pf',method,entry.problem,sourceGroups{q});
                path = fullfile(sourceRoot,'blocks',['block_' sourceKey '.mat']);
                loaded = load(path,'runs','iterations','extras');
                payloads{q} = loaded;
            end
            [runs,iterations,extras] = combine_full_campaign_payloads(payloads);
            campaignstore.write_block(targetRoot,blockKey,runs,iterations,extras);
        end
    end
end
end

function payload = one_payload(entry,method,trial,cfg)
[payload.runs,payload.iterations,payload.extras] = ...
    build_full_campaign_payload(entry,method,trial,cfg);
end

function summary = summarize_candidates(stores,chunks,workers)
n = numel(chunks);
chunkSize = chunks(:);
blockCount = zeros(n,1); runCount = zeros(n,1);
medianMiB = zeros(n,1); maxMiB = zeros(n,1);
maxLostWorkMinutes = zeros(n,1);
for k = 1:n
    inventory = campaignstore.inspect(stores(k),true);
    blockCount(k) = height(inventory.blocks);
    runCount(k) = sum(inventory.blocks.run_count);
    sizes = inventory.blocks.file_bytes/(1024^2);
    medianMiB(k) = median(sizes);
    maxMiB(k) = max(sizes);
    losses = zeros(height(inventory.blocks),1);
    for b = 1:height(inventory.blocks)
        loaded = load(inventory.blocks.path(b),'runs');
        losses(b) = greedy_makespan(loaded.runs.wall_time,workers)/60;
    end
    maxLostWorkMinutes(k) = max(losses);
end
summary = table(chunkSize,blockCount,runCount,medianMiB,maxMiB, ...
    maxLostWorkMinutes,'VariableNames',{'chunk_size','block_count', ...
    'run_count','median_mib','max_mib','max_lost_work_minutes'});
end

function value = greedy_makespan(times,workers)
loads = zeros(1,max(1,workers));
times = sort(times(:),'descend');
for k = 1:numel(times)
    [~,worker] = min(loads);
    loads(worker) = loads(worker)+times(k);
end
value = max(loads);
end

function entries = select_entries(catalog,labels)
use = ismember(string({catalog.problem}),string(labels));
entries = catalog(use);
if numel(entries) ~= numel(labels) || ...
        ~isequal(string({entries.problem}),string(labels))
    error('mcode:InvalidPreflightProblems', ...
        'Preflight labels must identify the frozen catalog entries in order.');
end
end

function groups = trial_groups(trials,chunkSize)
if mod(numel(trials),chunkSize) ~= 0
    error('mcode:InvalidChunkCandidates', ...
        'Chunk size must divide the number of trials.');
end
groups = cell(1,numel(trials)/chunkSize);
for k = 1:numel(groups)
    indices = (k-1)*chunkSize+(1:chunkSize);
    groups{k} = trials(indices);
end
end

function validate_preflight_config(cfg)
if isempty(cfg.chunk_candidates) || any(mod(numel(cfg.trials), ...
        cfg.chunk_candidates)~=0) || ...
        any(mod(cfg.chunk_candidates,cfg.chunk_candidates(1))~=0)
    error('mcode:InvalidChunkCandidates', ...
        'Candidates must divide the trial count and be nested.');
end
if any(~ismember(cfg.chunk_candidates,[1 2 4 5 10 20 25 50 100]))
    error('mcode:InvalidChunkCandidates','Unsupported chunk divisor.');
end
end

function start_pool(workers)
if workers > 1 && isempty(gcp('nocreate'))
    parpool('Processes',workers);
end
end

function ensure_folder(path)
if ~isfolder(path), mkdir(path); end
end
