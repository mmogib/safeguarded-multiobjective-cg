function tests = test_nonlipschitz_gradients
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'bench'));
testCase.TestData.registry = nonlipschitz_problem_registry();
end

function testKernelDerivativeIncludesZeroAnalytically(testCase)
[value,derivative] = holder_kernel(0);
verifyEqual(testCase,value,0);
verifyEqual(testCase,derivative,0);

h = 10.^(-(1:12));
right = arrayfun(@(v) holder_kernel(v)/v,h);
left = arrayfun(@(v) holder_kernel(-v)/(-v),h);
verifyLessThan(testCase,abs(right(end)),abs(right(1)));
verifyLessThan(testCase,abs(left(end)),abs(left(1)));
verifyLessThan(testCase,max(abs([right(end),left(end)])),1e-5);
end

function testCompositeJacobiansAreFiniteAtRegisteredRegularZeros(testCase)
registry = testCase.TestData.registry;
for k = 1:numel(registry)
    args = nonlipschitz_arguments(registry(k));
    for j = 1:numel(args)
        x = args(j).validation_anchor;
        verifyEqual(testCase,args(j).value(x),0,'AbsTol',1e-14, ...
            sprintf('%s/%s',registry(k).paper_label,args(j).argument_id));
        verifyGreaterThan(testCase,norm(args(j).gradient(x)),0);
        J = registry(k).jacobian(x);
        verifyTrue(testCase,isreal(J) && all(isfinite(J),'all'));
    end
end
end

function testTwoSidedAdaptiveCentralDifferencePolicy(testCase)
report = validate_nonlipschitz_gradients(testCase.TestData.registry);

verifyEqual(testCase,height(report),656); % 41 arguments x 2 sides x 8 bands
verifyTrue(testCase,all(report.no_crossing));
verifyTrue(testCase,all(report.passed), ...
    strjoin(cellstr(report.problem(~report.passed)+"/"+ ...
        report.argument(~report.passed)+"/"+string(report.distance(~report.passed))),', '));
verifyEqual(testCase,unique(report.distance)',sort(10.^(-(1:8))),'AbsTol',0);
end
