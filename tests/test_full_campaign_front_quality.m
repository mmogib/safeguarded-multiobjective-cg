function tests = test_full_campaign_front_quality
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testHandComputedCoveragePurityAndSpread(testCase)
quality = full_campaign_front_quality(fixture_runs());

coverage = quality.coverage;
verifyEqual(testCase,coverage_value(coverage,"A","B"),0.5, ...
    'AbsTol',1e-14);
verifyEqual(testCase,coverage_value(coverage,"B","A"),0.5, ...
    'AbsTol',1e-14);
verifyEqual(testCase,coverage_value(coverage,"A","C"),1, ...
    'AbsTol',1e-14);
verifyEqual(testCase,coverage_value(coverage,"C","A"),0, ...
    'AbsTol',1e-14);

perProblem = quality.per_problem;
verifyEqual(testCase,metric_value(perProblem,"A","purity_all"),1, ...
    'AbsTol',1e-14);
verifyEqual(testCase,metric_value(perProblem,"C","purity_all"),0, ...
    'AbsTol',1e-14);
verifyEqual(testCase,metric_value(perProblem,"A","gamma"),1, ...
    'AbsTol',1e-14);
verifyEqual(testCase,metric_value(perProblem,"A","delta"),0.5, ...
    'AbsTol',1e-14);
verifyEqual(testCase,metric_value(perProblem,"B","gamma"),2, ...
    'AbsTol',1e-14);
verifyEqual(testCase,metric_value(perProblem,"B","delta"),0, ...
    'AbsTol',1e-14);
verifyFalse(testCase,metric_value(perProblem,"C", ...
    "outside_reference_range"));

pairwise = quality.pairwise_purity;
verifyEqual(testCase,pairwise_value(pairwise,"A","B"),1, ...
    'AbsTol',1e-14);
verifyEqual(testCase,pairwise_value(pairwise,"A","C"),1, ...
    'AbsTol',1e-14);
verifyEqual(testCase,pairwise_value(pairwise,"C","A"),0, ...
    'AbsTol',1e-14);
end

function testEmptyAndSingletonFrontConventionsAreExplicit(testCase)
quality = full_campaign_front_quality(fixture_runs());

verifyTrue(testCase,isnan(coverage_value(quality.coverage,"A","D")));
verifyEqual(testCase,coverage_value(quality.coverage,"D","A"),0);
verifyTrue(testCase,isnan(metric_value(quality.per_problem,"D", ...
    "purity_all")));
verifyTrue(testCase,isnan(metric_value(quality.per_problem,"D","gamma")));
verifyTrue(testCase,isnan(metric_value(quality.per_problem,"C","delta")));
end

function testAggregatesWeightProblemsRatherThanFrontSizes(testCase)
runs = [fixture_runs(); second_problem_runs()];
quality = full_campaign_front_quality(runs);

row = quality.coverage_aggregate( ...
    quality.coverage_aggregate.source_method=="A" & ...
    quality.coverage_aggregate.target_method=="B",:);
verifyEqual(testCase,row.problems_defined,2);
verifyEqual(testCase,row.mean_coverage,0.75,'AbsTol',1e-14);
verifyEqual(testCase,row.median_coverage,0.75,'AbsTol',1e-14);
end

function testCoverageAggregateUsesCommonNonemptyFrontsInBothDirections(testCase)
runs = [fixture_runs(); second_problem_runs()];
quality = full_campaign_front_quality(runs);

forward = quality.coverage_aggregate( ...
    quality.coverage_aggregate.source_method=="A" & ...
    quality.coverage_aggregate.target_method=="D",:);
reverse = quality.coverage_aggregate( ...
    quality.coverage_aggregate.source_method=="D" & ...
    quality.coverage_aggregate.target_method=="A",:);

verifyEqual(testCase,forward.problems_defined,1);
verifyEqual(testCase,reverse.problems_defined,1);
verifyEqual(testCase,forward.mean_coverage,1,'AbsTol',1e-14);
verifyEqual(testCase,reverse.mean_coverage,0,'AbsTol',1e-14);
end

function testPurityAggregateUsesProblemsWithAllMethodFronts(testCase)
quality = full_campaign_front_quality( ...
    [fixture_runs();second_problem_runs()]);
rowA = quality.aggregate(quality.aggregate.method=="A",:);
rowD = quality.aggregate(quality.aggregate.method=="D",:);

verifyEqual(testCase,rowA.purity_problems_defined,1);
verifyEqual(testCase,rowD.purity_problems_defined,1);
verifyEqual(testCase,rowA.mean_purity_all,1,'AbsTol',1e-14);
verifyEqual(testCase,rowD.mean_purity_all,0,'AbsTol',1e-14);
end

function testSpreadAggregatesRequireAllMethodFronts(testCase)
quality = full_campaign_front_quality(fixture_runs());
row = quality.aggregate(quality.aggregate.method=="D",:);

verifyEqual(testCase,row.gamma_problems_compared,0);
verifyEqual(testCase,row.delta_problems_compared,0);
end

function testSpreadIsUndefinedWhenCommonExtremesDoNotBracketFront(testCase)
quality = full_campaign_front_quality(outside_fixture_runs());
perProblem = quality.per_problem;

verifyTrue(testCase,metric_value(perProblem,"C", ...
    "outside_reference_range"));
verifyEqual(testCase,metric_value(perProblem,"C", ...
    "max_reference_overshoot_ratio"),0.5,'AbsTol',1e-14);
verifyTrue(testCase,isnan(metric_value(perProblem,"C","gamma")));
verifyTrue(testCase,isnan(metric_value(perProblem,"C","delta")));
verifyTrue(testCase,all(isnan(perProblem.gamma_ratio)));
verifyTrue(testCase,all(isnan(perProblem.delta_ratio)));
end

function testWriterExportsLongAndMatrixArtifacts(testCase)
quality = full_campaign_front_quality(fixture_runs());
outputDir = tempname;
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>

write_full_campaign_front_quality(quality,outputDir);

expected = ["front_quality_per_problem.csv"; ...
    "front_coverage_per_problem.csv"; ...
    "front_coverage_matrices.csv"; ...
    "front_coverage_aggregate.csv"; ...
    "front_coverage_mean_matrix.csv"; ...
    "front_coverage_median_matrix.csv"; ...
    "front_pairwise_purity_per_problem.csv"; ...
    "front_pairwise_purity_aggregate.csv"; ...
    "front_quality_aggregate.csv"; ...
    "front_quality_definitions.txt"; ...
    "front_quality_report.mat"];
for k = 1:numel(expected)
    verifyTrue(testCase,isfile(fullfile(outputDir,expected(k))));
end

definitions = fileread(fullfile(outputDir,"front_quality_definitions.txt"));
verifySubstring(testCase,definitions, ...
    "Coverage means and medians use only problems on which both methods returned a non-empty front.");
verifySubstring(testCase,definitions, ...
    "Purity means and medians use only problems on which every reported method returned a non-empty front.");
verifySubstring(testCase,definitions, ...
    "Spread comparisons use only problems on which every reported method returned a non-empty front.");

matrixRows = readtable(fullfile(outputDir,"front_coverage_matrices.csv"), ...
    'TextType','string','VariableNamingRule','preserve');
verifyEqual(testCase,height(matrixRows),4);
verifyTrue(testCase,all(ismember(["to_A" "to_B" "to_C" "to_D"], ...
    string(matrixRows.Properties.VariableNames))));
end

function value = coverage_value(rows,source,target)
selected = rows.source_method==source & rows.target_method==target & ...
    rows.problem=="P1";
value = rows.coverage(selected);
end

function value = pairwise_value(rows,method,other)
selected = rows.method==method & rows.other_method==other & ...
    rows.problem=="P1";
value = rows.purity(selected);
end

function value = metric_value(rows,method,name)
selected = rows.method==method & rows.problem=="P1";
value = rows.(name)(selected);
end

function runs = fixture_runs()
problem = repmat("P1",7,1);
method = ["A";"A";"B";"B";"C";"D";"D"];
status = ["converged";"converged";"converged";"converged"; ...
    "converged";"line_search_failed";"line_search_failed"];
F_final = {[0;2];[1;1];[0;2];[2;0];[1.5;1.5];[4;4];[5;5]};
runs = table(problem,method,status,F_final);
end

function runs = outside_fixture_runs()
runs = fixture_runs();
runs.F_final{5} = [3;3];
end

function runs = second_problem_runs()
problem = repmat("P2",4,1);
method = ["A";"B";"C";"D"];
status = repmat("converged",4,1);
F_final = {[0;0];[1;1];[2;2];[3;3]};
runs = table(problem,method,status,F_final);
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
