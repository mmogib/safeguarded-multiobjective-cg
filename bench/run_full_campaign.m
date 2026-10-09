function output = run_full_campaign(cfg,storeRoot)
%RUN_FULL_CAMPAIGN Resume, complete, and seal exchange-041 shared shards.

catalog = full_campaign_catalog(cfg.mcode_root);
if isfield(cfg,'problem_labels') && ~isempty(cfg.problem_labels)
    use = ismember(string({catalog.problem}),string(cfg.problem_labels));
    catalog = catalog(use);
    if numel(catalog) ~= numel(cfg.problem_labels)
        error('mcode:InvalidCampaignProblems', ...
            'Configured problem labels do not identify unique catalog rows.');
    end
end
manifestPath = fullfile(storeRoot,'campaign_manifest.json');
if ~isfile(manifestPath)
    error('campaignstore:MissingManifest','Campaign manifest is missing.');
end
stored = jsondecode(fileread(manifestPath));
chunkSize = double(stored.chunk_size);
campaignstore.initialize(storeRoot, ...
    full_campaign_manifest(cfg,chunkSize,catalog));
if isfile(fullfile(storeRoot,'archive_manifest.csv'))
    output = finish_output(storeRoot);
    return
end

start_pool(cfg.parallel_workers);
inventory = campaignstore.inspect(storeRoot);
completed = inventory.run_keys;
groups = trial_groups(cfg.trials,chunkSize);
for methodIndex = 1:numel(cfg.methods)
    method = cfg.methods{methodIndex};
    for entryIndex = 1:numel(catalog)
        entry = catalog(entryIndex);
        for groupIndex = 1:numel(groups)
            trials = groups{groupIndex};
            keys = strings(numel(trials),1);
            for q = 1:numel(trials)
                keys(q) = full_campaign_run_key(entry,method,trials(q));
            end
            present = ismember(keys,completed);
            if all(present), continue; end
            if any(present)
                error('mcode:PartialFrozenChunk', ...
                    'Frozen chunk %s/%s/%d-%d is only partially present.', ...
                    method,entry.problem,trials(1),trials(end));
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
            [runs,iterations,extras] = ...
                combine_full_campaign_payloads(payloads);
            blockKey = full_campaign_block_key( ...
                'run',method,entry.problem,trials);
            campaignstore.write_block( ...
                storeRoot,blockKey,runs,iterations,extras);
            completed = [completed;keys]; %#ok<AGROW>
            fprintf('campaign complete: %s %s starts %d-%d (%d/%d)\n', ...
                method,entry.problem,trials(1),trials(end), ...
                numel(completed),numel(stored.expected_run_keys));
        end
    end
end
if ~isempty(campaignstore.missing_keys(storeRoot))
    error('campaignstore:IncompleteCampaign', ...
        'Runner ended with missing manifest keys.');
end
output = finish_output(storeRoot);
end

function output = finish_output(storeRoot)
seal = campaignstore.seal(storeRoot);
inventory = campaignstore.inspect(storeRoot,true);
output = struct('seal',seal,'inventory',inventory,'store_root',storeRoot);
end

function payload = one_payload(entry,method,trial,cfg)
[payload.runs,payload.iterations,payload.extras] = ...
    build_full_campaign_payload(entry,method,trial,cfg);
end

function groups = trial_groups(trials,chunkSize)
if mod(numel(trials),chunkSize) ~= 0
    error('mcode:InvalidFrozenChunk', ...
        'Frozen chunk size must divide the configured trial count.');
end
groups = cell(1,numel(trials)/chunkSize);
for k = 1:numel(groups)
    groups{k} = trials((k-1)*chunkSize+(1:chunkSize));
end
end

function start_pool(workers)
if workers > 1 && isempty(gcp('nocreate'))
    parpool('Processes',workers);
end
end

