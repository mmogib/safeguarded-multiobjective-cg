function tests = test_calibration
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
addpath(fullfile(mcodeRoot, 'core'));
addpath(fullfile(mcodeRoot, 'config'));
addpath(fullfile(mcodeRoot, 'bench'));
end

function testFrozenCalibrationConfigurationHasOnlyAuthorizedRuns(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = phase_b_calibration_config(mcodeRoot, fullfile(tempdir, 'unused.mat'));

verifyEqual(testCase, cfg.problem_indices, ...
    [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40]);
verifyEqual(testCase, cfg.trials, 1:100);
verifyEqual(testCase, numel(cfg.jobs), 39);
verifyEqual(testCase, unique(string({cfg.jobs.method}), 'stable'), ...
    ["TTCGP" "TTCGH" "TTCGL"]);
verifyEqual(testCase, unique(string({cfg.jobs.mode})), "paper_r2");
verifyEqual(testCase, unique([cfg.jobs.eta], 'stable'), ...
    [0 0.01 0.05 0.1 0.2 0.3 0.5 0.7 0.9 1 2 5 10]);
end


function testStage0ConfigurationIsExactlyTheAuthorizedDiagnostic(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = phase_b_stage0_config(mcodeRoot, fullfile(tempdir, 'unused-stage0.mat'));

verifyEqual(testCase, cfg.problem_indices, ...
    [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40]);
verifyEqual(testCase, cfg.trials, 1:100);
verifyEqual(testCase, numel(cfg.jobs), 3);
verifyEqual(testCase, string({cfg.jobs.method}), ["TTCGP" "TTCGH" "TTCGL"]);
verifyEqual(testCase, unique(string({cfg.jobs.mode})), "paper_r2");
verifyEqual(testCase, unique([cfg.jobs.eta]), 1);
verifyEqual(testCase, numel(cfg.jobs)*numel(cfg.problem_indices)*numel(cfg.trials), 4500);
end

function testCompetitorDiagnosticConfigurationIsExactlyAuthorized(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = phase_b_competitor_diagnostic_config(mcodeRoot, ...
    fullfile(tempdir, 'unused-competitors.mat'));

verifyEqual(testCase, cfg.problem_indices, ...
    [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40]);
verifyEqual(testCase, cfg.trials, 1:100);
verifyEqual(testCase, string({cfg.jobs.method}), ["PRP+" "AVHZ+"]);
verifyEqual(testCase, unique(string({cfg.jobs.mode})), "paper_r2");
verifyTrue(testCase, all(isnan([cfg.jobs.eta])));
verifyEqual(testCase, numel(cfg.jobs)*numel(cfg.problem_indices)* ...
    numel(cfg.trials), 3000);
end

function testMOSDVerificationConfigurationUsesSpentCalibrationSet(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = phase_b_mosd_verification_config(mcodeRoot, ...
    fullfile(tempdir, 'unused-mosd.mat'));

verifyEqual(testCase, cfg.problem_indices, ...
    [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40]);
verifyEqual(testCase, cfg.trials, 1:100);
verifyEqual(testCase, numel(cfg.jobs), 1);
verifyEqual(testCase, string(cfg.jobs.method), "MOSD");
verifyEqual(testCase, string(cfg.jobs.mode), "paper_r2");
verifyTrue(testCase, isnan(cfg.jobs.eta));
verifyEqual(testCase, numel(cfg.jobs)*numel(cfg.problem_indices)* ...
    numel(cfg.trials), 1500);
end

function testHeldoutConfigurationMatchesFrozenNineArmDesign(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = phase_b_heldout_config(mcodeRoot, ...
    fullfile(tempdir, 'unused-heldout.mat'));

verifyEqual(testCase, cfg.problem_indices, ...
    [2 3 4 8 9 10 11 12 13 15 16 20 21 24 25 27 28 29 30 34 36 39]);
verifyEqual(testCase, cfg.assca_compatible_indices, ...
    [3 4 9 10 11 13 15 16 20 21 27 28 30 34 36 39]);
verifyEqual(testCase, cfg.assca_incompatible_indices, [2 8 12 24 25 29]);
verifyEqual(testCase, cfg.trials, 1:100);
verifyEqual(testCase, numel(cfg.jobs), 9);
verifyEqual(testCase, string({cfg.jobs.method}), ...
    ["TTCGP" "TTCGH" "TTCGL" "TTCGP" "TTCGH" "TTCGL" ...
     "MOSD" "PRP+" "AVHZ+"]);
verifyEqual(testCase, [cfg.jobs.eta], [1 1 1 0.1 0.1 0.1 NaN NaN NaN]);
verifyEqual(testCase, unique(string({cfg.jobs.mode})), "paper_r2");
verifyEqual(testCase, numel(cfg.jobs)*numel(cfg.problem_indices)* ...
    numel(cfg.trials), 19800);
end

function testCampaignPreservesIterationDiagnostics(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(work, 'diagnostics.mat'), ...
    'jobs', struct('method', 'TTCGP', 'mode', 'paper', 'eta', 1), ...
    'problem_indices', 1, 'trials', 1);

campaign = run_campaign(cfg);
row = campaign.rows(1,:);
summary = summarize_calibration(campaign.rows, 1);

verifyEqual(testCase,campaign.manifest.schema_version,5);
verifyEqual(testCase, row.derivative_mode, "corrected");
verifyEqual(testCase, row.lambda_positive_count+0, ...
    sum(row.lambda_values{1} > 0));
verifyEqual(testCase, row.lambda_total, numel(row.lambda_values{1}));
verifyEqual(testCase, row.beta_observations, numel(row.raw_beta{1}));
verifyEqual(testCase, row.qp_solves, row.iterations);
verifyEqual(testCase, row.truncated_beta{1}, max(row.raw_beta{1}, 0));
verifyEqual(testCase, numel(row.clipped_beta{1}), row.beta_observations);
verifyEqual(testCase, summary.selected_eta, 1);
verifyEqual(testCase, summary.diagnostics.lambda_total, row.lambda_total);
verifyEqual(testCase, summary.diagnostics.descent_violations, 0);
verifyTrue(testCase,ismember('line_search_failure_detail', ...
    row.Properties.VariableNames));
verifyTrue(testCase,ismember('p_norm_values',row.Properties.VariableNames));
verifyTrue(testCase,ismember('alignment_values',row.Properties.VariableNames));
verifyTrue(testCase,ismember('alignment_undefined',row.Properties.VariableNames));
verifyTrue(testCase,ismember('hs_beta_fallbacks',row.Properties.VariableNames));
verifyTrue(testCase,ismember('hs_beta_fallback_details',row.Properties.VariableNames));
verifyTrue(testCase,ismember('line_search_no_bracket',row.Properties.VariableNames));
verifyTrue(testCase,ismember('line_search_budget_exhausted',row.Properties.VariableNames));
if ismember('line_search_failure_detail',row.Properties.VariableNames)
    verifyEmpty(testCase,row.line_search_failure_detail{1});
end
end

function testCampaignPersistsCompetitorNoDescentEvent(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(work, 'no-descent.mat'), ...
    'jobs', struct('method', 'PRP+', 'mode', 'paper_r2', 'eta', NaN), ...
    'problem_indices', 1, 'trials', 1);

campaign = run_campaign(cfg);
row = campaign.rows(1,:);

verifyEqual(testCase, row.status, "no_descent");
verifyEqual(testCase, row.no_descent_iteration, 2);
verifyGreaterThanOrEqual(testCase, row.no_descent_value, 0);
verifyLessThan(testCase, row.no_descent_steepest_value, 0);
verifyGreaterThan(testCase, row.no_descent_steepest_norm_squared, 0);
verifyEqual(testCase, -row.no_descent_steepest_value, ...
    row.no_descent_steepest_norm_squared, 'RelTol', 1e-8, 'AbsTol', 1e-12);
verifyEqual(testCase, row.line_search_failed, 0);
end

function testCompetitorDiagnosticSummaryRetainsStatusesAndEvents(testCase)
method = ["PRP+";"PRP+";"AVHZ+";"AVHZ+"];
problem = ["BK1";"BK1";"BK1";"SK2"];
status = ["converged";"no_descent";"no_descent";"max_iter"];
no_descent_iteration = [NaN;3;5;NaN];
no_descent_value = [NaN;0.2;0.4;NaN];
rows = table(method,problem,status,no_descent_iteration,no_descent_value);

summary = summarize_competitor_diagnostic(rows);

use = summary.overall_status.method=="PRP+" & ...
    summary.overall_status.status=="no_descent";
verifyEqual(testCase, summary.overall_status.runs(use), 1);
use = summary.problem_status.method=="AVHZ+" & ...
    summary.problem_status.problem=="SK2" & ...
    summary.problem_status.status=="max_iter";
verifyEqual(testCase, summary.problem_status.runs(use), 1);
use = summary.no_descent.method=="AVHZ+";
verifyEqual(testCase, summary.no_descent.events(use), 1);
verifyEqual(testCase, summary.no_descent.iteration_median(use), 5);
verifyEqual(testCase, summary.no_descent.value_median(use), 0.4);
end


function testStage0SummaryAggregatesRequestedDiagnostics(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work,'s')); %#ok<NASGU>
cfg = struct('mcode_root',mcodeRoot, ...
    'output_file',fullfile(work,'stage0-unit.mat'), ...
    'jobs',struct('method','TTCGP','mode','paper_r2','eta',1), ...
    'problem_indices',1,'trials',1);

campaign = run_campaign(cfg);
summary = summarize_stage0(campaign.rows);
row = campaign.rows(1,:);

verifyEqual(testCase,height(summary.by_problem_method),1);
verifyEqual(testCase,summary.by_problem_method.lambda_positive, ...
    row.lambda_positive_count);
verifyEqual(testCase,summary.by_problem_method.lambda_total,row.lambda_total);
verifyEqual(testCase,summary.by_problem_method.line_search_no_bracket, ...
    row.line_search_no_bracket);
verifyEqual(testCase,summary.by_problem_method.line_search_budget_exhausted, ...
    row.line_search_budget_exhausted);
verifyEqual(testCase,summary.distributions.lambda_n,row.lambda_total);
verifyEqual(testCase,summary.distributions.p_norm_n, ...
    numel(row.p_norm_values{1}));
verifyEqual(testCase,summary.distributions.alignment_undefined, ...
    row.alignment_undefined);
verifyEqual(testCase,summary.descent_violations,0);
end

function testCalibrationScoreUsesSuccessThenOnePercentTieRule(testCase)
eta = [0.5; 0.5; 1; 1; 2; 2];
status = ["converged"; "converged"; "converged"; "converged"; ...
    "converged"; "failed"];
iterations = [100; 100; 100.5; 100.5; 80; 80];
component_F = iterations;
component_J = iterations;
rows = table(repmat("TTCGP",6,1), repmat("BK1",6,1), eta, status, ...
    iterations, component_F, component_J, ...
    'VariableNames', {'method','problem','eta','status','iterations', ...
    'component_F','component_J'});

[scores, selected] = score_calibration(rows, [0.5 1 2]);

verifyEqual(testCase, scores.successes', [2 2 1]);
verifyTrue(testCase, scores.within_tie_band(scores.eta == 0.5));
verifyTrue(testCase, scores.within_tie_band(scores.eta == 1));
verifyEqual(testCase, selected, 1);
end

function testZeroControlIsScoredAgainstPositiveBaselinesButCannotBeSelected(testCase)
eta = [0; 0.5; 1];
status = repmat("converged",3,1);
iterations = [1; 100; 100.5];
component_F = iterations;
component_J = iterations;
rows = table(repmat("TTCGP",3,1),repmat("BK1",3,1),eta,status, ...
    iterations,component_F,component_J, ...
    'VariableNames',{'method','problem','eta','status','iterations', ...
    'component_F','component_J'});

[scores, selected] = score_calibration(rows,[0 0.5 1],[0.5 1]);

verifyEqual(testCase,scores.score(scores.eta==0.5),1,'AbsTol',1e-15);
verifyEqual(testCase,scores.score(scores.eta==0),0.01,'AbsTol',1e-15);
verifyFalse(testCase,scores.selection_eligible(scores.eta==0));
verifyFalse(testCase,scores.within_tie_band(scores.eta==0));
verifyFalse(testCase,scores.selected(scores.eta==0));
verifyEqual(testCase,selected,1);
end

function testControlComparisonUsesMethodProblemMetricMedians(testCase)
method = [repmat("TTCGP",6,1);repmat("TTCGH",6,1)];
problem = repmat(["BK1";"BK1";"BK1";"BK1";"BK1";"BK1"],2,1);
eta = repmat([0;0;0;1;1;1],2,1);
status = repmat("converged",12,1);
iterations = [1;3;100;2;4;200; 2;4;100;2;6;200];
component_F = 2*iterations;
component_J = 3*iterations;
rows = table(method,problem,eta,status,iterations,component_F,component_J);

comparison = compare_calibration_control(rows,0,1);

verifyEqual(testCase,height(comparison),6);
use = comparison.method=="TTCGP" & comparison.metric=="iterations";
verifyEqual(testCase,comparison.control_median(use),3);
verifyEqual(testCase,comparison.selected_median(use),4);
verifyEqual(testCase,comparison.selected_over_control(use),4/3,'AbsTol',1e-15);
end

function testCalibrationReportTablesHaveDeterministicExporter(testCase)
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work,'s')); %#ok<NASGU>
phaseB.summary.scores = table([0;1],[2;2], ...
    'VariableNames',{'eta','successes'});
phaseB.summary.diagnostics = table("TTCGP",1, ...
    'VariableNames',{'method','eta'});
phaseB.summary.control_comparison = table("TTCGP","BK1","iterations",3,4,4/3, ...
    'VariableNames',{'method','problem','metric','control_median', ...
    'selected_median','selected_over_control'});

export_calibration_tables(phaseB,work);

verifyTrue(testCase,isfile(fullfile(work,'calibration_paper_r2_scores.csv')));
verifyTrue(testCase,isfile(fullfile(work,'calibration_paper_r2_diagnostics.csv')));
verifyTrue(testCase,isfile(fullfile(work,'calibration_paper_r2_control_comparison.csv')));
verifyEqual(testCase,readtable(fullfile(work, ...
    'calibration_paper_r2_control_comparison.csv')).selected_over_control,4/3, ...
    'AbsTol',1e-14);
end

function testArchivedStartRangesAreComponentwiseAndIncludePortedAP1(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
[summary,coordinates] = archived_start_ranges(mcodeRoot);
registry = problem_registry(mcodeRoot);
bk1Starts = load_initial_points(registry(1),mcodeRoot);

verifyEqual(testCase,height(summary),41);
verifyEqual(testCase,summary.problem(1),"BK1");
verifyTrue(testCase,summary.available(1));
verifyEqual(testCase,coordinates.minimum(coordinates.problem=="BK1"), ...
    min(bk1Starts,[],2));
verifyEqual(testCase,coordinates.maximum(coordinates.problem=="BK1"), ...
    max(bk1Starts,[],2));
verifyEqual(testCase,sum(coordinates.problem=="BK1"),2);
verifyEqual(testCase,summary.problem(41),"AP1");
verifyTrue(testCase,summary.available(41));
verifyEqual(testCase,sum(coordinates.problem=="AP1"),2);
ap1Starts = load_initial_points(registry(41),mcodeRoot);
verifyEqual(testCase,coordinates.minimum(coordinates.problem=="AP1"), ...
    min(ap1Starts,[],2));
verifyEqual(testCase,coordinates.maximum(coordinates.problem=="AP1"), ...
    max(ap1Starts,[],2));
end
