function summary = summarize_competitor_diagnostic(rows)
%SUMMARIZE_COMPETITOR_DIAGNOSTIC Count outcomes and non-descent events.

[overallGroup,overallMethod,overallStatus] = findgroups(rows.method,rows.status);
overallRuns = splitapply(@numel,rows.status,overallGroup);
overallStatusTable = table(overallMethod,overallStatus,overallRuns, ...
    'VariableNames',{'method','status','runs'});

[problemGroup,problemMethod,problemName,problemStatus] = ...
    findgroups(rows.method,rows.problem,rows.status);
problemRuns = splitapply(@numel,rows.status,problemGroup);
problemStatusTable = table(problemMethod,problemName,problemStatus,problemRuns, ...
    'VariableNames',{'method','problem','status','runs'});

methods = unique(rows.method,'stable');
events = zeros(numel(methods),1);
iterationMinimum = nan(numel(methods),1);
iterationMedian = nan(numel(methods),1);
iterationMaximum = nan(numel(methods),1);
valueMinimum = nan(numel(methods),1);
valueMedian = nan(numel(methods),1);
valueMaximum = nan(numel(methods),1);
for methodIndex = 1:numel(methods)
    use = rows.method==methods(methodIndex) & rows.status=="no_descent";
    events(methodIndex) = sum(use);
    if events(methodIndex) > 0
        iterations = rows.no_descent_iteration(use);
        values = rows.no_descent_value(use);
        iterationMinimum(methodIndex) = min(iterations);
        iterationMedian(methodIndex) = median(iterations);
        iterationMaximum(methodIndex) = max(iterations);
        valueMinimum(methodIndex) = min(values);
        valueMedian(methodIndex) = median(values);
        valueMaximum(methodIndex) = max(values);
    end
end
noDescent = table(methods,events,iterationMinimum,iterationMedian, ...
    iterationMaximum,valueMinimum,valueMedian,valueMaximum, ...
    'VariableNames',{'method','events','iteration_min','iteration_median', ...
    'iteration_max','value_min','value_median','value_max'});

summary = struct('overall_status',overallStatusTable, ...
    'problem_status',problemStatusTable,'no_descent',noDescent);
end
