function metrics = nonlipschitz_front_metrics(rows,outputDir)
%NONLIPSCHITZ_FRONT_METRICS Exact-front E2 and pooled-union NL10 diagnostics.

problems = unique(string({rows.problem}),'stable');
records = struct('set_name',{},'problem',{},'method',{}, ...
    'reference_type',{},'successful_points',{},'nondominated_points',{}, ...
    'reference_points',{},'median_reference_distance',{}, ...
    'maximum_reference_distance',{},'endpoint_gap_max',{}, ...
    'maximum_objective_gap',{},'normalized_spacing',{}, ...
    'union_contribution_fraction',{});
for problemIndex = 1:numel(problems)
    problem = problems(problemIndex);
    problemRows = rows(strcmp({rows.problem},problem));
    methods = unique(string({problemRows.method}),'stable');
    successful = problemRows(strcmp({problemRows.status},'converged'));
    pooled = objective_matrix(successful);
    pooledFront = nondominated_rows(pooled);
    if startsWith(problem,"E2-")
        reference = exact_e2_front(problem);
        referenceType = "analytic_exact_front";
    else
        reference = pooledFront;
        referenceType = "pooled_union_relative";
    end
    for methodIndex = 1:numel(methods)
        method = methods(methodIndex);
        selected = successful(strcmp({successful.method},method));
        points = objective_matrix(selected);
        methodFront = nondominated_rows(points);
        [medianDistance,maxDistance,endpointGap,maxGap,spacing] = ...
            reference_diagnostics(methodFront,reference);
        if isempty(methodFront)
            contribution = NaN;
        else
            contribution = mean(ismember(methodFront,pooledFront,'rows'));
        end
        records(end+1) = struct('set_name',problemRows(1).set_name, ...
            'problem',char(problem),'method',char(method), ...
            'reference_type',char(referenceType), ...
            'successful_points',size(points,1), ...
            'nondominated_points',size(methodFront,1), ...
            'reference_points',size(reference,1), ...
            'median_reference_distance',medianDistance, ...
            'maximum_reference_distance',maxDistance, ...
            'endpoint_gap_max',endpointGap, ...
            'maximum_objective_gap',maxGap, ...
            'normalized_spacing',spacing, ...
            'union_contribution_fraction',contribution); %#ok<AGROW>
    end
end
metrics = struct2table(records);
metrics.set_name = string(metrics.set_name);
metrics.problem = string(metrics.problem);
metrics.method = string(metrics.method);
metrics.reference_type = string(metrics.reference_type);
if nargin >= 2 && ~isempty(outputDir)
    writetable(metrics,fullfile(outputDir,'e3_front_metrics.csv'));
end
end

function matrix = objective_matrix(rows)
if isempty(rows)
    matrix = zeros(0,0);
else
    matrix = cell2mat(arrayfun(@(row) row.F(:)',rows,'UniformOutput',false)');
end
end

function front = exact_e2_front(problem)
u = linspace(-1,1,10001)';
if problem == "E2-5"
    front = [(u+1).^2,u.^2,(u-1).^2];
else
    front = [(u+1).^2,(u-1).^2];
end
end

function front = nondominated_rows(points)
if isempty(points)
    front = points;
    return
end
points = unique(points,'rows','stable');
keep = true(size(points,1),1);
for i = 1:size(points,1)
    dominates = all(points <= points(i,:),2) & any(points < points(i,:),2);
    dominates(i) = false;
    keep(i) = ~any(dominates);
end
front = points(keep,:);
end

function [medianDistance,maxDistance,endpointGap,maxGap,spacing] = ...
    reference_diagnostics(points,reference)
if isempty(points) || isempty(reference)
    medianDistance = NaN; maxDistance = NaN; endpointGap = NaN;
    maxGap = NaN; spacing = NaN;
    return
end
scale = max(reference,[],1)-min(reference,[],1);
scale(scale==0) = 1;
normalizedPoints = points./scale;
normalizedReference = reference./scale;
distances = zeros(size(points,1),1);
for i = 1:size(points,1)
    distances(i) = min(vecnorm(normalizedReference-normalizedPoints(i,:),2,2));
end
medianDistance = median(distances);
maxDistance = max(distances);

endpointDistances = zeros(1,size(reference,2));
objectiveGaps = zeros(1,size(reference,2));
spacingValues = NaN(1,size(reference,2));
for objective = 1:size(reference,2)
    [~,extremeIndex] = min(reference(:,objective));
    endpointDistances(objective) = min(vecnorm( ...
        normalizedPoints-normalizedReference(extremeIndex,:),2,2));
    values = sort(points(:,objective));
    referenceMin = min(reference(:,objective));
    referenceMax = max(reference(:,objective));
    gaps = [abs(values(1)-referenceMin);diff(values); ...
        abs(referenceMax-values(end))]/scale(objective);
    objectiveGaps(objective) = max(gaps);
    if numel(values) >= 2
        interior = diff(values)/scale(objective);
        average = mean(interior);
        d0 = abs(values(1)-referenceMin)/scale(objective);
        dN = abs(referenceMax-values(end))/scale(objective);
        denominator = d0+dN+(numel(values)-1)*average;
        if denominator > 0
            spacingValues(objective) = ...
                (d0+dN+sum(abs(interior-average)))/denominator;
        end
    end
end
endpointGap = max(endpointDistances);
maxGap = max(objectiveGaps);
spacing = max(spacingValues,[],'omitnan');
end

