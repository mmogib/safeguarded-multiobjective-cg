function tests = test_problem_registry
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
testCase.TestData.mcodeRoot = mcodeRoot;
end

function testRegistryHasAllLegacyRows(testCase)
registry = problem_registry(testCase.TestData.mcodeRoot);

verifyEqual(testCase, numel(registry), 41);
verifyEqual(testCase, [registry.legacy_index], 1:41);
verifyEqual(testCase, [registry.m], [2 * ones(1, 29), 3 * ones(1, 12)]);
verifyEqual(testCase, [registry.n], ...
    [2 1 1 2 10 100 1000 1 2 2 2 10 2 3 2 1 1 4 2 1 2 2 5 4 2 2 2 2 3 ...
     2 15 30 50 2 2 10 200 100 10 3 2]);
end

function testRegistryPreservesKnownSourceMappings(testCase)
registry = problem_registry(testCase.TestData.mcodeRoot);

verifyEqual(testCase, registry(8).paper_label, 'MLF1');
verifyEqual(testCase, registry(8).source_file, 'DGO1.mat');
verifyEqual(testCase, registry(14).paper_label, 'TE7');
verifyEqual(testCase, registry(14).m, 2);
verifyEqual(testCase, registry(37).source_file, 'FDS2000.mat');
verifyEqual(testCase, registry(37).n, 200);
verifyEqual(testCase, registry(38).source_file, 'FDS100.mat');
verifyEqual(testCase, registry(38).n, 100);
verifyTrue(testCase, registry(41).initpoints_available);
end

function testBK1ValuesAndJacobian(testCase)
registry = problem_registry(testCase.TestData.mcodeRoot);
x = [1; 2];

verifyEqual(testCase, registry(1).value(x), [5; 25], 'AbsTol', 1e-14);
verifyEqual(testCase, registry(1).jacobian(x), [2 4; -8 -6], 'AbsTol', 1e-14);
verifyEqual(testCase, registry(1).legacy_jacobian(x), [2 4; -8 -6], 'AbsTol', 1e-14);
end

function testAP3CorrectedAndLegacyJacobiansAreExplicit(testCase)
registry = problem_registry(testCase.TestData.mcodeRoot);
x = [0.3; -0.2];

corrected = registry(28).jacobian(x);
legacy = registry(28).legacy_jacobian(x);
expected = [(x(1) - 4)^3, 2 * (x(2) - 2)^3; ...
            -4 * x(1) * (x(2) - x(1)^2) - 2 * (1 - x(1)), ...
             2 * (x(2) - x(1)^2)];

verifyEqual(testCase, corrected, expected, 'AbsTol', 1e-13);
verifyEqual(testCase, legacy(1, 1), (x(1) - 1)^3, 'AbsTol', 1e-13);
verifyNotEqual(testCase, corrected(1, 1), legacy(1, 1));
end

function testProblemHandlesReturnColumnValuesAndMByNJacobians(testCase)
registry = problem_registry(testCase.TestData.mcodeRoot);

for k = 1:numel(registry)
    x = registry(k).safe_point;
    F = registry(k).value(x);
    J = registry(k).jacobian(x);
    verifySize(testCase, F, [registry(k).m, 1], registry(k).paper_label);
    verifySize(testCase, J, [registry(k).m, registry(k).n], registry(k).paper_label);
    verifyTrue(testCase, all(isfinite(F)), registry(k).paper_label);
    verifyTrue(testCase, all(isfinite(J), 'all'), registry(k).paper_label);
end
end
