function summary = summarize_calibration(rows, candidates, selectionCandidates)
%SUMMARIZE_CALIBRATION Score calibration rows and aggregate diagnostics.

if nargin < 3
    selectionCandidates = candidates;
end

if any(rows.derivative_mode ~= "corrected")
    error('mcode:CalibrationLegacyJacobian', ...
        'Calibration rows must use corrected Jacobians throughout.');
end
if any(rows.descent_violations ~= 0)
    error('mcode:CalibrationA3Failed', ...
        'Paper-mode calibration contains f(x_k,d_k) >= 0.');
end

[scoreTable, selectedEta] = score_calibration( ...
    rows, candidates, selectionCandidates);
keys = unique(rows(:,{'method','eta'}), 'rows', 'stable');
diagnostics = empty_diagnostics(height(keys));
for keyIndex = 1:height(keys)
    use = rows.method == keys.method(keyIndex) & rows.eta == keys.eta(keyIndex);
    raw = flatten_cells(rows.raw_beta(use));
    truncated = flatten_cells(rows.truncated_beta(use));
    clipped = flatten_cells(rows.clipped_beta(use));
    diagnostics.method(keyIndex) = keys.method(keyIndex);
    diagnostics.eta(keyIndex) = keys.eta(keyIndex);
    diagnostics.runs(keyIndex) = sum(use);
    diagnostics.successes(keyIndex) = sum(rows.status(use) == "converged");
    diagnostics.wall_time(keyIndex) = sum(rows.wall_time(use));
    diagnostics.lambda_positive(keyIndex) = sum(rows.lambda_positive_count(use));
    diagnostics.lambda_total(keyIndex) = sum(rows.lambda_total(use));
    diagnostics.lambda_rate(keyIndex) = safe_ratio( ...
        diagnostics.lambda_positive(keyIndex), diagnostics.lambda_total(keyIndex));
    diagnostics.beta_observations(keyIndex) = sum(rows.beta_observations(use));
    diagnostics.raw_beta_min(keyIndex) = stat(raw, 'min');
    diagnostics.raw_beta_median(keyIndex) = stat(raw, 'median');
    diagnostics.raw_beta_max(keyIndex) = stat(raw, 'max');
    diagnostics.truncated_beta_min(keyIndex) = stat(truncated, 'min');
    diagnostics.truncated_beta_median(keyIndex) = stat(truncated, 'median');
    diagnostics.truncated_beta_max(keyIndex) = stat(truncated, 'max');
    diagnostics.clipped_beta_min(keyIndex) = stat(clipped, 'min');
    diagnostics.clipped_beta_median(keyIndex) = stat(clipped, 'median');
    diagnostics.clipped_beta_max(keyIndex) = stat(clipped, 'max');
    diagnostics.beta_truncations(keyIndex) = sum(rows.beta_truncations(use));
    diagnostics.beta_clips(keyIndex) = sum(rows.beta_clips(use));
    diagnostics.beta_clip_rate(keyIndex) = safe_ratio( ...
        diagnostics.beta_clips(keyIndex), diagnostics.beta_observations(keyIndex));
    diagnostics.beta_denominator_fallbacks(keyIndex) = ...
        sum(rows.beta_denominator_fallbacks(use));
    diagnostics.lambda_denominator_fallbacks(keyIndex) = ...
        sum(rows.lambda_denominator_fallbacks(use));
    diagnostics.descent_violations(keyIndex) = sum(rows.descent_violations(use));
    diagnostics.line_search_trials(keyIndex) = sum(rows.line_search_trials(use));
    diagnostics.line_search_ok(keyIndex) = sum(rows.line_search_ok(use));
    diagnostics.line_search_max_trials(keyIndex) = sum(rows.line_search_max_trials(use));
    diagnostics.line_search_min_step(keyIndex) = sum(rows.line_search_min_step(use));
    diagnostics.line_search_alphamax_unvalidated(keyIndex) = ...
        sum(rows.line_search_alphamax_unvalidated(use));
    diagnostics.line_search_failed(keyIndex) = sum(rows.line_search_failed(use));
    diagnostics.qp_failures(keyIndex) = sum(rows.qp_failures(use));
    diagnostics.nonfinite_events(keyIndex) = sum(rows.nonfinite_events(use));
end

problemKeys = unique(rows(:,{'method','eta','problem'}), 'rows', 'stable');
lambdaByProblem = problemKeys;
lambdaByProblem.lambda_positive = zeros(height(problemKeys),1);
lambdaByProblem.lambda_total = zeros(height(problemKeys),1);
lambdaByProblem.lambda_rate = nan(height(problemKeys),1);
for keyIndex = 1:height(problemKeys)
    use = rows.method == problemKeys.method(keyIndex) & ...
        rows.eta == problemKeys.eta(keyIndex) & ...
        rows.problem == problemKeys.problem(keyIndex);
    lambdaByProblem.lambda_positive(keyIndex) = sum(rows.lambda_positive_count(use));
    lambdaByProblem.lambda_total(keyIndex) = sum(rows.lambda_total(use));
    lambdaByProblem.lambda_rate(keyIndex) = safe_ratio( ...
        lambdaByProblem.lambda_positive(keyIndex), ...
        lambdaByProblem.lambda_total(keyIndex));
end

[group, method, eta, status] = findgroups(rows.method, rows.eta, rows.status);
count = splitapply(@numel, rows.status, group);
terminationReasons = table(method, eta, status, count, ...
    'VariableNames', {'method','eta','status','count'});
summary = struct('selected_eta', selectedEta, 'scores', scoreTable, ...
    'diagnostics', diagnostics, 'lambda_by_problem', lambdaByProblem, ...
    'termination_reasons', terminationReasons);
end

function output = flatten_cells(values)
if isempty(values)
    output = [];
else
    output = [values{:}];
end
end

function value = stat(values, operation)
if isempty(values)
    value = NaN;
else
    value = feval(operation, values);
end
end

function value = safe_ratio(numerator, denominator)
if denominator == 0
    value = NaN;
else
    value = numerator/denominator;
end
end

function diagnostics = empty_diagnostics(rowCount)
names = {'method','eta','runs','successes','wall_time', ...
    'lambda_positive','lambda_total','lambda_rate','beta_observations', ...
    'raw_beta_min','raw_beta_median','raw_beta_max', ...
    'truncated_beta_min','truncated_beta_median','truncated_beta_max', ...
    'clipped_beta_min','clipped_beta_median','clipped_beta_max', ...
    'beta_truncations','beta_clips','beta_clip_rate', ...
    'beta_denominator_fallbacks','lambda_denominator_fallbacks', ...
    'descent_violations','line_search_trials','line_search_ok', ...
    'line_search_max_trials','line_search_min_step', ...
    'line_search_alphamax_unvalidated','line_search_failed', ...
    'qp_failures','nonfinite_events'};
types = [{'string'}, repmat({'double'},1,numel(names)-1)];
diagnostics = table('Size',[rowCount numel(names)], ...
    'VariableTypes',types,'VariableNames',names);
end
