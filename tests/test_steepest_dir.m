function tests = test_steepest_dir
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'core'));
end

function testKnownTwoObjectiveSolution(testCase)
J = eye(2);
result = steepest_dir(J, 'corrected');

verifyEqual(testCase, result.status, 'ok');
verifyEqual(testCase, result.v, [-0.5; -0.5], 'AbsTol', 1e-8);
verifyEqual(testCase, result.t, -0.5, 'AbsTol', 1e-8);
verifyEqual(testCase, result.theta, -0.25, 'AbsTol', 1e-8);
verifyEqual(testCase, result.t, -norm(result.v)^2, 'AbsTol', 1e-8);
verifyEqual(testCase, result.theta, -0.5*norm(result.v)^2, 'AbsTol', 1e-8);
verifyEqual(testCase, sum(result.weights), 1, 'AbsTol', 1e-8);
verifyEqual(testCase, result.v + J'*result.weights, zeros(2,1), 'AbsTol', 1e-8);
verifyGreaterThanOrEqual(testCase, result.qp_time, 0);
end

function testLegacyAndCorrectedPoliciesSolveSameSimpleQP(testCase)
J = [2, 0; 0, 1; -1, 1];
legacy = steepest_dir(J, 'legacy');
corrected = steepest_dir(J, 'corrected');

verifyEqual(testCase, legacy.status, 'ok');
verifyEqual(testCase, corrected.status, 'ok');
verifyEqual(testCase, legacy.v, corrected.v, 'AbsTol', 1e-7);
verifyEqual(testCase, legacy.theta, corrected.theta, 'AbsTol', 1e-8);
end

function testNonfiniteJacobianDoesNotCallQP(testCase)
result = steepest_dir([1, NaN; 0, 1], 'corrected');

verifyEqual(testCase, result.status, 'nonfinite');
verifyTrue(testCase, isnan(result.theta));
verifyEqual(testCase, result.qp_time, 0);
end

function testCorrectedQPHandlesSmallPositiveJacobianWithoutFalseUnbounded(testCase)
J = [1.18867e-5; 4.54155e-5];

result = steepest_dir(J, 'corrected');

verifyEqual(testCase, result.status, 'ok');
verifyEqual(testCase, result.v, -J(1), 'AbsTol', 1e-12);
verifyEqual(testCase, result.t, -J(1)^2, 'AbsTol', 1e-16);
verifyEqual(testCase, result.theta, -0.5*J(1)^2, 'AbsTol', 1e-16);
verifyEqual(testCase, result.weights, [1;0], 'AbsTol', 1e-7);
end
