function output = run_campaign(cfg)
%RUN_CAMPAIGN Execute restartable method/problem/trial jobs.

validate_campaign(cfg);
manifest = make_manifest(cfg);
if isfile(cfg.output_file)
    saved = load(cfg.output_file, 'rows', 'manifest');
    if ~strcmp(saved.manifest.hash, manifest.hash)
        error('mcode:CheckpointHashMismatch', ...
            'Checkpoint hash %s does not match requested hash %s.', ...
            saved.manifest.hash, manifest.hash);
    end
    rows = saved.rows;
    manifest = saved.manifest;
else
    rows = empty_rows();
end

registry = problem_registry(cfg.mcode_root);
parallelWorkers = 1;
if isfield(cfg, 'parallel_workers')
    parallelWorkers = cfg.parallel_workers;
end
if parallelWorkers > 1 && isempty(gcp('nocreate'))
    parpool('Processes', parallelWorkers);
end
for jobIndex = 1:numel(cfg.jobs)
    job = cfg.jobs(jobIndex);
    for problemIndex = cfg.problem_indices
        prob = registry(problemIndex);
        starts = load_initial_points(prob, cfg.mcode_root);
        pending = cfg.trials(arrayfun(@(trial) ...
            ~row_exists(rows, job, prob, trial), cfg.trials));
        if isempty(pending)
            continue
        end
        blockCells = cell(1, numel(pending));
        if parallelWorkers > 1
            blockCells = run_parallel_trials(job, prob, pending, starts);
        else
            for pendingIndex = 1:numel(pending)
                trial = pending(pendingIndex);
                blockCells{pendingIndex} = run_one(job, prob, trial, ...
                    starts(:,trial));
            end
        end
        blockRows = vertcat(blockCells{:});
        rows = [rows; blockRows]; %#ok<AGROW>
        atomic_save(cfg.output_file, rows, manifest);
    end
end
output = struct('rows', rows, 'manifest', manifest);
end

function blockCells = run_parallel_trials(job, prob, pending, starts)
% One future per trial avoids stranding workers on static long-tail chunks.
blockCells = cell(1, numel(pending));
futures = parallel.FevalFuture.empty;
pool = gcp('nocreate');
for pendingIndex = 1:numel(pending)
    trial = pending(pendingIndex);
    futures(pendingIndex) = parfeval(pool, @run_one, 1, ...
        job, prob, trial, starts(:,trial));
end
cleanup = onCleanup(@() cancel(futures));
for completed = 1:numel(futures)
    [completedIndex, completedRow] = fetchNext(futures);
    blockCells{completedIndex} = completedRow;
end
delete(cleanup);
end

function row = run_one(job, prob, trial, x0)
opts = experiment(job.method, job.mode);
if ~isnan(job.eta)
    opts.eta_bar = job.eta;
end
started = tic;
runResult = solve_mocg(prob, x0, opts);
elapsed = toc(started);
row = make_row(job, prob, trial, runResult, elapsed, opts);
end

function validate_campaign(cfg)
required = {'mcode_root','output_file','jobs','problem_indices','trials'};
for k = 1:numel(required)
    if ~isfield(cfg, required{k})
        error('mcode:InvalidCampaign', 'Missing campaign field %s.', required{k});
    end
end
if any(cfg.problem_indices < 1 | cfg.problem_indices > 41)
    error('mcode:InvalidCampaign', 'Problem indices must lie in 1:41.');
end
if any(cfg.trials < 1 | cfg.trials > 100)
    error('mcode:InvalidCampaign', 'Trials must lie in 1:100.');
end
end

function manifest = make_manifest(cfg)
optim = ver('optim');
manifest = struct('schema_version', 5, 'hash', campaign_hash(cfg), ...
    'created_utc', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'matlab_version', version, 'optimization_toolbox_version', optim.Version, ...
    'configuration', cfg);
manifest.configuration = rmfield(manifest.configuration, 'output_file');
end

function yes = row_exists(rows, job, prob, trial)
if isempty(rows)
    yes = false;
    return
end
etaMatch = (isnan(rows.eta) & isnan(job.eta)) | rows.eta == job.eta;
yes = any(rows.mode == string(job.mode) & ...
    rows.method == string(job.method) & ...
    rows.legacy_index == prob.legacy_index & rows.trial == trial & etaMatch);
end

function row = make_row(job, prob, trial, result, elapsed, opts)
counts = result.counts;
legacy = result.legacy_counts;
diag = result.diagnostics;
noDescentIteration = NaN;
noDescentValue = NaN;
noDescentSteepestValue = NaN;
noDescentSteepestNormSquared = NaN;
if ~isempty(diag.no_descent_event)
    noDescentIteration = diag.no_descent_event.iteration;
    noDescentValue = diag.no_descent_event.directional_value;
    noDescentSteepestValue = ...
        diag.no_descent_event.steepest_directional_value;
    noDescentSteepestNormSquared = ...
        diag.no_descent_event.steepest_norm_squared;
end
lambdaDenom = numel(diag.lambda_values);
if lambdaDenom == 0
    lambdaRate = NaN;
else
    lambdaRate = diag.lambda_positive/lambdaDenom;
end
row = table(string(job.mode), string(job.method), string(prob.paper_label), ...
    prob.legacy_index, trial, job.eta, string(opts.derivative_mode), ...
    string(result.status), ...
    result.iterations, counts.vector_F, counts.vector_J, ...
    counts.component_F, counts.component_J, legacy.FeN, legacy.GeN, ...
    legacy.NV, diag.qp_solves, elapsed, counts.evaluation_time, diag.qp_time, ...
    lambdaRate, diag.lambda_positive, lambdaDenom, ...
    diag.lambda_denominator_fallbacks, {diag.lambda_values}, ...
    {diag.p_norm_values}, {diag.alignment_values}, diag.alignment_undefined, ...
    numel(diag.raw_beta), {diag.raw_beta}, {diag.truncated_beta}, ...
    {diag.clipped_beta}, diag.beta_denominator_fallbacks, ...
    diag.hs_beta_fallbacks, {diag.hs_beta_fallback_details}, ...
    diag.beta_truncations, ...
    diag.beta_clips, diag.descent_violations, noDescentIteration, ...
    noDescentValue, noDescentSteepestValue, ...
    noDescentSteepestNormSquared, diag.line_search_trials, ...
    sum(strcmp(diag.line_search_statuses,'ok')), ...
    sum(strcmp(diag.line_search_statuses,'max_trials')), ...
    sum(strcmp(diag.line_search_statuses,'min_step')), ...
    sum(strcmp(diag.line_search_statuses,'alphamax_unvalidated')), ...
    sum(strcmp(diag.line_search_statuses,'no_bracket')), ...
    sum(strcmp(diag.line_search_statuses,'budget_exhausted')), ...
    sum(ismember(diag.line_search_statuses, ...
        {'init_failed','no_bracket','budget_exhausted','failed'})), ...
    {diag.line_search_failure},diag.qp_failures,diag.nonfinite_events,{result.F}, ...
    'VariableNames', empty_rows().Properties.VariableNames);
end

function rows = empty_rows()
names = {'mode','method','problem','legacy_index','trial','eta', ...
    'derivative_mode','status', ...
    'iterations','vector_F','vector_J','component_F','component_J', ...
    'legacy_FeN','legacy_GeN','legacy_NV','qp_solves','wall_time','evaluation_time', ...
    'qp_time','lambda_positive_rate','lambda_positive_count','lambda_total', ...
    'lambda_denominator_fallbacks','lambda_values', ...
    'p_norm_values','alignment_values','alignment_undefined','beta_observations', ...
    'raw_beta','truncated_beta','clipped_beta','beta_denominator_fallbacks', ...
    'hs_beta_fallbacks','hs_beta_fallback_details', ...
    'beta_truncations','beta_clips','descent_violations', ...
    'no_descent_iteration','no_descent_value', ...
    'no_descent_steepest_value','no_descent_steepest_norm_squared', ...
    'line_search_trials', ...
    'line_search_ok','line_search_max_trials','line_search_min_step', ...
    'line_search_alphamax_unvalidated','line_search_no_bracket', ...
    'line_search_budget_exhausted','line_search_failed', ...
    'line_search_failure_detail','qp_failures','nonfinite_events','F'};
types = repmat({'double'}, 1, numel(names));
stringNames = {'mode','method','problem','derivative_mode','status'};
cellNames = {'lambda_values','p_norm_values','alignment_values','raw_beta', ...
    'truncated_beta','clipped_beta','hs_beta_fallback_details', ...
    'line_search_failure_detail','F'};
types(ismember(names,stringNames)) = ...
    repmat({'string'},1,sum(ismember(names,stringNames)));
types(ismember(names,cellNames)) = ...
    repmat({'cell'},1,sum(ismember(names,cellNames)));
rows = table('Size', [0 numel(names)], 'VariableTypes', types, ...
    'VariableNames', names);
end

function atomic_save(path, rows, manifest)
folder = fileparts(path);
if ~isfolder(folder)
    mkdir(folder);
end
temporary = [tempname(folder) '.mat'];
cleanup = onCleanup(@() delete_if_present(temporary));
save(temporary, 'rows', 'manifest', '-v7.3');
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('mcode:CheckpointWriteFailed', '%s', message);
end
delete(cleanup);
end

function delete_if_present(path)
if isfile(path)
    delete(path);
end
end
