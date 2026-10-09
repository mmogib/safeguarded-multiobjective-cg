function metrics = full_campaign_front_metrics(runs)
%FULL_CAMPAIGN_FRONT_METRICS Exact E2 and labelled relative diagnostics.

records = table();
for problem = unique(runs.problem,'stable')'
    problemRows = runs(runs.problem==problem,:);
    successful = problemRows(problemRows.status=="converged",:);
    pooled = objective_matrix(successful.F_final);
    pooledFront = nondominated_rows(pooled);
    if startsWith(problem,"E2-")
        reference = exact_e2_front(problem);
        referenceType = "analytic_exact_front";
    else
        reference = pooledFront;
        referenceType = "pooled_union_relative";
    end
    for method = unique(problemRows.method,'stable')'
        selected = successful(successful.method==method,:);
        points = nondominated_rows(objective_matrix(selected.F_final));
        [medianDistance,maxDistance,spacing] = diagnostics(points,reference);
        records = [records;table(problemRows.tier(1), ...
            problemRows.set_name(1),problem,method,referenceType, ...
            height(selected),size(points,1),size(reference,1), ...
            medianDistance,maxDistance,spacing, ...
            'VariableNames',{'tier','set_name','problem','method', ...
            'reference_type','successful_points','nondominated_points', ...
            'reference_points','median_reference_distance', ...
            'maximum_reference_distance','normalized_spacing'})]; %#ok<AGROW>
    end
end
metrics = records;
end

function matrix = objective_matrix(values)
if isempty(values)
    matrix = zeros(0,0);
else
    matrix = cell2mat(cellfun(@(x) x(:)',values,'UniformOutput',false));
end
end

function front = exact_e2_front(problem)
u = linspace(-1,1,10001)';
if problem=="E2-5"
    front = [(u+1).^2,u.^2,(u-1).^2];
else
    front = [(u+1).^2,(u-1).^2];
end
end

function front = nondominated_rows(points)
if isempty(points), front = points; return; end
points = unique(points,'rows','stable');
keep = true(size(points,1),1);
for k = 1:size(points,1)
    dominates = all(points<=points(k,:),2) & any(points<points(k,:),2);
    dominates(k) = false;
    keep(k) = ~any(dominates);
end
front = points(keep,:);
end

function [medianDistance,maxDistance,spacing] = diagnostics(points,reference)
if isempty(points) || isempty(reference)
    medianDistance = NaN; maxDistance = NaN; spacing = NaN; return
end
scale = max(reference,[],1)-min(reference,[],1);
scale(scale==0) = 1;
normalizedPoints = points./scale;
normalizedReference = reference./scale;
distances = zeros(size(points,1),1);
for k = 1:size(points,1)
    distances(k) = min(vecnorm( ...
        normalizedReference-normalizedPoints(k,:),2,2));
end
medianDistance = median(distances);
maxDistance = max(distances);
if size(normalizedPoints,1)<2
    spacing = NaN;
else
    ordered = sortrows(normalizedPoints,1);
    gaps = vecnorm(diff(ordered,1,1),2,2);
    spacing = std(gaps)/max(mean(gaps),realmin);
end
end

