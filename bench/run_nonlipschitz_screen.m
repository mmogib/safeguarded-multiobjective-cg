function output = run_nonlipschitz_screen(cfg)
%RUN_NONLIPSCHITZ_SCREEN Run only the authorized accessibility gate and E1.

validate_config(cfg);
ensure_folder(cfg.output_dir);
ensure_folder(cfg.line_trial_dir);
registry = nonlipschitz_problem_registry();

gradientReport = validate_nonlipschitz_gradients(registry(cfg.problem_indices));
if ~all(gradientReport.passed)
    error('mcode:NonLipschitzGradientValidation', ...
        'Non-Lipschitz gradient validation failed before the screen.');
end
[gateRows,projectionRows] = run_gate(registry,cfg);
save(cfg.gate_file,'gateRows','projectionRows','gradientReport','cfg','-v7.3');

rows = load_checkpoint(cfg);
start_pool(cfg.parallel_workers);
for methodIndex = 1:numel(cfg.methods)
    method = cfg.methods{methodIndex};
    for problemIndex = cfg.problem_indices
        prob = registry(problemIndex);
        starts = nonlipschitz_starts(prob);
        pending = cfg.trials(~arrayfun(@(trial) row_exists( ...
            rows,method,prob.paper_label,trial),cfg.trials));
        if isempty(pending)
            assert_block_trace_exists(cfg,method,prob.paper_label);
            continue
        end
        rowCells = cell(1,numel(pending));
        trialCells = cell(1,numel(pending));
        if cfg.parallel_workers > 1
            parfor q = 1:numel(pending)
                trial = pending(q);
                [rowCells{q},trialCells{q}] = run_one( ...
                    prob,starts(:,trial),method,trial,cfg);
            end
        else
            for q = 1:numel(pending)
                trial = pending(q);
                [rowCells{q},trialCells{q}] = run_one( ...
                    prob,starts(:,trial),method,trial,cfg);
            end
        end
        blockRows = horzcat(rowCells{:});
        lineTrials = vertcat(trialCells{:});
        save_line_trial_block(cfg,prob,method,lineTrials);
        rows = [rows,blockRows]; %#ok<AGROW>
        save_checkpoint(cfg,rows);
        fprintf('E1 complete: %s %s (%d total rows)\n', ...
            method,prob.paper_label,numel(rows));
    end
end

summary = summarize_nonlipschitz_screen(rows,gateRows,projectionRows,cfg.output_dir);
lineTrialFiles = completed_line_trial_files(rows,cfg);
output = struct('rows',rows,'line_trial_files',{lineTrialFiles},'gate_rows',gateRows, ...
    'projection_rows',projectionRows,'gradient_report',gradientReport, ...
    'summary',summary,'configuration',cfg);
end

function [gateRows,projectionRows] = run_gate(registry,cfg)
gateRows = empty_gate_rows();
projectionRows = empty_projection_rows();
for problemIndex = cfg.problem_indices
    prob = registry(problemIndex);
    starts = nonlipschitz_starts(prob);
    if strcmp(prob.set_name,'E2')
        for trial = cfg.trials
            witness = prob.pareto_projection(starts(:,trial));
            differences = prob.value(witness)-prob.value(starts(:,trial));
            projectionRows(end+1) = struct('problem',prob.paper_label, ...
                'trial',trial,'max_difference',max(differences), ...
                'singular_residual',abs(prob.singular_value(witness))); %#ok<AGROW>
        end
    else
        cells = cell(1,numel(cfg.trials));
        if cfg.parallel_workers > 1
            start_pool(cfg.parallel_workers);
            parfor q = 1:numel(cfg.trials)
                trial = cfg.trials(q);
                certificate = certify_nl10_accessibility(prob,starts(:,trial));
                cells{q} = gate_row(prob,trial,certificate);
            end
        else
            for q = 1:numel(cfg.trials)
                trial = cfg.trials(q);
                certificate = certify_nl10_accessibility(prob,starts(:,trial));
                cells{q} = gate_row(prob,trial,certificate);
            end
        end
        gateRows = [gateRows,horzcat(cells{:})]; %#ok<AGROW>
    end
end
end

function row = gate_row(prob,trial,certificate)
row = struct('problem',prob.paper_label,'trial',trial, ...
    'status',certificate.status,'best_upper_bound',certificate.best_upper_bound, ...
    'argument_id',certificate.argument_id,'witness',certificate.witness, ...
    'component_differences',certificate.component_differences, ...
    'search_evaluations',certificate.search_evaluations);
end

function [row,trialRows] = run_one(prob,x0,method,trial,cfg)
opts = experiment(method,cfg.mode);
opts.eta_bar = cfg.eta_bar;
opts.max_iter = cfg.max_iter;
result = solve_mocg_instrumented(prob,x0,opts);
exposure = result.exposure;
row = struct('set_name',prob.set_name,'problem',prob.paper_label, ...
    'problem_index',prob.nonlipschitz_index,'method',method,'trial',trial, ...
    'status',result.status,'iterations',result.iterations, ...
    'vector_F',result.counts.vector_F,'vector_J',result.counts.vector_J, ...
    's_0',exposure.s_0,'s_min_post0',exposure.s_min_post0, ...
    's_end',exposure.s_end,'d_0',exposure.d_0, ...
    'd_min_post0',exposure.d_min_post0,'d_end',exposure.d_end, ...
    'chi_0',exposure.chi_0,'chi_max_post0',exposure.chi_max_post0, ...
    'chi_end',exposure.chi_end,'s_contraction',exposure.s_contraction, ...
    'd_contraction',exposure.d_contraction, ...
    'accepted_post0_count',exposure.accepted_post0_count, ...
    's_band_counts',exposure.s_band_counts, ...
    'd_band_counts',exposure.d_band_counts, ...
    'chi_band_counts',exposure.chi_band_counts, ...
    'regular_exact_hits',exposure.regular_exact_hits, ...
    'degenerate_zeros',exposure.degenerate_zeros, ...
    'inner_stationary',exposure.inner_stationary, ...
    'unavailable_proxies',exposure.unavailable_proxies);
trialRows = flatten_trials(prob,method,trial,exposure.line_trials);
end

function rows = flatten_trials(prob,method,runTrial,records)
argumentMetadata = nonlipschitz_arguments(prob);
argumentIds = {argumentMetadata.argument_id};
n = numel(records);
run_trial = repmat(uint16(runTrial),n,1);
iteration = zeros(n,1,'uint16');
line_trial = zeros(n,1,'uint16');
alpha = zeros(n,1);
accepted = false(n,1);
s = NaN(n,1);
d = NaN(n,1);
chi = NaN(n,1);
s_argument_index = zeros(n,1,'uint8');
d_argument_index = zeros(n,1,'uint8');
chi_argument_index = zeros(n,1,'uint8');
distance_kind = zeros(n,1,'uint8');
regular_exact_hits = zeros(n,1,'uint8');
degenerate_zeros = zeros(n,1,'uint8');
inner_stationary = zeros(n,1,'uint8');
for k = 1:n
    observation = records(k).exposure;
    statuses = {observation.entries.status};
    iteration(k) = uint16(records(k).iteration);
    line_trial(k) = uint16(records(k).trial);
    alpha(k) = records(k).alpha;
    accepted(k) = records(k).accepted;
    s(k) = observation.s;
    d(k) = observation.d;
    chi(k) = observation.chi;
    s_argument_index(k) = argument_index(observation.s_argument_id,argumentIds);
    d_argument_index(k) = argument_index(observation.d_argument_id,argumentIds);
    chi_argument_index(k) = argument_index(observation.chi_argument_id,argumentIds);
    distance_kind(k) = distance_kind_code(observation.d_distance_kind);
    regular_exact_hits(k) = uint8(sum(strcmp(statuses,'regular_exact_hit')));
    degenerate_zeros(k) = uint8(sum(strcmp(statuses,'degenerate_zero')));
    inner_stationary(k) = uint8(sum(strcmp(statuses,'inner_stationary')));
end
rows = table(run_trial,iteration,line_trial,alpha,accepted,s,d,chi, ...
    s_argument_index,d_argument_index,chi_argument_index,distance_kind, ...
    regular_exact_hits,degenerate_zeros,inner_stationary);
end

function index = argument_index(argumentId,argumentIds)
index = find(strcmp(argumentIds,argumentId),1);
if isempty(index), index = 0; end
index = uint8(index);
end

function code = distance_kind_code(kind)
if strcmp(kind,'exact')
    code = uint8(1);
elseif strcmp(kind,'first_order_proxy')
    code = uint8(2);
else
    code = uint8(0);
end
end

function yes = row_exists(rows,method,problem,trial)
if isempty(rows)
    yes = false;
else
    yes = any(strcmp({rows.method},method) & strcmp({rows.problem},problem) & ...
        [rows.trial] == trial);
end
end

function rows = load_checkpoint(cfg)
if isfile(cfg.checkpoint_file)
    loaded = load(cfg.checkpoint_file,'rows','cfgSaved');
    if ~isequaln(strip_paths(loaded.cfgSaved),strip_paths(cfg))
        error('mcode:NonLipschitzCheckpointMismatch', ...
            'Existing checkpoint configuration does not match.');
    end
    rows = loaded.rows;
else
    rows = empty_screen_rows();
end
end

function save_checkpoint(cfg,rows)
cfgSaved = cfg;
temporary = [tempname(cfg.output_dir) '.mat'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
save(temporary,'rows','cfgSaved','-v7.3');
replace_file(temporary,cfg.checkpoint_file);
end

function save_line_trial_block(cfg,prob,method,lineTrials)
argumentMetadata = nonlipschitz_arguments(prob);
blockMetadata = struct('set_name',prob.set_name,'problem',prob.paper_label, ...
    'method',method,'argument_ids',{{argumentMetadata.argument_id}}, ...
    'distance_kind_codes',struct('unavailable',uint8(0),'exact',uint8(1), ...
    'first_order_proxy',uint8(2)),'storage_version',cfg.storage_version);
path = line_trial_path(cfg,method,prob.paper_label);
temporary = [tempname(cfg.line_trial_dir) '.mat'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
save(temporary,'lineTrials','blockMetadata','-v7.3');
replace_file(temporary,path);
end

function assert_block_trace_exists(cfg,method,problem)
if ~isfile(line_trial_path(cfg,method,problem))
    error('mcode:MissingNonLipschitzLineTrials', ...
        'Completed block %s/%s has no line-trial table.',method,problem);
end
end

function files = completed_line_trial_files(rows,cfg)
files = {};
for methodIndex = 1:numel(cfg.methods)
    method = cfg.methods{methodIndex};
    problems = unique({rows(strcmp({rows.method},method)).problem},'stable');
    for problemIndex = 1:numel(problems)
        files{end+1} = line_trial_path(cfg,method,problems{problemIndex}); %#ok<AGROW>
    end
end
end

function path = line_trial_path(cfg,method,problem)
path = fullfile(cfg.line_trial_dir,sprintf('line_trials_%s_%s.mat',method,problem));
end

function replace_file(source,target)
[ok,message] = movefile(source,target,'f');
if ~ok
    error('mcode:CheckpointWriteFailed','%s',message);
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function cfg = strip_paths(cfg)
cfg.output_dir = '';
cfg.checkpoint_file = '';
cfg.gate_file = '';
cfg.line_trial_dir = '';
end

function start_pool(workers)
if workers > 1 && isempty(gcp('nocreate'))
    parpool('Processes',workers);
end
end

function validate_config(cfg)
if ~isequal(cfg.methods,{'TTCGP','TTCGH','TTCGL'}) || ...
        ~strcmp(cfg.mode,'paper_r2') || cfg.eta_bar ~= 1
    error('mcode:UnauthorizedNonLipschitzArm', ...
        'Exchange 029 authorizes only TTCGP/TTCGH/TTCGL at eta_bar=1.');
end
if any(cfg.problem_indices < 1 | cfg.problem_indices > 15) || ...
        any(cfg.trials < 1 | cfg.trials > 100)
    error('mcode:InvalidNonLipschitzScreen','Invalid problem or trial index.');
end
end

function ensure_folder(path)
if ~isfolder(path), mkdir(path); end
end

function rows = empty_screen_rows()
rows = struct('set_name',{},'problem',{},'problem_index',{},'method',{}, ...
    'trial',{},'status',{},'iterations',{},'vector_F',{},'vector_J',{}, ...
    's_0',{},'s_min_post0',{},'s_end',{},'d_0',{},'d_min_post0',{}, ...
    'd_end',{},'chi_0',{},'chi_max_post0',{},'chi_end',{}, ...
    's_contraction',{},'d_contraction',{},'accepted_post0_count',{}, ...
    's_band_counts',{},'d_band_counts',{},'chi_band_counts',{}, ...
    'regular_exact_hits',{},'degenerate_zeros',{},'inner_stationary',{}, ...
    'unavailable_proxies',{});
end

function rows = empty_gate_rows()
rows = struct('problem',{},'trial',{},'status',{},'best_upper_bound',{}, ...
    'argument_id',{},'witness',{},'component_differences',{}, ...
    'search_evaluations',{});
end

function rows = empty_projection_rows()
rows = struct('problem',{},'trial',{},'max_difference',{}, ...
    'singular_residual',{});
end
