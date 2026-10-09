function report = certify_tier3_levelsets(registry)
%CERTIFY_TIER3_LEVELSETS Instantiate all analytic NC10 certificates.

if nargin == 0
    registry = tier3_problem_registry();
end
rowCount = 100*numel(registry);
problem = strings(rowCount,1);
startId = zeros(rowCount,1);
F1Upper = zeros(rowCount,1);
F2Upper = zeros(rowCount,1);
r1 = zeros(rowCount,1);
r2 = zeros(rowCount,1);
x1AbsBound = zeros(rowCount,1);
x2AbsBound = zeros(rowCount,1);
proofId = strings(rowCount,1);
passed = false(rowCount,1);
row = 0;

for p = 1:numel(registry)
    starts = tier3_starts(registry(p));
    for start = 1:size(starts,2)
        row = row+1;
        certificate = tier3_levelset_certificate(registry(p),starts(:,start));
        problem(row) = certificate.problem;
        startId(row) = start;
        F1Upper(row) = certificate.objective_upper(1);
        F2Upper(row) = certificate.objective_upper(2);
        r1(row) = certificate.argument_radius(1);
        r2(row) = certificate.argument_radius(2);
        x1AbsBound(row) = certificate.abs_bound(1);
        x2AbsBound(row) = certificate.abs_bound(2);
        proofId(row) = certificate.proof_id;
        passed(row) = certificate.passed;
    end
end

report = table(problem,startId,F1Upper,F2Upper,r1,r2,x1AbsBound, ...
    x2AbsBound,proofId,passed,'VariableNames', ...
    {'problem','start_id','F1_upper','F2_upper','r1','r2', ...
     'x1_abs_bound','x2_abs_bound','proof_id','passed'});
end

