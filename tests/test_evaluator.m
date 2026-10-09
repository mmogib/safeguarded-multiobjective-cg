function tests = test_evaluator
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
addpath(fullfile(mcodeRoot, 'core'));
registry = problem_registry(mcodeRoot);
testCase.TestData.problem = registry(1);
end

function testScalingJacobianIsCountedAtConstruction(testCase)
prob = testCase.TestData.problem;
x0 = [1; 2];
evaluator = Evaluator(prob, x0, 'corrected');

counts = evaluator.counts();
expectedScale = [1/4; 1/8];
verifyEqual(testCase, evaluator.scale, expectedScale, 'AbsTol', 1e-15);
verifyEqual(testCase, counts.vector_F, 0);
verifyEqual(testCase, counts.vector_J, 1);
verifyEqual(testCase, counts.component_F, 0);
verifyEqual(testCase, counts.component_J, prob.m);
verifyGreaterThanOrEqual(testCase, counts.evaluation_time, 0);
end

function testValueAndJacobianCachesAreIndependentAndLazy(testCase)
prob = testCase.TestData.problem;
x0 = [1; 2];
x = [2; 3];
evaluator = Evaluator(prob, x0, 'corrected');

F1 = evaluator.value(x);
F2 = evaluator.value(x);
afterF = evaluator.counts();
J1 = evaluator.jacobian(x);
J2 = evaluator.jacobian(x);
afterJ = evaluator.counts();

verifyEqual(testCase, F1, F2);
verifyEqual(testCase, J1, J2);
verifyEqual(testCase, afterF.vector_F, 1);
verifyEqual(testCase, afterF.vector_J, 1);
verifyEqual(testCase, afterJ.vector_F, 1);
verifyEqual(testCase, afterJ.vector_J, 2);
verifyEqual(testCase, F1, evaluator.scale .* prob.value(x), 'AbsTol', 1e-15);
verifyEqual(testCase, J1, evaluator.scale .* prob.jacobian(x), 'AbsTol', 1e-15);
end

function testCacheKeysUseExactFullVectorEquality(testCase)
prob = testCase.TestData.problem;
x0 = [1; 2];
evaluator = Evaluator(prob, x0, 'corrected');

evaluator.value(x0);
xNear = x0;
xNear(1) = xNear(1) + eps(xNear(1));
evaluator.value(xNear);

counts = evaluator.counts();
verifyEqual(testCase, counts.vector_F, 2);
end

function testIterationResetRetainsOnlyRequestedPoints(testCase)
prob = testCase.TestData.problem;
x0 = [1; 2];
x1 = [2; 3];
trial = [1.5; 2.5];
evaluator = Evaluator(prob, x0, 'corrected');
evaluator.value(x0);
evaluator.value(x1);
evaluator.value(trial);

evaluator.begin_iteration(x1, x0);
evaluator.value(x0);
evaluator.value(x1);
beforeRevisit = evaluator.counts();
evaluator.value(trial);
afterRevisit = evaluator.counts();

verifyEqual(testCase, beforeRevisit.vector_F, 3);
verifyEqual(testCase, afterRevisit.vector_F, 4);
end

function testLegacyJacobianModeUsesArchivedDerivative(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
registry = problem_registry(mcodeRoot);
prob = registry(28);
x0 = [0.3; -0.2];
legacy = Evaluator(prob, x0, 'legacy');
corrected = Evaluator(prob, x0, 'corrected');

verifyNotEqual(testCase, legacy.jacobian(x0), corrected.jacobian(x0));
verifyEqual(testCase, legacy.jacobian(x0), ...
    legacy.scale .* prob.legacy_jacobian(x0), 'AbsTol', 1e-15);
end

function testUnscaledValueReusesScaledCache(testCase)
prob = testCase.TestData.problem;
x0 = [1; 2];
evaluator = Evaluator(prob, x0, 'corrected');

raw = evaluator.unscaled_value(x0);
afterFirst = evaluator.counts();
rawAgain = evaluator.unscaled_value(x0);
afterSecond = evaluator.counts();

verifyEqual(testCase, raw, prob.value(x0), 'AbsTol', 1e-15);
verifyEqual(testCase, rawAgain, raw);
verifyEqual(testCase, afterFirst.vector_F, 1);
verifyEqual(testCase, afterSecond.vector_F, 1);
end
