function report = validate_tier3_gradients(registry)
%VALIDATE_TIER3_GRADIENTS Analytic-zero and phase-aware NC10 validation.

if nargin == 0
    registry = tier3_problem_registry();
end
report = struct('zero',zero_derivative_checks(), ...
    'phase',phase_aware_checks(), ...
    'composite',composite_chain_checks(registry));
end

function report = zero_derivative_checks()
magnitudes = 10.^(-(1:14));
h = [-magnitudes,magnitudes]';
value = oscillatory_kernel(h);
quotient = value./h;
bound = 2*abs(h);
passed = abs(quotient) <= bound+8*eps(max(1,bound));
report = table(h,quotient,bound,passed);
end

function report = phase_aware_checks()
nValues = [1 4 16 64 256 1024];
phase = zeros(2*numel(nValues),1);
t = zeros(size(phase));
analytic = zeros(size(phase));
finiteDifference = zeros(size(phase));
relativeError = zeros(size(phase));
passed = false(size(phase));
row = 0;
for n = nValues
    for z = [2*pi*n,(2*n+1)*pi]
        row = row+1;
        phase(row) = z;
        t(row) = 1/sqrt(z);
        [~,analytic(row)] = oscillatory_kernel(t(row));
        approximations = phase_differences(z,10.^(-(1:6)));
        errors = abs(approximations-analytic(row));
        [error,best] = min(errors);
        finiteDifference(row) = approximations(best);
        relativeError(row) = error/max(1,abs(analytic(row)));
        passed(row) = relativeError(row) <= 5e-6;
    end
end
report = table(phase,t,analytic,finiteDifference,relativeError,passed, ...
    'VariableNames',{'phase','t','analytic','finite_difference', ...
    'relative_error','passed'});
end

function approximations = phase_differences(z,deltas)
approximations = zeros(size(deltas));
for k = 1:numel(deltas)
    delta = deltas(k);
    tPlus = 1/sqrt(z+delta);
    tMinus = 1/sqrt(z-delta);
    approximations(k) = (oscillatory_kernel(tPlus)- ...
        oscillatory_kernel(tMinus))/(tPlus-tMinus);
end
end

function report = composite_chain_checks(registry)
rowCount = numel(registry)+sum(arrayfun(@(p) ...
    numel(nonlipschitz_arguments(p)),registry));
problem = strings(rowCount,1);
pointId = strings(rowCount,1);
maxAbsError = zeros(rowCount,1);
relativeError = zeros(rowCount,1);
passed = false(rowCount,1);
row = 0;

for p = 1:numel(registry)
    prob = registry(p);
    args = nonlipschitz_arguments(prob);
    points = {prob.safe_point};
    pointNames = "safe";
    for j = 1:numel(args)
        points{end+1} = args(j).validation_anchor; %#ok<AGROW>
        pointNames(end+1) = "zero_"+string(args(j).argument_id); %#ok<AGROW>
    end
    for q = 1:numel(points)
        row = row+1;
        x = points{q};
        implemented = prob.jacobian(x);
        reconstructed = reconstruct_jacobian(prob,args,x);
        error = norm(implemented-reconstructed,inf);
        scale = max(1,norm(reconstructed,inf));
        problem(row) = prob.paper_label;
        pointId(row) = pointNames(q);
        maxAbsError(row) = error;
        relativeError(row) = error/scale;
        passed(row) = all(isfinite(implemented),'all') && ...
            relativeError(row) <= 2e-13;
    end
end
report = table(problem,pointId,maxAbsError,relativeError,passed, ...
    'VariableNames',{'problem','point_id','max_abs_error', ...
    'relative_error','passed'});
end

function jacobian = reconstruct_jacobian(prob,args,x)
jacobian = zeros(prob.m,prob.n);
for j = 1:numel(args)
    [~,derivative] = oscillatory_kernel(args(j).value(x));
    contribution = derivative*args(j).gradient(x)';
    for row = args(j).objective_rows
        jacobian(row,:) = jacobian(row,:)+contribution;
    end
end
end

