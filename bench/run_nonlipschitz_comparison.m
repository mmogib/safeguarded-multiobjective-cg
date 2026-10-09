function output = run_nonlipschitz_comparison(cfg)
%RUN_NONLIPSCHITZ_COMPARISON Run the authorized seven-arm E3 campaign.

validate_config(cfg);
ensure_folder(cfg.output_dir);
ensure_folder(cfg.line_trial_dir);
gateRows = load_gate(cfg.gate_source_file);
registry = nonlipschitz_problem_registry();
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
                [rowCells{q},trialCells{q}] = run_one(prob,starts(:,trial), ...
                    method,trial,cfg,gateRows);
            end
        else
            for q = 1:numel(pending)
                trial = pending(q);
                [rowCells{q},trialCells{q}] = run_one(prob,starts(:,trial), ...
                    method,trial,cfg,gateRows);
            end
        end
        blockRows = horzcat(rowCells{:});
        lineTrials = vertcat(trialCells{:});
        save_line_trial_block(cfg,prob,method,lineTrials);
        rows = [rows,blockRows]; %#ok<AGROW>
        save_checkpoint(cfg,rows);
        fprintf('E3 complete: %s %s (%d total rows)\n', ...
            method,prob.paper_label,numel(rows));
    end
end

output = struct('rows',rows,'line_trial_files', ...
    {completed_line_trial_files(rows,cfg)},'configuration',cfg);
end

function [row,trialRows] = run_one(prob,x0,method,trial,cfg,gateRows)
opts = experiment(method,cfg.mode);
if startsWith(method,'TTCG')
    opts.eta_bar = cfg.eta_bar;
end
opts.max_iter = cfg.max_iter;
started = tic;
result = solve_mocg_instrumented(prob,x0,opts);
wallTime = toc(started);
exposure = result.exposure;
event = result.diagnostics.no_descent_event;
if isempty(event)
    noDescentIteration = NaN; noDescentValue = NaN;
    noDescentSteepest = NaN; noDescentNormSquared = NaN;
else
    noDescentIteration = event.iteration;
    noDescentValue = event.directional_value;
    noDescentSteepest = event.steepest_directional_value;
    noDescentNormSquared = event.steepest_norm_squared;
end
rawBeta = result.diagnostics.raw_beta;
linduCorrection = result.diagnostics.lindu_correction_values;
row = struct('set_name',prob.set_name,'problem',prob.paper_label, ...
    'problem_index',prob.nonlipschitz_index,'method',method,'trial',trial, ...
    'gate_status',gate_status(prob,trial,gateRows), ...
    'status',result.status,'iterations',result.iterations, ...
    'theta',result.theta,'v_norm',result.v_norm, ...
    'steepest_directional_value',result.steepest_directional_value, ...
    'vector_F',result.counts.vector_F,'vector_J',result.counts.vector_J, ...
    'component_F',result.counts.component_F, ...
    'component_J',result.counts.component_J, ...
    'line_search_trials',result.diagnostics.line_search_trials, ...
    'qp_solves',result.diagnostics.qp_solves,'wall_time',wallTime, ...
    'evaluation_time',result.counts.evaluation_time, ...
    'qp_time',result.diagnostics.qp_time, ...
    'descent_violations',result.diagnostics.descent_violations, ...
    'no_descent_iteration',noDescentIteration, ...
    'no_descent_value',noDescentValue, ...
    'no_descent_steepest_value',noDescentSteepest, ...
    'no_descent_steepest_norm_squared',noDescentNormSquared, ...
    'qp_failures',result.diagnostics.qp_failures, ...
    'nonfinite_events',result.diagnostics.nonfinite_events, ...
    'max_direction_norm',result.diagnostics.max_direction_norm, ...
    'max_direction_over_v_norm', ...
    result.diagnostics.max_direction_over_v_norm, ...
    'max_abs_raw_beta',max_abs(rawBeta), ...
    'max_lindu_correction',max_abs(linduCorrection), ...
    'x',result.x,'F',result.F, ...
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
trialRows = pack_nonlipschitz_line_trials(prob,trial,exposure.line_trials);
end

function value = max_abs(values)
if isempty(values), value = NaN; else, value = max(abs(values)); end
end

function status = gate_status(prob,trial,gateRows)
if strcmp(prob.set_name,'E2')
    status = 'analytically_accessible';
    return
end
use = strcmp({gateRows.problem},prob.paper_label) & [gateRows.trial] == trial;
if sum(use) ~= 1
    error('mcode:MissingNonLipschitzGate', ...
        'Expected one gate row for %s trial %d.',prob.paper_label,trial);
end
status = gateRows(use).status;
end

function gateRows = load_gate(path)
if ~isfile(path)
    error('mcode:MissingNonLipschitzGate','Missing accepted 029 gate: %s',path);
end
loaded = load(path,'gateRows');
gateRows = loaded.gateRows;
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
        error('mcode:NonLipschitzComparisonCheckpointMismatch', ...
            'Existing E3 checkpoint configuration does not match.');
    end
    rows = loaded.rows;
else
    rows = struct([]);
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
    error('mcode:MissingNonLipschitzComparisonTrials', ...
        'Completed E3 block %s/%s has no line-trial table.',method,problem);
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
if ~ok, error('mcode:CheckpointWriteFailed','%s',message); end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function cfg = strip_paths(cfg)
cfg.output_dir = '';
cfg.checkpoint_file = '';
cfg.line_trial_dir = '';
cfg.gate_source_file = '';
end

function start_pool(workers)
if workers > 1 && isempty(gcp('nocreate'))
    parpool('Processes',workers);
end
end

function validate_config(cfg)
authorized = {'TTCGP','TTCGH','TTCGL','MOSD','PRP+','AVHZ+','TT-PRP1'};
if ~isequal(cfg.methods,authorized) || ~strcmp(cfg.mode,'paper_r2') || ...
        cfg.eta_bar ~= 1
    error('mcode:UnauthorizedNonLipschitzComparison', ...
        'Exchange 030 authorizes exactly seven fixed E3 arms.');
end
if any(cfg.problem_indices < 1 | cfg.problem_indices > 15) || ...
        any(cfg.trials < 1 | cfg.trials > 100)
    error('mcode:InvalidNonLipschitzComparison', ...
        'Invalid problem or trial index.');
end
end

function ensure_folder(path)
if ~isfolder(path), mkdir(path); end
end

