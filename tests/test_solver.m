function tests = test_solver
tests = functiontests(localfunctions);
end

function testTraceRetainsOneRecordPerComputedDirection(testCase)
registry = problem_registry(testCase.TestData.root);
prob = registry(1);
opts = experiment('TTCGP','paper_r2');
opts.max_iter = 8;
opts.trace_enabled = true;

result = solve_mocg(prob,[0.3;-0.4],opts);
records = result.trace.iterations;
required = {'k','accepted_step','theta','v_norm', ...
    'steepest_directional_value','raw_beta','raw_lambda', ...
    'beta_denominator_fallback','lambda_denominator_fallback', ...
    'p_norm','alignment','correction_ratio','direction_growth', ...
    'direction_angle','line_search_status','line_search_trials', ...
    'directional_value','descent_gap','descent_tolerance', ...
    'descent_bound_holds'};

verifyNotEmpty(testCase,records);
verifyTrue(testCase,all(isfield(records,required)));
verifyEqual(testCase,[records.k],1:numel(records));
verifyEqual(testCase,records(1).directional_value, ...
    records(1).steepest_directional_value,'AbsTol',0);
verifyTrue(testCase,records(1).descent_bound_holds);
verifyEqual(testCase,[records(~isnan([records.raw_beta])).raw_beta], ...
    result.diagnostics.raw_beta,'AbsTol',0);
verifyEqual(testCase,[records(~isnan([records.raw_lambda])).raw_lambda], ...
    result.diagnostics.lambda_values,'AbsTol',0);
verifyEqual(testCase,sum([records.line_search_trials]), ...
    result.diagnostics.line_search_trials);
end

function testTracingDoesNotChangeTerminalTrajectoryOrCounters(testCase)
registry = problem_registry(testCase.TestData.root);
prob = registry(1);
opts = experiment('TTCGH','paper_r2');
opts.max_iter = 12;
opts.trace_enabled = false;
plain = solve_mocg(prob,[0.3;-0.4],opts);
opts.trace_enabled = true;
traced = solve_mocg(prob,[0.3;-0.4],opts);

fields = {'status','x','F','iterations','legacy_counts', ...
    'theta','v_norm','steepest_directional_value'};
for k = 1:numel(fields)
    verifyEqual(testCase,traced.(fields{k}),plain.(fields{k}),fields{k});
end
verifyEqual(testCase,rmfield(traced.counts,'evaluation_time'), ...
    rmfield(plain.counts,'evaluation_time'),'counts');
verifyEqual(testCase,rmfield(traced.diagnostics,'qp_time'), ...
    rmfield(plain.diagnostics,'qp_time'),'diagnostics');
end

function setupOnce(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'core'));
addpath(fullfile(mcodeRoot, 'config'));
addpath(fullfile(mcodeRoot, 'problems'));
testCase.TestData.root = mcodeRoot;
end

function testExperimentDefinesOnlyPublishedMethodPolicies(testCase)
ttcgp = experiment('TTCGP', 'paper');
revised = experiment('TTCGP', 'paper_r2');
prp = experiment('PRP+', 'paper');
avhz = experiment('AVHZ+', 'paper');
mosd = experiment('MOSD', 'paper_r2');
lindu = experiment('TT-PRP1','paper_r2');

verifyEqual(testCase, ttcgp.direction, 'threeterm');
verifyEqual(testCase, ttcgp.beta_formula, 'PRP');
verifyEqual(testCase, ttcgp.beta_safeguard, 'nonneg_capped');
verifyEqual(testCase, ttcgp.lambda_mode, 'paper');
verifyEqual(testCase, revised.lambda_mode, 'paper_r2');
verifyEqual(testCase, revised.mode, 'paper_r2');
verifyEqual(testCase, ttcgp.line_search_mode, 'validated_strong');
verifyEqual(testCase, prp.beta_safeguard, 'nonneg');
verifyEmpty(testCase, prp.eta_bar);
verifyEqual(testCase, avhz.mu, 1);
verifyEqual(testCase, mosd.direction, 'steepest');
verifyEqual(testCase, mosd.beta_formula, 'none');
verifyEqual(testCase, mosd.beta_safeguard, 'none');
verifyEmpty(testCase, mosd.eta_bar);
verifyEqual(testCase,lindu.direction,'lindu');
verifyEqual(testCase,lindu.beta_formula,'PRP');
verifyEqual(testCase,lindu.beta_safeguard,'nonneg');
verifyEmpty(testCase,lindu.eta_bar);
verifyEqual(testCase,lindu.line_search_mode,'validated_strong');
end

function testLinDuUsesUncappedPRPPlus(testCase)
opts = experiment('TT-PRP1','paper_r2');
[beta,info] = beta_safeguard(25,'nonneg',opts.eta_bar);
verifyEqual(testCase,beta,25);
verifyFalse(testCase,info.clipped);
end

function testLambdaModesUseQuantitiesNamedByEvaluationPoint(testCase)
q = struct('f_xnext_dprev', 2, 'f_xnext_vprev', -4, ...
    'f_xnext_v', -5, 'f_x_v', -6, 'f_x0_v0', -10);

[paper, paperInfo] = lambda_parameter(q, 'paper');
[paperR2, paperR2Info] = lambda_parameter(q, 'paper_r2');
[driver, driverInfo] = lambda_parameter(q, 'legacy_driver');
[etaSen, etaInfo] = lambda_parameter(q, 'legacy_etasen');

verifyEqual(testCase, paper, 0.5);
verifyEqual(testCase, paperR2, 0.4);
verifyEqual(testCase, driver, 0.2);
verifyEqual(testCase, etaSen, 1/3, 'AbsTol', 1e-15);
verifyEqual(testCase, paperInfo.denominator_name, 'f_xnext_vprev');
verifyEqual(testCase, paperR2Info.denominator_name, '-f_xnext_v');
verifyEqual(testCase, driverInfo.denominator_name, 'f_x0_v0');
verifyEqual(testCase, etaInfo.denominator_name, 'f_x_v');
end

function testRevisedDirectionUsesCurrentSteepestAndIsUnconditional(testCase)
[direction, info] = revised_direction([1;0], [0;1], 2, 0.5);

verifyEqual(testCase, info.p, [1;2], 'AbsTol', 1e-15);
verifyEqual(testCase, info.p_norm, sqrt(5), 'AbsTol', 1e-15);
verifyEqual(testCase, info.alignment, 2/sqrt(5), 'AbsTol', 1e-15);
verifyEqual(testCase, direction, [0;1] + 0.5*[1;2]/sqrt(5), ...
    'AbsTol', 1e-15);

[zeroLambdaDirection, zeroInfo] = revised_direction([0;1], [-1;0], 0, 0.5);
verifyEqual(testCase, zeroInfo.p, [0;1]);
verifyEqual(testCase, zeroLambdaDirection, [-1;0.5], 'AbsTol', 1e-15);
end

function testPaperSolverConvergesOnIdenticalQuadratics(testCase)
prob = identical_quadratics();
opts = experiment('TTCGP', 'paper');
opts.max_iter = 10;

result = solve_mocg(prob, 1, opts);

verifyEqual(testCase, result.status, 'converged');
verifyEqual(testCase, result.x, 0, 'AbsTol', 1e-8);
verifyEqual(testCase, result.F, [0;0], 'AbsTol', 1e-12);
verifyGreaterThanOrEqual(testCase, result.iterations, 1);
verifyEqual(testCase, result.diagnostics.descent_violations, 0);
verifyEqual(testCase, result.diagnostics.qp_failures, 0);
verifyEqual(testCase, result.diagnostics.qp_solves, result.iterations);
end

function testSolverReturnsFinalStationarityAndDirectionGrowth(testCase)
opts = experiment('TT-PRP1','paper_r2');
opts.max_iter = 10;

result = solve_mocg(identical_quadratics(),1,opts);

verifyEqual(testCase,result.status,'converged');
verifyEqual(testCase,result.theta,0,'AbsTol',1e-12);
verifyEqual(testCase,result.v_norm,0,'AbsTol',1e-12);
verifyEqual(testCase,result.steepest_directional_value,0,'AbsTol',1e-12);
verifyGreaterThanOrEqual(testCase,result.diagnostics.max_direction_norm,1);
verifyGreaterThanOrEqual(testCase, ...
    result.diagnostics.max_direction_over_v_norm,1);
end

function testSolverRecordsEtaMechanismResponsesForEveryDirection(testCase)
opts = experiment('TTCGP','paper_r2');
opts.eta_bar = 0.3;
opts.max_iter = 10;

result = solve_mocg(identical_quadratics(),1,opts);
diag = result.diagnostics;

constructed = 1+numel(diag.raw_beta);
verifyEqual(testCase,numel(diag.correction_ratio_values),constructed);
verifyEqual(testCase,numel(diag.direction_growth_values),constructed);
verifyEqual(testCase,numel(diag.direction_angle_values),constructed);
verifyEqual(testCase,diag.correction_ratio_values(1),0,'AbsTol',0);
verifyEqual(testCase,diag.direction_growth_values(1),1,'AbsTol',0);
verifyEqual(testCase,diag.direction_angle_values(1),0,'AbsTol',0);
verifyLessThanOrEqual(testCase,max(diag.correction_ratio_values), ...
    opts.eta_bar+1e-12);
verifyLessThanOrEqual(testCase,max(diag.direction_growth_values), ...
    1+opts.eta_bar+1e-12);
end

function testMOSDBypassesConjugateDirectionDiagnostics(testCase)
opts = experiment('MOSD', 'paper_r2');
opts.max_iter = 10;

result = solve_mocg(identical_quadratics(), 1, opts);

verifyEqual(testCase, result.status, 'converged');
verifyEmpty(testCase, result.diagnostics.raw_beta);
verifyEmpty(testCase, result.diagnostics.lambda_values);
verifyEmpty(testCase, result.diagnostics.p_norm_values);
verifyEqual(testCase, result.diagnostics.qp_solves, result.iterations);
end

function testTraceEnabledIsNumericallyInvisible(testCase)
prob = identical_quadratics();
plainOpts = experiment('TTCGP','paper_r2');
plainOpts.max_iter = 10;
tracedOpts = plainOpts;
tracedOpts.trace_enabled = true;

plain = solve_mocg(prob,1,plainOpts);
traced = solve_mocg(prob,1,tracedOpts);

verifyEqual(testCase,traced.status,plain.status);
verifyEqual(testCase,traced.x,plain.x,'AbsTol',0);
verifyEqual(testCase,traced.F,plain.F,'AbsTol',0);
verifyEqual(testCase,traced.iterations,plain.iterations);
counterFields = {'vector_F','vector_J','component_F','component_J'};
for k = 1:numel(counterFields)
    field = counterFields{k};
    verifyEqual(testCase,traced.counts.(field),plain.counts.(field));
end
verifyEqual(testCase,traced.legacy_counts,plain.legacy_counts);
verifyTrue(testCase,isfield(traced,'trace'));
verifyEqual(testCase,traced.trace.accepted_points(:,1),1,'AbsTol',0);
verifyEqual(testCase,traced.trace.accepted_points(:,end),traced.x,'AbsTol',0);
end

function testInstrumentedWrapperReturnsFrozenExposureSummary(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
registry = nonlipschitz_problem_registry();
starts = nonlipschitz_starts(registry(1));
opts = experiment('TTCGP','paper_r2');
opts.max_iter = 10;
directOpts = opts;
directOpts.trace_enabled = true;

direct = solve_mocg(registry(1),starts(:,1),directOpts);
result = solve_mocg_instrumented(registry(1),starts(:,1),opts);

verifyTrue(testCase,isfield(result,'exposure'));
verifyEqual(testCase,result.trace.accepted_points, ...
    direct.trace.accepted_points,'AbsTol',0);
verifyEqual(testCase,result.trace.line_trials,direct.trace.line_trials);
verifyEqual(testCase,result.exposure.d_0,abs(starts(2,1)),'AbsTol',1e-14);
verifyEqual(testCase,result.exposure.accepted_post0_count, ...
    size(result.trace.accepted_points,2)-1);
end

function testSolverPreservesLineSearchFailureDiagnostics(testCase)
opts = experiment('TTCGP','paper');
opts.alpha_max = 10;
opts.max_iter = 10;

result = solve_mocg(identical_linear_objectives(),0,opts);

verifyEqual(testCase,result.status,'line_search_failed');
verifyTrue(testCase,isfield(result.diagnostics,'line_search_failure'));
if isfield(result.diagnostics,'line_search_failure')
    failure = result.diagnostics.line_search_failure;
    verifyEqual(testCase,failure.status,'no_bracket');
    verifyEqual(testCase,failure.bracket.a,10,'AbsTol',1e-14);
    verifyLessThan(testCase,failure.bracket.q_a,0);
    verifyLessThan(testCase,failure.bracket.g_a,0);
end
end

function testPaperR2CompetitorClassifiesNonDescentBeforeLineSearch(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
registry = problem_registry(mcodeRoot);
starts = load_initial_points(registry(1), mcodeRoot);

result = solve_mocg(registry(1), starts(:,1), ...
    experiment('PRP+', 'paper_r2'));

verifyEqual(testCase, result.status, 'no_descent');
verifyEqual(testCase, result.iterations, 2);
verifyEqual(testCase, result.diagnostics.no_descent_event.iteration, 2);
verifyGreaterThanOrEqual(testCase, ...
    result.diagnostics.no_descent_event.directional_value, 0);
verifyLessThan(testCase, ...
    result.diagnostics.no_descent_event.steepest_directional_value, 0);
verifyGreaterThan(testCase, ...
    result.diagnostics.no_descent_event.steepest_norm_squared, 0);
verifyEqual(testCase, ...
    -result.diagnostics.no_descent_event.steepest_directional_value, ...
    result.diagnostics.no_descent_event.steepest_norm_squared, ...
    'RelTol', 1e-8, 'AbsTol', 1e-12);
verifyEmpty(testCase, result.diagnostics.line_search_failure);
verifyEqual(testCase, result.diagnostics.line_search_statuses, {'ok'});
end

function testInvalidEtaOnCompetitorIsRejected(testCase)
opts = experiment('PRP+', 'paper');
opts.eta_bar = 1;

verifyError(testCase, @() solve_mocg(identical_quadratics(), 1, opts), ...
    'mcode:UnexpectedEtaBar');
end

function testInvalidWolfeParametersAreRejected(testCase)
opts = experiment('TTCGP','paper');
opts.rho = opts.sigma;

verifyError(testCase,@() solve_mocg(identical_quadratics(),1,opts), ...
    'mcode:InvalidWolfeParameters');
end

function testInvalidStepBoundsAreRejected(testCase)
opts = experiment('TTCGP','paper');
opts.alpha_min = -1;

verifyError(testCase,@() solve_mocg(identical_quadratics(),1,opts), ...
    'mcode:InvalidStepBounds');
end

function testInvalidLineSearchBudgetIsRejected(testCase)
opts = experiment('TTCGP','paper');
opts.line_search_max_trials = 2.5;

verifyError(testCase,@() solve_mocg(identical_quadratics(),1,opts), ...
    'mcode:InvalidLineSearchBudget');
end

function testLegacyTTCGPMatchesFreshSourceOnSensitiveTE6Trial(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
registry = problem_registry(mcodeRoot);
prob = registry(13);
starts = load_initial_points(prob, mcodeRoot);

result = solve_mocg(prob, starts(:,2), experiment('TTCGP', 'legacy'));
expectedF = [-11.469837091508705-2*pi*1i; -346.56453281225254];
tolerance = 1e-10+1e-8*max(1, abs(expectedF));

verifyEqual(testCase, result.status, 'converged');
verifyEqual(testCase, result.iterations, 8);
verifyEqual(testCase, result.legacy_counts.NV, 9);
verifyLessThanOrEqual(testCase, abs(result.F-expectedF), tolerance);
end

function testLegacyPRPUsesArchivedStoppingPrecision(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
registry = problem_registry(mcodeRoot);
prob = registry(19);
starts = load_initial_points(prob, mcodeRoot);

opts = experiment('PRP+', 'legacy');
result = solve_mocg(prob, starts(:,54), opts);
expectedF = [0.054334576725178989; 18.406693874552587];
tolerance = 1e-10+1e-8*max(1, abs(expectedF));

verifyEqual(testCase, opts.theta_tol, 5*sqrt(2.22e-16));
verifyEqual(testCase, result.status, 'converged');
verifyEqual(testCase, result.iterations, 157);
verifyEqual(testCase, result.legacy_counts.NV, 158);
verifyLessThanOrEqual(testCase, abs(result.F-expectedF), tolerance);
end

function prob = identical_quadratics()
prob = struct('legacy_index', 0, 'paper_label', 'unit-quadratic', ...
    'm', 2, 'n', 1, ...
    'value', @(x) [0.5*x(1)^2; 0.5*x(1)^2], ...
    'jacobian', @(x) [x(1); x(1)], ...
    'legacy_jacobian', @(x) [x(1); x(1)]);
end

function prob = identical_linear_objectives()
prob = struct('legacy_index',0,'paper_label','unit-linear', ...
    'm',2,'n',1,'value',@(x) [-x(1);-x(1)], ...
    'jacobian',@(x) [-1;-1],'legacy_jacobian',@(x) [-1;-1]);
end
