function [summary,coordinates] = archived_start_ranges(mcodeRoot)
%ARCHIVED_START_RANGES Componentwise extrema of the exact archived starts.

registry = problem_registry(mcodeRoot);
problem = strings(41,1);
legacyIndex = (1:41)';
dimension = zeros(41,1);
sourceFile = strings(41,1);
available = false(41,1);
overallMinimum = nan(41,1);
overallMaximum = nan(41,1);

totalCoordinates = sum([registry.n]);
coordinateProblem = strings(totalCoordinates,1);
coordinateLegacyIndex = zeros(totalCoordinates,1);
coordinateNumber = zeros(totalCoordinates,1);
minimum = nan(totalCoordinates,1);
maximum = nan(totalCoordinates,1);
coordinateSourceFile = strings(totalCoordinates,1);
coordinateAvailable = false(totalCoordinates,1);

cursor = 0;
for problemIndex = 1:numel(registry)
    prob = registry(problemIndex);
    problem(problemIndex) = string(prob.paper_label);
    dimension(problemIndex) = prob.n;
    sourceFile(problemIndex) = string(prob.source_file);
    available(problemIndex) = prob.initpoints_available;
    use = cursor+(1:prob.n);
    cursor = cursor+prob.n;
    coordinateProblem(use) = string(prob.paper_label);
    coordinateLegacyIndex(use) = prob.legacy_index;
    coordinateNumber(use) = (1:prob.n)';
    coordinateSourceFile(use) = string(prob.source_file);
    coordinateAvailable(use) = prob.initpoints_available;
    if prob.initpoints_available
        starts = load_initial_points(prob,mcodeRoot);
        minimum(use) = min(starts,[],2);
        maximum(use) = max(starts,[],2);
        overallMinimum(problemIndex) = min(starts,[],'all');
        overallMaximum(problemIndex) = max(starts,[],'all');
    end
end

summary = table(problem,legacyIndex,dimension,sourceFile,available, ...
    overallMinimum,overallMaximum, ...
    'VariableNames',{'problem','legacy_index','dimension','source_file', ...
    'available','overall_minimum','overall_maximum'});
coordinates = table(coordinateProblem,coordinateLegacyIndex,coordinateNumber, ...
    minimum,maximum,coordinateSourceFile,coordinateAvailable, ...
    'VariableNames',{'problem','legacy_index','coordinate','minimum','maximum', ...
    'source_file','available'});
end
