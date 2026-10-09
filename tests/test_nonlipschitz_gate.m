function tests = test_nonlipschitz_gate
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'bench'));
testCase.TestData.registry = nonlipschitz_problem_registry();
end

function testStrictRegularWitnessCertifiesAccessibility(testCase)
prob = testCase.TestData.registry(6); % NL10-1
arg = nonlipschitz_arguments(prob);
[certified,detail] = is_accessible_witness(prob,arg(1),[3;3],[0;0]);

verifyTrue(testCase,certified);
verifyEqual(testCase,detail.status,'certified_accessible');
verifyLessThanOrEqual(testCase,detail.component_differences,0);
verifyGreaterThan(testCase,detail.gradient_norm,0);
end

function testDegenerateZeroIsNeverCertified(testCase)
prob = testCase.TestData.registry(10); % NL10-5
args = nonlipschitz_arguments(prob);
[certified,detail] = is_accessible_witness(prob,args(1),[2;2],[0;0]);

verifyFalse(testCase,certified);
verifyEqual(testCase,detail.status,'degenerate_zero');
end

function testExactBoundaryWitnessIsCertified(testCase)
prob = testCase.TestData.registry(6);
args = nonlipschitz_arguments(prob);
x0 = [0;0];
[certified,detail] = is_accessible_witness(prob,args(1),x0,x0);

verifyTrue(testCase,certified);
verifyEqual(testCase,detail.max_difference,0);
end

function testFloatingSearchNeverClaimsInaccessibility(testCase)
prob = testCase.TestData.registry(15); % NL10-10
result = certify_nl10_accessibility(prob,[0.137;-0.219]);

verifyTrue(testCase,ismember(result.status, ...
    {'certified_accessible','unresolved'}));
verifyNotEqual(testCase,result.status,'certified_inaccessible');
verifyTrue(testCase,isfinite(result.best_upper_bound));
end

function testE2ProjectionGateAtRepresentativeStarts(testCase)
registry = testCase.TestData.registry;
for k = 1:5
    starts = nonlipschitz_starts(registry(k));
    for trial = [1 50 100]
        x0 = starts(:,trial);
        witness = registry(k).pareto_projection(x0);
        differences = registry(k).value(witness)-registry(k).value(x0);
        verifyLessThanOrEqual(testCase,differences,1e-12,registry(k).paper_label);
        verifyEqual(testCase,registry(k).singular_value(witness),0, ...
            'AbsTol',1e-12,registry(k).paper_label);
    end
end
end
