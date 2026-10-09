function tests = test_tier3_gradients
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'bench'));
testCase.TestData.registry = tier3_problem_registry();
end

function testZeroDerivativeUsesExactDifferenceQuotientBound(testCase)
h = [-10.^(-(1:14)),10.^(-(1:14))];
quotient = oscillatory_kernel(h)./h;
verifyLessThanOrEqual(testCase,abs(quotient),2*abs(h)+eps);
verifyEqual(testCase,oscillatory_kernel(0),0);
[~,derivative] = oscillatory_kernel(0);
verifyEqual(testCase,derivative,0);
end

function testPhaseAwareAndCompositeGradientGate(testCase)
report = validate_tier3_gradients(testCase.TestData.registry);

verifyGreaterThan(testCase,height(report.zero),0);
verifyGreaterThan(testCase,height(report.phase),0);
verifyEqual(testCase,height(report.composite),46);
verifyTrue(testCase,all(report.zero.passed));
verifyTrue(testCase,all(report.phase.passed),phase_failures(report.phase));
verifyTrue(testCase,all(report.composite.passed), ...
    strjoin(cellstr(report.composite.problem(~report.composite.passed)+"/"+ ...
    report.composite.point_id(~report.composite.passed)),', '));
end

function message = phase_failures(report)
failed = report(~report.passed,:);
message = strjoin(cellstr("z="+string(failed.phase)+ ...
    ", error="+string(failed.relative_error)),', ');
end
