function tests = test_nonlipschitz_problems
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'));
testCase.TestData.root = root;
end

function testSeparateRegistryPreservesLegacyRows(testCase)
legacy = problem_registry(testCase.TestData.root);
registry = nonlipschitz_problem_registry();

verifyEqual(testCase,numel(legacy),41);
verifyEqual(testCase,[legacy.legacy_index],1:41);
verifyEqual(testCase,numel(registry),15);
verifyEqual(testCase,string({registry.paper_label}), ...
    ["E2-1","E2-2","E2-3","E2-4","E2-5", ...
     "NL10-1","NL10-2","NL10-3","NL10-4","NL10-5", ...
     "NL10-6","NL10-7","NL10-8","NL10-9","NL10-10"]);
verifyEqual(testCase,[registry.n],[2 2 2 2 10 2 2 2 2 2 2 2 2 2 2]);
verifyEqual(testCase,[registry.m],[2 2 2 2 3 2 2 2 2 2 2 2 2 2 2]);
end

function testE2OneClosedForm(testCase)
registry = nonlipschitz_problem_registry();
prob = registry(1);
x = [0.25;-0.4];
[p,dp] = holder_kernel(x(2));

verifyEqual(testCase,prob.value(x),[(x(1)+1)^2+p;(x(1)-1)^2+p], ...
    'AbsTol',1e-14);
verifyEqual(testCase,prob.jacobian(x), ...
    [2*(x(1)+1),dp;2*(x(1)-1),dp],'AbsTol',1e-14);
verifyEqual(testCase,prob.jacobian(x),prob.legacy_jacobian(x), ...
    'AbsTol',0);
end

function testE2FiveHasThreeByTenJacobian(testCase)
registry = nonlipschitz_problem_registry();
prob = registry(5);
x = (1:10)'/20;

verifySize(testCase,prob.value(x),[3 1]);
verifySize(testCase,prob.jacobian(x),[3 10]);
verifyTrue(testCase,all(isfinite(prob.jacobian(x)),'all'));
end

function testNL10OneUsesHolderKernelAndAnalyticJacobian(testCase)
registry = nonlipschitz_problem_registry();
prob = registry(6);
x = [0.5;-0.25];
[p1,d1] = holder_kernel(x(1));
[p2,d2] = holder_kernel(x(2)-1);
[p3,d3] = holder_kernel(x(1)-2);
[p4,d4] = holder_kernel(x(2)+1);

verifyEqual(testCase,prob.value(x),[p1+p2;p3+p4],'AbsTol',1e-14);
verifyEqual(testCase,prob.jacobian(x),[d1,d2;d3,d4], ...
    'AbsTol',1e-14);
end

function testStartsAreDeterministicAndOffSingularSet(testCase)
registry = nonlipschitz_problem_registry();
for k = 1:numel(registry)
    [a,metaA] = nonlipschitz_starts(registry(k));
    [b,metaB] = nonlipschitz_starts(registry(k));
    verifySize(testCase,a,[registry(k).n 100],registry(k).paper_label);
    verifyEqual(testCase,a,b,'AbsTol',0,registry(k).paper_label);
    verifyEqual(testCase,metaA,metaB,registry(k).paper_label);
    if strcmp(registry(k).set_name,'E2')
        for trial = 1:100
            verifyNotEqual(testCase,registry(k).singular_value(a(:,trial)),0, ...
                registry(k).paper_label);
        end
    else
        verifyEqual(testCase,metaA.seed,20260928);
        verifyGreaterThanOrEqual(testCase,a,registry(k).lower_bound);
        verifyLessThanOrEqual(testCase,a,registry(k).upper_bound);
    end
end
end

function testE2ParetoProjectionDominatesSampledStarts(testCase)
registry = nonlipschitz_problem_registry();
for k = 1:5
    starts = nonlipschitz_starts(registry(k));
    for trial = [1 18 41 73 100]
        x0 = starts(:,trial);
        projected = registry(k).pareto_projection(x0);
        verifyLessThanOrEqual(testCase,registry(k).value(projected), ...
            registry(k).value(x0)+1e-13,registry(k).paper_label);
        verifyEqual(testCase,registry(k).singular_value(projected),0, ...
            'AbsTol',1e-13,registry(k).paper_label);
    end
end
end

function testNL10BoxesMatchInheritedDriver(testCase)
registry = nonlipschitz_problem_registry();
expectedLower = [-3 -2 -2 -5 -2 0 -3 -2 -3 -2; ...
                 -3 -2 -2 -5 -2 0 -3 -2 -3 -2];
expectedUpper = [3 2 2 5 2 6 3 5 3 6; ...
                 3 2 2 5 2 6 3 5 3 6];
for d = 1:10
    verifyEqual(testCase,registry(5+d).lower_bound,expectedLower(:,d));
    verifyEqual(testCase,registry(5+d).upper_bound,expectedUpper(:,d));
end
end
