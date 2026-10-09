function tests = test_tier3_problems
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'));
testCase.TestData.registry = tier3_problem_registry();
end

function testKernelHasTrueValuesAtZeroAndNoNumericalDeadZone(testCase)
[value,derivative] = oscillatory_kernel(0);
verifyEqual(testCase,value,0);
verifyEqual(testCase,derivative,0);

t = 1e-14;
[value,derivative] = oscillatory_kernel(t);
verifyEqual(testCase,value,t^2*(1+sin(1/t^2)),'AbsTol',0);
verifyEqual(testCase,derivative, ...
    2*t+2*t*sin(1/t^2)-(2/t)*cos(1/t^2),'AbsTol',0);
verifyNotEqual(testCase,derivative,0);
end

function testRegistryContainsTenInheritedTemplates(testCase)
registry = testCase.TestData.registry;
verifyEqual(testCase,numel(registry),10);
verifyEqual(testCase,string({registry.paper_label}),"NC10-"+string(1:10));
verifyEqual(testCase,[registry.n],2*ones(1,10));
verifyEqual(testCase,[registry.m],2*ones(1,10));
verifyEqual(testCase,string({registry.set_name}),repmat("NC10",1,10));

expectedLower = [-3 -2 -2 -5 -2 0 -3 -2 -3 -2; ...
                 -3 -2 -2 -5 -2 0 -3 -2 -3 -2];
expectedUpper = [3 2 2 5 2 6 3 5 3 6; ...
                 3 2 2 5 2 6 3 5 3 6];
for d = 1:10
    verifyEqual(testCase,registry(d).lower_bound,expectedLower(:,d));
    verifyEqual(testCase,registry(d).upper_bound,expectedUpper(:,d));
end
end

function testFirstTemplateUsesOscillatoryKernel(testCase)
prob = testCase.TestData.registry(1);
x = [0.5;-0.25];
[p1,d1] = oscillatory_kernel(x(1));
[p2,d2] = oscillatory_kernel(x(2)-1);
[p3,d3] = oscillatory_kernel(x(1)-2);
[p4,d4] = oscillatory_kernel(x(2)+1);

verifyEqual(testCase,prob.value(x),[p1+p2;p3+p4],'AbsTol',1e-14);
verifyEqual(testCase,prob.jacobian(x),[d1,d2;d3,d4], ...
    'RelTol',1e-14);
end

function testStartsArePairedWithInheritedFamily(testCase)
registry = testCase.TestData.registry;
inherited = nonlipschitz_problem_registry();
inherited = inherited(strcmp({inherited.set_name},'NL10'));
for d = 1:10
    [starts,metadata] = tier3_starts(registry(d));
    inheritedStarts = nonlipschitz_starts(inherited(d));
    verifySize(testCase,starts,[2 100]);
    verifyEqual(testCase,starts,inheritedStarts,'AbsTol',0);
    verifyEqual(testCase,metadata.seed,registry(d).start_seed);
end
end

function testArgumentGeometryIsSharedButTierIsExplicit(testCase)
registry = testCase.TestData.registry;
expected = [4 4 4 4 4 2 2 4 4 4];
for d = 1:10
    args = nonlipschitz_arguments(registry(d));
    verifyEqual(testCase,numel(args),expected(d),registry(d).paper_label);
end

args = nonlipschitz_arguments(registry(5));
verifyEqual(testCase,args(1).value([0;0]),0);
verifyEqual(testCase,norm(args(1).gradient([0;0])),0);
end

