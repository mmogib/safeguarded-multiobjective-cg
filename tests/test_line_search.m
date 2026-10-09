function tests = test_line_search
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'core'),fullfile(mcodeRoot,'problems'), ...
    fullfile(mcodeRoot,'config'),fullfile(mcodeRoot,'bench'));
end

function testValidatedStrongAcceptsOnlyCheckedStep(testCase)
prob = quadratic_problem();
evaluator = Evaluator(prob, 1, 'corrected');
opts = line_options('validated_strong');

result = line_search(evaluator, 1, -1, 1, opts);

verifyEqual(testCase, result.status, 'ok');
verifyTrue(testCase, result.validated);
verifyEqual(testCase, result.alpha, 1, 'AbsTol', 1e-15);
verifyLessThanOrEqual(testCase, abs(result.phi_trial), -opts.sigma*result.phi0);
end

function testValidatedStrongOptionallyRecordsEveryTrialPoint(testCase)
prob = shifted_quadratic_problem();
evaluator = Evaluator(prob,0,'corrected');
opts = line_options('validated_strong');
opts.record_trials = true;

result = line_search(evaluator,0,1,1.5,opts);

verifyEqual(testCase,numel(result.trial_records),result.trials);
verifyEqual(testCase,[result.trial_records.trial],1:result.trials);
verifyEqual(testCase,result.trial_records(end).accepted,true);
for k = 1:numel(result.trial_records)
    record = result.trial_records(k);
    verifyEqual(testCase,record.point,record.alpha,'AbsTol',0);
    verifyTrue(testCase,all(isfield(record, ...
        {'point','alpha','accepted','q','g','phi'})));
end
end

function testValidatedStrongRejectsNonDescentDirection(testCase)
prob = quadratic_problem();
evaluator = Evaluator(prob, 1, 'corrected');
opts = line_options('validated_strong');

result = line_search(evaluator, 1, 1, 1, opts);

verifyEqual(testCase, result.status, 'init_failed');
verifyFalse(testCase, result.validated);
verifyTrue(testCase, isnan(result.alpha));
end

function testValidatedStrongReportsNoBracket(testCase)
prob = linear_problem();
evaluator = Evaluator(prob, 0, 'corrected');
opts = line_options('validated_strong');
opts.alpha_max = 10;

result = line_search(evaluator, 0, 1, 0.1, opts);

verifyEqual(testCase,result.status,'no_bracket');
verifyFalse(testCase,result.validated);
verifyTrue(testCase,isfield(result,'bracket'));
if isfield(result,'bracket')
    verifyEqual(testCase,result.bracket.a,10,'AbsTol',1e-14);
    verifyLessThan(testCase,result.bracket.q_a,0);
    verifyLessThan(testCase,result.bracket.g_a,0);
end
end

function testValidatedStrongDoesNotAcceptPrematureRightEndpoint(testCase)
prob = shifted_quadratic_problem();
evaluator = Evaluator(prob, 0, 'corrected');
opts = line_options('validated_strong');

result = line_search(evaluator, 0, 1, 1.5, opts);

verifyEqual(testCase,result.status,'ok');
verifyTrue(testCase,result.validated);
verifyGreaterThan(testCase,abs(result.alpha-1.5),1e-15);
verifyLessThanOrEqual(testCase,abs(result.phi_trial),-opts.sigma*result.phi0);
end

function testInitFailureReportsLastShrunkPoint(testCase)
prob = shifted_quadratic_problem();
evaluator = Evaluator(prob,0,'corrected');
opts = line_options('validated_strong');
opts.alpha_min = 1.2;
opts.alpha_max = 10;

result = line_search(evaluator,0,1,4,opts);

verifyEqual(testCase,result.status,'init_failed');
verifyEqual(testCase,result.bracket.a,1.2,'AbsTol',1e-14);
verifyEqual(testCase,result.bracket.b,4,'AbsTol',1e-14);
verifyLessThan(testCase,result.bracket.q_a,0);
verifyGreaterThan(testCase,result.bracket.g_a,0);
end

function testValidatedStrongRejectsNonfiniteBaseline(testCase)
prob = nonfinite_baseline_problem();
evaluator = Evaluator(prob,0,'corrected');
opts = line_options('validated_strong');

result = line_search(evaluator,0,1,1,opts);

verifyEqual(testCase,result.status,'init_failed');
verifyFalse(testCase,result.validated);
verifyTrue(testCase,isnan(result.alpha));
verifyEqual(testCase,result.trials,0);
end

function testValidatedStrongReportsBudgetExhausted(testCase)
prob = shifted_quadratic_problem();
evaluator = Evaluator(prob,0,'corrected');
opts = line_options('validated_strong');
opts.max_trials = 2;

result = line_search(evaluator,0,1,1.5,opts);

verifyEqual(testCase,result.status,'budget_exhausted');
verifyFalse(testCase,result.validated);
verifyLessThan(testCase,result.bracket.q_a,0);
verifyLessThan(testCase,result.bracket.g_a,0);
end

function testValidatedStrongRecoversHistoricalBK1Failure(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
fixtureFile = fullfile(mcodeRoot,'data','results','phaseB', ...
    'line_search_failure_states.mat');
assumeTrue(testCase,isfile(fixtureFile), ...
    'The optional historical regression fixture is unavailable.');
saved = load(fixtureFile,'failure_states');
state = saved.failure_states(1);
registry = problem_registry(mcodeRoot);
prob = registry(state.legacy_index);
evaluator = Evaluator(prob,state.x0,'corrected');
opts = experiment('TTCGP','paper');
lineOpts = struct('mode','validated_strong','rho',opts.rho, ...
    'sigma',opts.sigma,'alpha_min',opts.alpha_min, ...
    'alpha_max',opts.alpha_max,'max_trials',opts.line_search_max_trials);

result = line_search(evaluator,state.x,state.direction, ...
    state.alpha_start,lineOpts);

verifyEqual(testCase,result.status,'ok');
verifyTrue(testCase,result.validated);
end

function testLegacyRecordsUnvalidatedAlphaMaxExit(testCase)
prob = linear_problem();
evaluator = Evaluator(prob, 0, 'legacy');
opts = line_options('legacy');
opts.alpha_max = 10;

result = line_search(evaluator, 0, 1, 0.1, opts);

verifyEqual(testCase, result.status, 'alphamax_unvalidated');
verifyEqual(testCase, result.legacy_exit, 'alphamax');
verifyFalse(testCase, result.validated);
verifyEqual(testCase, result.alpha, 10);
end

function opts = line_options(mode)
opts = struct('mode', mode, 'rho', 1e-4, 'sigma', 0.1, ...
    'alpha_min', 1e-15, 'alpha_max', 1e10, 'max_trials', 100);
end

function prob = quadratic_problem()
prob = struct('m', 2, 'n', 1, ...
    'value', @(x) [0.5*x(1)^2; 0.5*x(1)^2], ...
    'jacobian', @(x) [x(1); x(1)], ...
    'legacy_jacobian', @(x) [x(1); x(1)]);
end

function prob = linear_problem()
prob = struct('m', 2, 'n', 1, ...
    'value', @(x) [-x(1); -x(1)], ...
    'jacobian', @(x) [-1; -1], ...
    'legacy_jacobian', @(x) [-1; -1]);
end

function prob = shifted_quadratic_problem()
prob = struct('m',2,'n',1, ...
    'value',@(x) [0.5*(x(1)-1)^2;0.5*(x(1)-1)^2], ...
    'jacobian',@(x) [x(1)-1;x(1)-1], ...
    'legacy_jacobian',@(x) [x(1)-1;x(1)-1]);
end

function prob = nonfinite_baseline_problem()
prob = struct('m',2,'n',1,'value',@nonfinite_value, ...
    'jacobian',@(x) [-1;-1],'legacy_jacobian',@(x) [-1;-1]);
end

function value = nonfinite_value(x)
if x(1) == 0
    value = [Inf;Inf];
else
    value = [-x(1);-x(1)];
end
end
