function tests = test_tier3_certificates
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'bench'));
testCase.TestData.registry = tier3_problem_registry();
end

function testScalarSublevelRadiusImplication(testCase)
t = [-100 -3 -1 -0.2 0 0.2 1 3 100];
value = oscillatory_kernel(t);
verifyGreaterThanOrEqual(testCase,value,zeros(size(value)));

for k = 1:numel(t)
    radius = oscillatory_sublevel_radius(value(k));
    verifyGreaterThanOrEqual(testCase,radius,abs(t(k)));
end
verifyEqual(testCase,oscillatory_sublevel_radius(0),1);
verifyError(testCase,@() oscillatory_sublevel_radius(-1), ...
    'mcode:InvalidSublevelUpperBound');
end

function testEveryPrescribedStartHasFiniteExplicitCertificate(testCase)
report = certify_tier3_levelsets(testCase.TestData.registry);

verifyEqual(testCase,height(report),1000);
verifyEqual(testCase,unique(report.problem,'stable'),"NC10-"+string(1:10)');
for d = 1:10
    verifyEqual(testCase,sum(report.problem=="NC10-"+string(d)),100);
end
verifyTrue(testCase,all(report.passed));
verifyTrue(testCase,all(isfinite(report.x1_abs_bound)));
verifyTrue(testCase,all(isfinite(report.x2_abs_bound)));
verifyGreaterThan(testCase,report.x1_abs_bound,zeros(height(report),1));
verifyGreaterThan(testCase,report.x2_abs_bound,zeros(height(report),1));
verifyEqual(testCase,numel(unique(report.proof_id)),10);
end

function testCertificateBoundsCoverConstructedLevelSetPoints(testCase)
registry = testCase.TestData.registry;
oldState = rng;
cleanup = onCleanup(@() rng(oldState)); %#ok<NASGU>
rng(20261002,'twister');
for d = 1:10
    starts = tier3_starts(registry(d));
    for startId = [1 37 100]
        x0 = starts(:,startId);
        certificate = tier3_levelset_certificate(registry(d),x0);
        candidates = [x0,2*certificate.abs_bound.*(rand(2,300)-0.5)];
        values = zeros(2,size(candidates,2));
        for q = 1:size(candidates,2)
            values(:,q) = registry(d).value(candidates(:,q));
        end
        inLevelSet = all(values <= registry(d).value(x0),1);
        verifyLessThanOrEqual(testCase,abs(candidates(:,inLevelSet)), ...
            certificate.abs_bound+1e-12);
    end
end
end
