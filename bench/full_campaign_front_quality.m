function quality = full_campaign_front_quality(runs)
%FULL_CAMPAIGN_FRONT_QUALITY Front-set measures from stored final images.
%   Only converged runs contribute. Dominance and equality are exact, and
%   every aggregate gives each problem equal weight.

problems = unique(runs.problem,'stable');
methods = unique(runs.method,'stable');
perProblem = table();
coverage = table();
pairwisePurity = table();

for p = 1:numel(problems)
    problem = problems(p);
    problemRows = runs(runs.problem==problem,:);
    successful = problemRows(problemRows.status=="converged",:);
    pooledFront = nondominated_rows(objective_matrix(successful.F_final));
    fronts = cell(numel(methods),1);

    for s = 1:numel(methods)
        selected = successful(successful.method==methods(s),:);
        fronts{s} = nondominated_rows(objective_matrix(selected.F_final));
        purity = set_fraction(fronts{s},pooledFront);
        [gamma,delta,outsideReference,maxOvershootRatio] = ...
            spread_metrics(fronts{s},pooledFront);
        perProblem = [perProblem;table(problem,methods(s), ...
            size(fronts{s},1),size(pooledFront,1),purity,gamma,delta, ...
            outsideReference,maxOvershootRatio, ...
            'VariableNames',{'problem','method','front_points', ...
            'reference_points','purity_all','gamma','delta', ...
            'outside_reference_range', ...
            'max_reference_overshoot_ratio'})]; %#ok<AGROW>
    end

    for source = 1:numel(methods)
        for target = 1:numel(methods)
            value = coverage_value(fronts{source},fronts{target});
            coverage = [coverage;table(problem,methods(source), ...
                methods(target),size(fronts{source},1), ...
                size(fronts{target},1),value,'VariableNames', ...
                {'problem','source_method','target_method', ...
                'source_points','target_points','coverage'})]; %#ok<AGROW>
            if source ~= target
                pairReference = nondominated_rows( ...
                    concatenate_points(fronts{source},fronts{target}));
                purity = set_fraction(fronts{source},pairReference);
                pairwisePurity = [pairwisePurity;table(problem, ...
                    methods(source),methods(target), ...
                    size(fronts{source},1),size(pairReference,1),purity, ...
                    'VariableNames',{'problem','method','other_method', ...
                    'front_points','reference_points','purity'})]; %#ok<AGROW>
            end
        end
    end
end

perProblem.gamma_ratio = profile_ratios(perProblem,'gamma');
perProblem.delta_ratio = profile_ratios(perProblem,'delta');
quality = struct( ...
    'per_problem',perProblem, ...
    'coverage',coverage, ...
    'coverage_aggregate',aggregate_coverage(coverage,methods), ...
    'pairwise_purity',pairwisePurity, ...
    'pairwise_purity_aggregate', ...
        aggregate_pairwise_purity(pairwisePurity,methods), ...
    'aggregate',aggregate_per_method(perProblem,methods));
end

function matrix = objective_matrix(values)
if isempty(values)
    matrix = zeros(0,0);
else
    matrix = cell2mat(cellfun(@(x) x(:)',values,'UniformOutput',false));
end
end

function combined = concatenate_points(left,right)
if isempty(left), combined = right; return; end
if isempty(right), combined = left; return; end
combined = [left;right];
end

function front = nondominated_rows(points)
if isempty(points), front = points; return; end
points = unique(points,'rows','stable');
keep = true(size(points,1),1);
for k = 1:size(points,1)
    dominated = all(points<=points(k,:),2) & any(points<points(k,:),2);
    dominated(k) = false;
    keep(k) = ~any(dominated);
end
front = points(keep,:);
end

function value = coverage_value(source,target)
if isempty(target), value = NaN; return; end
if isempty(source), value = 0; return; end
covered = false(size(target,1),1);
for k = 1:size(target,1)
    covered(k) = any(all(source<=target(k,:),2));
end
value = mean(covered);
end

function value = set_fraction(points,reference)
if isempty(points), value = NaN; return; end
if isempty(reference), value = 0; return; end
inReference = false(size(points,1),1);
for k = 1:size(points,1)
    inReference(k) = any(all(reference==points(k,:),2));
end
value = mean(inReference);
end

function [gamma,delta,outsideReference,maxOvershootRatio] = ...
    spread_metrics(points,reference)
if isempty(points) || isempty(reference)
    gamma = NaN;
    delta = NaN;
    outsideReference = false;
    maxOvershootRatio = NaN;
    return
end

n = size(points,1);
components = size(points,2);
lowerExtremes = min(reference,[],1);
upperExtremes = max(reference,[],1);
outsideReference = any(any(points<lowerExtremes | points>upperExtremes));
ranges = upperExtremes-lowerExtremes;
overshoots = max([lowerExtremes-min(points,[],1); ...
    max(points,[],1)-upperExtremes;zeros(1,components)],[],1);
ratios = zeros(1,components);
positiveRange = ranges>0;
ratios(positiveRange) = overshoots(positiveRange)./ranges(positiveRange);
ratios(~positiveRange & overshoots>0) = Inf;
maxOvershootRatio = max(ratios);
if outsideReference
    gamma = NaN;
    delta = NaN;
    return
end
gammaByComponent = zeros(components,1);
deltaByComponent = NaN(components,1);
for j = 1:components
    values = sort(points(:,j));
    lowerExtreme = lowerExtremes(j);
    upperExtreme = upperExtremes(j);
    endpointLower = abs(values(1)-lowerExtreme);
    endpointUpper = abs(upperExtreme-values(end));
    internal = diff(values);
    gammaByComponent(j) = max([endpointLower;internal;endpointUpper]);
    if n < 2, continue; end
    averageGap = mean(internal);
    denominator = endpointLower+endpointUpper+(n-1)*averageGap;
    if denominator == 0
        deltaByComponent(j) = 0;
    else
        deltaByComponent(j) = (endpointLower+endpointUpper+ ...
            sum(abs(internal-averageGap)))/denominator;
    end
end
gamma = max(gammaByComponent);
if n < 2
    delta = NaN;
else
    delta = max(deltaByComponent);
end
end

function ratios = profile_ratios(rows,metric)
ratios = NaN(height(rows),1);
for problem = unique(rows.problem,'stable')'
    selected = rows.problem==problem;
    if any(rows.front_points(selected)==0), continue; end
    if any(rows.outside_reference_range(selected)), continue; end
    values = rows.(metric)(selected);
    valid = isfinite(values);
    if ~any(valid), continue; end
    best = min(values(valid));
    current = Inf(size(values));
    if best == 0
        current(valid & values==0) = 1;
        current(valid & values>0) = Inf;
    else
        current(valid) = values(valid)/best;
    end
    ratios(selected) = current;
end
end

function result = aggregate_coverage(rows,methods)
result = table();
for source = 1:numel(methods)
    for target = 1:numel(methods)
        selected = rows.source_method==methods(source) & ...
            rows.target_method==methods(target) & ...
            rows.source_points>0 & rows.target_points>0;
        values = rows.coverage(selected);
        values = values(~isnan(values));
        result = [result;table(methods(source),methods(target), ...
            numel(values),mean_or_nan(values),median_or_nan(values), ...
            'VariableNames',{'source_method','target_method', ...
            'problems_defined','mean_coverage','median_coverage'})]; %#ok<AGROW>
    end
end
end

function result = aggregate_pairwise_purity(rows,methods)
result = table();
for method = 1:numel(methods)
    for other = 1:numel(methods)
        if method == other, continue; end
        selected = rows.method==methods(method) & ...
            rows.other_method==methods(other);
        values = rows.purity(selected);
        values = values(~isnan(values));
        result = [result;table(methods(method),methods(other), ...
            numel(values),mean_or_nan(values),median_or_nan(values), ...
            'VariableNames',{'method','other_method','problems_defined', ...
            'mean_purity','median_purity'})]; %#ok<AGROW>
    end
end
end

function result = aggregate_per_method(rows,methods)
problems = unique(rows.problem,'stable');
commonFrontProblems = strings(0,1);
for p = 1:numel(problems)
    selectedProblem = rows.problem==problems(p);
    if all(rows.front_points(selectedProblem)>0)
        commonFrontProblems(end+1,1) = problems(p); %#ok<AGROW>
    end
end

result = table();
for s = 1:numel(methods)
    selected = rows.method==methods(s);
    puritySelected = selected & ismember(rows.problem,commonFrontProblems);
    purity = rows.purity_all(puritySelected);
    gammaRatio = rows.gamma_ratio(selected);
    deltaRatio = rows.delta_ratio(selected);
    gammaCompared = gammaRatio(~isnan(gammaRatio));
    deltaCompared = deltaRatio(~isnan(deltaRatio));
    result = [result;table(methods(s), ...
        sum(~isnan(purity)),mean_or_nan(purity(~isnan(purity))), ...
        median_or_nan(purity(~isnan(purity))), ...
        numel(gammaCompared),fraction_equal_one(gammaCompared), ...
        fraction_finite(gammaCompared),median_or_nan(gammaCompared), ...
        numel(deltaCompared),fraction_equal_one(deltaCompared), ...
        fraction_finite(deltaCompared),median_or_nan(deltaCompared), ...
        'VariableNames',{'method','purity_problems_defined', ...
        'mean_purity_all','median_purity_all', ...
        'gamma_problems_compared','gamma_win_fraction', ...
        'gamma_finite_fraction','gamma_median_ratio', ...
        'delta_problems_compared','delta_win_fraction', ...
        'delta_finite_fraction','delta_median_ratio'})]; %#ok<AGROW>
end
end

function value = fraction_equal_one(values)
if isempty(values), value = NaN; else, value = mean(values==1); end
end

function value = fraction_finite(values)
if isempty(values), value = NaN; else, value = mean(isfinite(values)); end
end

function value = mean_or_nan(values)
if isempty(values), value = NaN; else, value = mean(values); end
end

function value = median_or_nan(values)
if isempty(values), value = NaN; else, value = median(values); end
end
