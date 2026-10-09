function tests = test_heldout
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot,'bench'));
end

function testSummaryUsesConditionalMediansAndFailureAwareProfiles(testCase)
rows = synthetic_rows();

summary = summarize_heldout(rows,1);

use = summary.per_problem.arm=="TTCGP_eta1";
verifyEqual(testCase,summary.per_problem.successes(use),1);
verifyEqual(testCase,summary.per_problem.median_iterations(use),5);
verifyTrue(testCase,summary.per_problem.assca_compatible(use));

use = summary.profile_ratios.arm=="TTCGP_eta1" & ...
    summary.profile_ratios.metric=="iterations";
verifyEqual(testCase,summary.profile_ratios.ratio(use),[1;Inf]);
use = summary.profile_curves.arm=="TTCGP_eta1" & ...
    summary.profile_curves.metric=="iterations" & ...
    isinf(summary.profile_curves.tau);
verifyEqual(testCase,summary.profile_curves.proportion(use),0.5);

verifyEqual(testCase,summary.no_descent.directional_over_steepest,0.1, ...
    'AbsTol',1e-15);
verifyEqual(testCase,summary.no_descent.directional_over_norm_squared,0.1, ...
    'AbsTol',1e-15);
end

function testPairwiseComparisonUsesFrozenFailureConvention(testCase)
rows = synthetic_rows();

comparison = compare_heldout_arms(rows,'TTCGP',1,'MOSD',NaN,1);

use = comparison.aggregate.metric=="iterations";
verifyEqual(testCase,comparison.aggregate.left_successes(use),1);
verifyEqual(testCase,comparison.aggregate.right_successes(use),2);
verifyEqual(testCase,comparison.aggregate.paired_successes(use),1);
verifyEqual(testCase,comparison.aggregate.right_only_success(use),1);
verifyEqual(testCase,comparison.aggregate.both_failed(use),0);
verifyEqual(testCase,comparison.aggregate.geomean_left_over_right(use),0.5, ...
    'AbsTol',1e-15);
verifyEqual(testCase,comparison.aggregate.work_wins(use),1);

use = comparison.per_problem.metric=="iterations";
verifyEqual(testCase,comparison.per_problem.paired_successes(use),1);
verifyEqual(testCase,comparison.per_problem.geomean_left_over_right(use),0.5, ...
    'AbsTol',1e-15);
end

function rows = synthetic_rows()
method = ["MOSD";"MOSD";"TTCGP";"TTCGP"];
eta = [NaN;NaN;1;1];
problem = repmat("P1",4,1);
legacy_index = ones(4,1);
trial = [1;2;1;2];
status = ["converged";"converged";"converged";"no_descent"];
iterations = [10;20;5;8];
component_F = [100;200;50;80];
component_J = [30;60;15;24];
qp_solves = iterations;
wall_time = [1;2;0.5;0.8];
no_descent_iteration = [NaN;NaN;NaN;2];
no_descent_value = [NaN;NaN;NaN;0.2];
no_descent_steepest_value = [NaN;NaN;NaN;-2];
no_descent_steepest_norm_squared = [NaN;NaN;NaN;2];
rows = table(method,eta,problem,legacy_index,trial,status,iterations, ...
    component_F,component_J,qp_solves,wall_time,no_descent_iteration, ...
    no_descent_value,no_descent_steepest_value, ...
    no_descent_steepest_norm_squared);
end
