function tests = test_singular_instrumentation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'));
testCase.TestData.registry = nonlipschitz_problem_registry();
end

function testRegistryFieldsAndCounts(testCase)
registry = testCase.TestData.registry;
required = {'argument_id','objective_rows','value','gradient', ...
    'distance_kind','distance','regular_zero_test', ...
    'validation_anchor','validation_normal','witness_components'};
expected = [1 1 1 1 1 4 4 4 4 4 2 2 4 4 4];
for k = 1:numel(registry)
    args = nonlipschitz_arguments(registry(k));
    verifyEqual(testCase,numel(args),expected(k),registry(k).paper_label);
    verifyTrue(testCase,all(isfield(args,required)),registry(k).paper_label);
end
end

function testExactAndProxyDistances(testCase)
registry = testCase.TestData.registry;

args = nonlipschitz_arguments(registry(7)); % NL10-2
verifyEqual(testCase,args(1).distance([1;1]),sqrt(2),'AbsTol',1e-14);
verifyEqual(testCase,args(1).distance_kind,'exact');

args = nonlipschitz_arguments(registry(10)); % NL10-5
verifyEqual(testCase,args(1).distance([2;-3]),2,'AbsTol',1e-14);
verifyEqual(testCase,args(3).distance([4;1]),3,'AbsTol',1e-14);

args = nonlipschitz_arguments(registry(11)); % NL10-6
verifyEqual(testCase,args(1).distance([0;2]),1,'AbsTol',1e-14);
verifyEqual(testCase,args(2).distance([3;7]),1,'AbsTol',1e-14);

args = nonlipschitz_arguments(registry(14)); % NL10-9
verifyEqual(testCase,args(1).distance_kind,'first_order_proxy');
verifyEqual(testCase,args(1).distance([1;0]),1/sqrt(5),'AbsTol',1e-14);
end

function testStatusesAreNotImputed(testCase)
registry = testCase.TestData.registry;

regular = evaluate_singular_exposure( ...
    nonlipschitz_arguments(registry(1)),[0;0]);
verifyEqual(testCase,regular.entries(1).status,'regular_exact_hit');
verifyEqual(testCase,regular.entries(1).d,0);
verifyEqual(testCase,regular.entries(1).chi,Inf);
verifyEqual(testCase,regular.entries(1).log10_d,-Inf);

degenerate = evaluate_singular_exposure( ...
    nonlipschitz_arguments(registry(10)),[0;0]);
verifyEqual(testCase,degenerate.entries(1).status,'degenerate_zero');
verifyTrue(testCase,isnan(degenerate.entries(1).d));
verifyTrue(testCase,isnan(degenerate.entries(1).chi));

inner = evaluate_singular_exposure( ...
    nonlipschitz_arguments(registry(11)),[0;0]);
verifyEqual(testCase,inner.entries(1).status,'inner_stationary');
verifyEqual(testCase,inner.entries(1).distance_kind,'exact');
verifyEqual(testCase,inner.entries(1).d,1);
verifyEqual(testCase,inner.entries(1).chi,0);
end

function testAggregateRetainsAttainingIdsAndDistanceLabel(testCase)
registry = testCase.TestData.registry;
obs = evaluate_singular_exposure(nonlipschitz_arguments(registry(14)),[1;0.2]);

verifyNotEmpty(testCase,obs.s_argument_id);
verifyNotEmpty(testCase,obs.d_argument_id);
verifyNotEmpty(testCase,obs.chi_argument_id);
verifyTrue(testCase,ismember(obs.d_distance_kind,{'exact','first_order_proxy'}));
end

function testMetadataDoesNotTouchEvaluatorCounters(testCase)
prob = testCase.TestData.registry(6);
x = [0.2;-0.4];
evaluator = Evaluator(prob,x,'corrected');
evaluator.value(x);
before = evaluator.counts();

args = nonlipschitz_arguments(prob);
evaluate_singular_exposure(args,x);
after = evaluator.counts();

verifyEqual(testCase,after,before);
end

function testSummaryExcludesInitialPointAndTrials(testCase)
args = nonlipschitz_arguments(testCase.TestData.registry(1));
accepted = [0 0 0;0.1 0.01 0.02];
trial = struct('iteration',1,'trial',1,'alpha',0.5,'point',[0;0], ...
    'accepted',false,'q',0,'g',0,'phi',0);

summary = summarize_singular_exposure(args,accepted,trial);

verifyEqual(testCase,summary.s_0,0.1,'AbsTol',1e-15);
verifyEqual(testCase,summary.s_min_post0,0.01,'AbsTol',1e-15);
verifyEqual(testCase,summary.d_min_post0,0.01,'AbsTol',1e-15);
verifyEqual(testCase,summary.chi_max_post0,10,'AbsTol',1e-12);
verifyEqual(testCase,summary.d_contraction,0.1,'AbsTol',1e-14);
verifyEqual(testCase,summary.accepted_post0_count,2);
verifyEqual(testCase,summary.d_band_counts(1),2);
verifyEqual(testCase,summary.d_band_counts(2),1);
verifyEqual(testCase,summary.regular_exact_hits,0);
verifyEqual(testCase,numel(summary.line_trials),1);
verifyEqual(testCase,summary.line_trials(1).exposure.d,0);
verifyEqual(testCase,summary.line_trials(1).exposure.entries(1).status, ...
    'regular_exact_hit');
end
