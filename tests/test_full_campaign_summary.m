function tests = test_full_campaign_summary
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testFailureAwareProfilesKeepFailuresInfiniteAndExposeSuccess(testCase)
runs = fixture_runs();
profiles = full_campaign_profiles(runs);

failed = profiles.ratios.slice=="all_reported" & ...
    profiles.ratios.run_key=="b-p2" & ...
    profiles.ratios.metric=="iterations";
verifyEqual(testCase,profiles.ratios.ratio(failed),Inf);
curve = profiles.curves(profiles.curves.slice=="all_reported" & ...
    profiles.curves.method=="B" & profiles.curves.metric=="iterations" & ...
    isinf(profiles.curves.tau),:);
verifyEqual(testCase,curve.proportion,0.5);
end

function testZeroWorkUsesShiftedRatiosAndKeepsSuccessEndpoint(testCase)
runs = fixture_runs();
runs.status(:) = "converged";
runs.line_search_trials = [0;0;0;2];

profiles = full_campaign_profiles(runs);
row = profiles.ratios.slice=="all_reported" & ...
    profiles.ratios.run_key=="b-p2" & ...
    profiles.ratios.metric=="line_search_trials";
verifyEqual(testCase,profiles.ratios.ratio(row),3);
endpoint = profiles.curves.slice=="all_reported" & ...
    profiles.curves.method=="B" & ...
    profiles.curves.metric=="line_search_trials" & ...
    isinf(profiles.curves.tau);
verifyEqual(testCase,profiles.curves.proportion(endpoint),1);

report = full_campaign_reporting_tables(runs,fixture_iterations(), ...
    empty_tier2(),fixture_tier3_exposure());
pair = report.paired_work.slice=="all_reported" & ...
    report.paired_work.left_method=="A" & ...
    report.paired_work.right_method=="B" & ...
    report.paired_work.metric=="line_search_trials";
verifyEqual(testCase,report.paired_work.geomean_left_over_right(pair), ...
    sqrt(1/3),'AbsTol',1e-14);
end

function testReportingTablesSeparateApplicabilityAndTier3Descent(testCase)
runs = fixture_runs();
iterations = fixture_iterations();
tier2 = empty_tier2();
tier3 = fixture_tier3_exposure();

report = full_campaign_reporting_tables(runs,iterations,tier2,tier3);

verifyTrue(testCase,all(ismember(["all_reported" "theorem_compatible"], ...
    unique(report.outcomes.slice))));
theoremB = report.outcomes(report.outcomes.slice=="theorem_compatible" & ...
    report.outcomes.method=="B",:);
verifyEqual(testCase,sum(theoremB.runs),1);
verifyEqual(testCase,sum(theoremB.converged),1);
descentB = report.tier3_descent(report.tier3_descent.method=="B",:);
verifyEqual(testCase,sum(descentB.computed_directions),3);
verifyEqual(testCase,sum(descentB.bound_violations),1);
verifyEqual(testCase,report.tier3_exposure.max_actual_post0(1),20);
end

function testNC10FrontIsExplicitlyPooledUnionRelative(testCase)
metrics = full_campaign_front_metrics(fixture_runs());
verifyEqual(testCase,unique(metrics.reference_type),"pooled_union_relative");
verifyFalse(testCase,any(contains(lower(metrics.reference_type),"cust")));
end

function runs = fixture_runs()
runKey = ["a-p1";"b-p1";"a-p2";"b-p2"];
tier = [3;3;3;3]; setName = repmat("NC10",4,1);
problem = ["NC10-1";"NC10-1";"NC10-5";"NC10-5"];
problemIndex = [1;1;5;5]; method = ["A";"B";"A";"B"];
startId = [1;1;1;1]; status = ["converged";"converged"; ...
    "converged";"line_search_failed"];
iterations = [2;4;3;8]; componentF = [10;20;12;50];
componentJ = [8;16;9;40]; lineSearchTrials = [3;5;4;100];
qpSolves = [2;4;3;8]; wallTime = [1;2;1.5;4];
evaluationTime = wallTime/2; qpTime = wallTime/4;
theta = -ones(4,1); vNorm = ones(4,1);
theoremCompatible = [true;true;false;false];
unboundedLevelSet = false(4,1); naturalDomain = false(4,1);
exposureStratum = ["primary_nc10";"primary_nc10"; ...
    "primary_nc10";"primary_nc10"];
tier3Primary = true(4,1);
Ffinal = {[0;1];[0.2;0.8];[0.1;1.2];[0.4;1.0]};
runs = table(runKey,tier,setName,problem,problemIndex,method,startId,status, ...
    iterations,componentF,componentJ,lineSearchTrials,qpSolves,wallTime, ...
    evaluationTime,qpTime,theta,vNorm,theoremCompatible,unboundedLevelSet, ...
    naturalDomain,exposureStratum,tier3Primary,Ffinal, ...
    'VariableNames',{'run_key','tier','set_name','problem','problem_index', ...
    'method','start_id','status','iterations','component_F','component_J', ...
    'line_search_trials','qp_solves','wall_time','evaluation_time','qp_time', ...
    'theta','v_norm','theorem_compatible','unbounded_level_set', ...
    'natural_domain','exposure_stratum','tier3_primary','F_final'});
end

function iterations = fixture_iterations()
runKey = ["a-p1";"a-p1";"b-p1";"b-p1";"a-p2";"b-p2"];
k = [1;2;1;2;1;1];
descentGap = [0;-1;0;0;0;1];
descentBoundHolds = [true;true;true;true;true;false];
iterations = table(runKey,k,descentGap,descentBoundHolds, ...
    'VariableNames',{'run_key','k','descent_gap','descent_bound_holds'});
end

function value = fixture_tier3_exposure()
runKey = ["a-p1";"a-p1";"b-p1";"b-p1"];
k = [1;2;1;2]; argumentId = repmat("f1_t1",4,1);
r = [.1;.01;.2;.02]; d = r; distanceKind = repmat("exact",4,1);
status = repmat("regular",4,1); actualExposure = [1;20;2;10];
inverseTEnvelope = [10;100;5;50];
value = table(runKey,k,argumentId,r,d,distanceKind,status,actualExposure, ...
    inverseTEnvelope,'VariableNames',{'run_key','k','argument_id','r','d', ...
    'distance_kind','status','actual_exposure','inverse_t_envelope'});
end

function value = empty_tier2()
value = table('Size',[0 8], ...
    'VariableTypes',{'string','double','string','double','double', ...
    'string','string','double'},'VariableNames', ...
    {'run_key','k','argument_id','r','d','distance_kind','status','chi'});
end
