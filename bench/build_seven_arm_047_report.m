function report = build_seven_arm_047_report(runs,iterations,maxProfilePoints)
%BUILD_SEVEN_ARM_047_REPORT Compute every exchange-047 reduction in memory.

if nargin < 3, maxProfilePoints = 300; end
tables = seven_arm_047_tables(runs,iterations);
profiles = seven_arm_047_profiles(runs,maxProfilePoints);
frontQuality = full_campaign_front_quality(runs);
frontMetrics = full_campaign_front_metrics(runs);
analyticFrontDistance = analytic_distance_summary(frontMetrics);
report = struct('tables',tables,'profiles',profiles, ...
    'front_quality',frontQuality,'front_metrics',frontMetrics, ...
    'analytic_front_distance',analyticFrontDistance, ...
    'styles',seven_arm_047_styles());
end

function output = analytic_distance_summary(rows)
rows = rows(rows.set_name=="E2",:);
methods = seven_arm_047_methods().display_name;
problems = zeros(numel(methods),1);
medianProblemMedian = NaN(numel(methods),1);
largestMaximum = NaN(numel(methods),1);
for m = 1:numel(methods)
    block = rows(rows.method==methods(m),:);
    problems(m) = height(block);
    if ~isempty(block)
        medianProblemMedian(m) = median( ...
            block.median_reference_distance,'omitnan');
        largestMaximum(m) = max(block.maximum_reference_distance,[],'omitnan');
    end
end
output = table(methods,problems,medianProblemMedian,largestMaximum, ...
    'VariableNames',{'method','problems', ...
    'median_problem_median_reference_distance', ...
    'largest_maximum_reference_distance'});
end
