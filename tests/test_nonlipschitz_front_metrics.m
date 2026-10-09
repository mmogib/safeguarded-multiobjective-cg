function tests = test_nonlipschitz_front_metrics
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'bench'));
end

function testE2UsesAnalyticFrontAndDetectsOffFrontGap(testCase)
rows = [make_row('E2','E2-1','A','converged',[0;4]), ...
        make_row('E2','E2-1','A','converged',[1;1]), ...
        make_row('E2','E2-1','A','converged',[4;0]), ...
        make_row('E2','E2-1','B','converged',[1;5]), ...
        make_row('E2','E2-1','B','converged',[2;2]), ...
        make_row('E2','E2-1','B','converged',[5;1])];

metrics = nonlipschitz_front_metrics(rows);

a = metrics(metrics.method=="A",:);
b = metrics(metrics.method=="B",:);
verifyEqual(testCase,a.reference_type,"analytic_exact_front");
verifyEqual(testCase,a.median_reference_distance,0,'AbsTol',1e-14);
verifyEqual(testCase,a.endpoint_gap_max,0,'AbsTol',1e-14);
verifyGreaterThan(testCase,b.median_reference_distance,0);
verifyFalse(testCase,any(contains(lower(metrics.Properties.VariableNames), ...
    'purity')));
end

function testNL10IsExplicitlyPooledUnionRelative(testCase)
rows = [make_row('NL10','NL10-1','A','converged',[0;2]), ...
        make_row('NL10','NL10-1','A','converged',[2;0]), ...
        make_row('NL10','NL10-1','B','converged',[1;1]), ...
        make_row('NL10','NL10-1','B','no_descent',[3;3])];

metrics = nonlipschitz_front_metrics(rows);

verifyTrue(testCase,all(metrics.reference_type=="pooled_union_relative"));
verifyTrue(testCase,all(metrics.union_contribution_fraction>=0 & ...
    metrics.union_contribution_fraction<=1));
end

function row = make_row(setName,problem,method,status,F)
row = struct('set_name',setName,'problem',problem,'method',method, ...
    'status',status,'F',F);
end

