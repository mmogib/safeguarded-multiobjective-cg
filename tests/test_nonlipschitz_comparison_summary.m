function tests = test_nonlipschitz_comparison_summary
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'), ...
    fullfile(root,'config'),fullfile(root,'bench'));
end

function testFailureAwareProfilesUseInfinityAndExcludeCpu(testCase)
method = ["A";"B";"A";"B"];
problem = repmat("P1",4,1);
trial = [1;1;2;2];
status = ["converged";"converged";"converged";"no_descent"];
iterations = [10;5;8;4];
component_F = [20;10;16;8];
component_J = [6;4;5;3];
line_search_trials = [4;3;4;2];
qp_solves = [3;2;3;2];
wall_time = [100;1;100;1];
rows = table(method,problem,trial,status,iterations,component_F, ...
    component_J,line_search_trials,qp_solves,wall_time);

profiles = nonlipschitz_performance_profiles(rows);

verifyFalse(testCase,any(profiles.ratios.metric=="wall_time"));
use = profiles.ratios.method=="B" & profiles.ratios.trial==2 & ...
    profiles.ratios.metric=="iterations";
verifyEqual(testCase,profiles.ratios.ratio(use),Inf);
use = profiles.curves.method=="B" & ...
    profiles.curves.metric=="iterations" & profiles.curves.slice=="all" & ...
    isinf(profiles.curves.tau);
verifyEqual(testCase,profiles.curves.proportion(use),0.5);
verifyEqual(testCase,unique(profiles.curves.slice,'stable'),["all";"P1"]);
use = profiles.curves.method=="B" & ...
    profiles.curves.metric=="iterations" & profiles.curves.slice=="P1" & ...
    isinf(profiles.curves.tau);
verifyEqual(testCase,profiles.curves.proportion(use),0.5);
end

function testSmokeSummarySeparatesGateAndExposureBands(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
outputDir = tempname;
cfg = nonlipschitz_comparison_config(root,outputDir);
cfg.problem_indices = [1 6];
cfg.trials = 1;
cfg.parallel_workers = 1;
cfg.max_iter = 2;
assumeTrue(testCase,isfile(cfg.gate_source_file), ...
    'The optional accepted accessibility gate is unavailable.');
campaign = run_nonlipschitz_comparison(cfg);

summary = summarize_nonlipschitz_comparison(campaign.rows,outputDir);

verifyEqual(testCase,height(summary.runs),14);
verifyEqual(testCase,height(summary.profile_ratios),14*5);
verifyTrue(testCase,any(summary.exposure.gate_status== ...
    "analytically_accessible"));
verifyTrue(testCase,any(ismember(summary.exposure.gate_status, ...
    ["certified_accessible","unresolved"])));
verifyEqual(testCase,unique(summary.exposure.threshold)',sort(10.^(-(1:8))));
verifyTrue(testCase,isfile(fullfile(outputDir,'e3_run_rows.csv')));
verifyTrue(testCase,isfile(fullfile(outputDir,'e3_exposure_conditioned.csv')));
verifyTrue(testCase,isfield(summary,'front_metrics'));
verifyTrue(testCase,isfile(fullfile(outputDir,'e3_front_metrics.csv')));
end
