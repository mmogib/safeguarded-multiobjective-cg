function summary = summarize_stage0(rows)
%SUMMARIZE_STAGE0 Aggregate the revised-direction diagnostic in exchange 010.

requiredMode = rows.mode == "paper_r2";
if any(~requiredMode) || any(rows.derivative_mode ~= "corrected")
    error('mcode:InvalidStage0Rows', ...
        'Stage 0 accepts only paper_r2 rows with corrected Jacobians.');
end
if any(rows.eta ~= 1)
    error('mcode:InvalidStage0Eta', 'Stage 0 requires eta_bar=1.');
end

byProblemMethod = aggregate_keys(rows, {'method','problem'});
byMethod = aggregate_keys(rows, {'method'});

methods = unique(rows.method, 'stable');
distributions = table(methods, 'VariableNames', {'method'});
statNames = {'n','min','q01','q05','median','q95','q99','max'};
families = {'lambda','p_norm','alignment'};
for familyIndex = 1:numel(families)
    for statIndex = 1:numel(statNames)
        distributions.([families{familyIndex} '_' statNames{statIndex}]) = ...
            nan(height(distributions),1);
    end
end
distributions.alignment_undefined = zeros(height(distributions),1);
for methodIndex = 1:height(distributions)
    use = rows.method == distributions.method(methodIndex);
    lambda = flatten_cells(rows.lambda_values(use));
    pNorm = flatten_cells(rows.p_norm_values(use));
    alignment = flatten_cells(rows.alignment_values(use));
    lambdaStats = distribution_stats(lambda);
    pStats = distribution_stats(pNorm);
    alignmentStats = distribution_stats(alignment);
    for statIndex = 1:numel(statNames)
        name = statNames{statIndex};
        distributions.(['lambda_' name])(methodIndex) = lambdaStats.(name);
        distributions.(['p_norm_' name])(methodIndex) = pStats.(name);
        distributions.(['alignment_' name])(methodIndex) = alignmentStats.(name);
    end
    distributions.alignment_undefined(methodIndex) = ...
        sum(rows.alignment_undefined(use));
end

[group, method, problem, status] = findgroups( ...
    rows.method, rows.problem, rows.status);
count = splitapply(@numel, rows.status, group);
terminationReasons = table(method,problem,status,count, ...
    'VariableNames',{'method','problem','status','count'});

summary = struct( ...
    'lambda_denominator_definition', ...
        'number of noninitial, nonterminal revised-direction constructions', ...
    'by_problem_method',byProblemMethod, ...
    'by_method',byMethod, ...
    'distributions',distributions, ...
    'termination_reasons',terminationReasons, ...
    'descent_violations',sum(rows.descent_violations), ...
    'hs_fallback_details',{collect_structs(rows.hs_beta_fallback_details)});
end

function output = aggregate_keys(rows, keyNames)
keys = unique(rows(:,keyNames), 'rows', 'stable');
output = keys;
numericNames = {'runs','successes','lambda_positive','lambda_total', ...
    'lambda_rate','line_search_ok','line_search_no_bracket', ...
    'line_search_budget_exhausted','line_search_other_failed', ...
    'hs_beta_fallbacks','alignment_undefined'};
for k = 1:numel(numericNames)
    output.(numericNames{k}) = zeros(height(keys),1);
end
for keyIndex = 1:height(keys)
    use = true(height(rows),1);
    for nameIndex = 1:numel(keyNames)
        name = keyNames{nameIndex};
        use = use & rows.(name) == keys.(name)(keyIndex);
    end
    output.runs(keyIndex) = sum(use);
    output.successes(keyIndex) = sum(rows.status(use) == "converged");
    output.lambda_positive(keyIndex) = sum(rows.lambda_positive_count(use));
    output.lambda_total(keyIndex) = sum(rows.lambda_total(use));
    output.lambda_rate(keyIndex) = safe_ratio( ...
        output.lambda_positive(keyIndex), output.lambda_total(keyIndex));
    output.line_search_ok(keyIndex) = sum(rows.line_search_ok(use));
    output.line_search_no_bracket(keyIndex) = sum(rows.line_search_no_bracket(use));
    output.line_search_budget_exhausted(keyIndex) = ...
        sum(rows.line_search_budget_exhausted(use));
    output.line_search_other_failed(keyIndex) = ...
        sum(rows.line_search_failed(use))-output.line_search_no_bracket(keyIndex) ...
        -output.line_search_budget_exhausted(keyIndex);
    output.hs_beta_fallbacks(keyIndex) = sum(rows.hs_beta_fallbacks(use));
    output.alignment_undefined(keyIndex) = sum(rows.alignment_undefined(use));
end
end

function stats = distribution_stats(values)
values = values(isfinite(values));
stats = struct('n',numel(values),'min',NaN,'q01',NaN,'q05',NaN, ...
    'median',NaN,'q95',NaN,'q99',NaN,'max',NaN);
if isempty(values)
    return
end
values = sort(values(:));
stats.min = values(1);
stats.q01 = empirical_quantile(values,0.01);
stats.q05 = empirical_quantile(values,0.05);
stats.median = empirical_quantile(values,0.5);
stats.q95 = empirical_quantile(values,0.95);
stats.q99 = empirical_quantile(values,0.99);
stats.max = values(end);
end

function value = empirical_quantile(sortedValues, probability)
position = 1+(numel(sortedValues)-1)*probability;
lower = floor(position);
upper = ceil(position);
weight = position-lower;
value = (1-weight)*sortedValues(lower)+weight*sortedValues(upper);
end

function output = flatten_cells(values)
if isempty(values)
    output = [];
else
    output = [values{:}];
end
end

function output = collect_structs(values)
output = struct('iteration',{},'denominator',{},'numerator',{}, ...
    'zero_tolerance',{},'policy',{});
for k = 1:numel(values)
    output = [output values{k}]; %#ok<AGROW>
end
end

function value = safe_ratio(numerator, denominator)
if denominator == 0
    value = NaN;
else
    value = numerator/denominator;
end
end
