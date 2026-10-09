function tests = test_tier3_instrumentation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'),fullfile(root,'bench'));
testCase.TestData.registry = tier3_problem_registry();
end

function testActualAndInverseTEnvelopeAreSeparate(testCase)
args = nonlipschitz_arguments(testCase.TestData.registry(1));
x = [0.2;0.7];
observation = evaluate_tier3_exposure(args,x);
entry = observation.entries(1);
[~,derivative] = oscillatory_kernel(args(1).value(x));
gradientNorm = norm(args(1).gradient(x));

verifyEqual(testCase,entry.actual_exposure,abs(derivative)*gradientNorm, ...
    'RelTol',1e-14);
verifyEqual(testCase,entry.inverse_t_envelope, ...
    gradientNorm/abs(args(1).value(x)),'RelTol',1e-14);
verifyNotEqual(testCase,entry.actual_exposure,entry.inverse_t_envelope);
verifyFalse(testCase,isfield(entry,'chi'));
end

function testRegularAndDegenerateZerosAreNotConflated(testCase)
registry = testCase.TestData.registry;
regular = evaluate_tier3_exposure( ...
    nonlipschitz_arguments(registry(1)),[0;0]);
verifyEqual(testCase,regular.entries(1).status,'regular_exact_hit');
verifyEqual(testCase,regular.entries(1).actual_exposure,0);
verifyEqual(testCase,regular.entries(1).inverse_t_envelope,Inf);
verifyEqual(testCase,regular.entries(1).d,0);

degenerate = evaluate_tier3_exposure( ...
    nonlipschitz_arguments(registry(5)),[0;0]);
verifyEqual(testCase,degenerate.entries(1).status,'degenerate_zero');
verifyTrue(testCase,isnan(degenerate.entries(1).actual_exposure));
verifyTrue(testCase,isnan(degenerate.entries(1).inverse_t_envelope));
verifyTrue(testCase,isnan(degenerate.entries(1).d));
end

function testAcceptedSummaryExcludesInitialPointAndLineTrials(testCase)
args = nonlipschitz_arguments(testCase.TestData.registry(1));
accepted = [0.1 0.05 0.025;0.4 0.4 0.4];
trial = struct('iteration',1,'trial',1,'alpha',0.5,'point',[0;0], ...
    'accepted',false,'q',0,'g',0,'phi',0);

summary = summarize_tier3_exposure(args,accepted,trial);
postActual = arrayfun(@(k) evaluate_tier3_exposure( ...
    args,accepted(:,k)).actual_exposure,2:3);

verifyEqual(testCase,summary.actual_max_post0,max(postActual),'AbsTol',0);
verifyEqual(testCase,summary.accepted_post0_count,2);
verifyEqual(testCase,numel(summary.line_trials),1);
verifyEqual(testCase,summary.line_trials(1).exposure.entries(1).status, ...
    'regular_exact_hit');
verifyEqual(testCase, ...
    summary.line_trials(1).exposure.entries(1).actual_exposure,0);
verifyEqual(testCase,summary.line_trials(1).exposure.inverse_t_envelope,Inf);
end

function testTier3ContractExtendsBaselineWithoutAStore(testCase)
baseline = campaignstore.baseline_retention_contract();
contract = tier3_retention_contract();

verifyEqual(testCase,contract.runs,baseline.runs);
verifyEqual(testCase,contract.iterations,baseline.iterations);
verifyTrue(testCase,isfield(contract.extras,'accepted_exposure'));
verifyTrue(testCase,isfield(contract.extras,'line_trial_exposure'));
required = {'run_key','argument_id','r','d','status', ...
    'actual_exposure','inverse_t_envelope'};
verifyTrue(testCase,all(ismember(required, ...
    contract.extras.accepted_exposure)));
verifyTrue(testCase,all(ismember(required, ...
    contract.extras.line_trial_exposure)));
end
