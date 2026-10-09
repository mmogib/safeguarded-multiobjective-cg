function result = steepest_dir(J, qpMode)
%STEEPEST_DIR Solve min_{t,v} t + 1/2||v||^2, J_i v <= t.

arguments
    J (:,:) double
    qpMode (1,:) char {mustBeMember(qpMode, {'legacy','corrected'})}
end

[m, n] = size(J);
result = struct('status', 'qp_failed', 'v', nan(n,1), 't', NaN, ...
    'theta', NaN, 'weights', nan(m,1), 'exitflag', NaN, ...
    'output', struct(), 'qp_time', 0);

if any(~isfinite(J), 'all')
    result.status = 'nonfinite';
    return
end

started = tic;
if strcmp(qpMode, 'legacy')
    % Display is the only overridden legacy option. Capturing thousands of
    % default progress messages with evalc makes capped runs pathologically
    % slow while leaving the numerical call unchanged.
    persistent legacyOptions
    if isempty(legacyOptions)
        legacyOptions = optimoptions('quadprog', 'Display', 'off');
    end
    H = diag([0; ones(n,1)]);
    linear = [1; zeros(n,1)];
    A = [-ones(m,1), J];
    b = zeros(m,1);
    initial = ones(n+1,1);
    [z, objective, exitflag, output, lambda] = quadprog( ...
        H, linear, A, b, [], [], [], [], initial, legacyOptions);
    result.qp_time = toc(started);
    result.exitflag = exitflag;
    result.output = output;
    if exitflag <= 0 || isempty(z)
        return
    end
    result.t = z(1);
    result.v = z(2:end);
    result.theta = objective;
    result.weights = lambda.ineqlin;
else
    % The dual simplex QP has no unregularized t-variable.  Scaling its
    % objective leaves the minimizer unchanged and prevents tiny Jacobians
    % from being misclassified as an unbounded primal problem by quadprog.
    dualHessian = J*J';
    dualScale = max(abs(dualHessian), [], 'all');
    if dualScale == 0
        weights = ones(m,1)/m;
        exitflag = 1;
        output = struct('message','Zero Jacobian: simplex center returned.');
    else
        persistent correctedOptions
        if isempty(correctedOptions)
            correctedOptions = optimoptions('quadprog', ...
                'Algorithm','interior-point-convex','Display','off', ...
                'OptimalityTolerance',1e-12, ...
                'ConstraintTolerance',1e-12, ...
                'StepTolerance',1e-14,'MaxIterations',1000);
        end
        initialWeights = ones(m,1)/m;
        [weights, ~, exitflag, output] = quadprog( ...
            dualHessian/dualScale, zeros(m,1), [], [], ...
            ones(1,m), 1, zeros(m,1), [], initialWeights, correctedOptions);
    end
    result.qp_time = toc(started);
    result.exitflag = exitflag;
    result.output = output;
    if exitflag <= 0 || isempty(weights)
        return
    end
    weights = max(weights,0);
    weights = weights/sum(weights);
    result.weights = weights;
    result.v = -J'*weights;
    result.t = max(J*result.v);
    result.theta = result.t+0.5*norm(result.v)^2;
end
if any(~isfinite([result.t; result.v; result.theta; result.weights]))
    result.status = 'nonfinite';
else
    result.status = 'ok';
end
end
