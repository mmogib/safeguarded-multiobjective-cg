function result = legacy(evaluator, x, direction, alpha, opts)
%LEGACY Bug-compatible qwolfe/qwolfe3 policy with explicit exit metadata.

result = base_result();
F0 = evaluator.value(x);
J0 = evaluator.jacobian(x);
phi0 = max(legacy_directional_products(J0, direction));
result.phi0 = phi0;
alphaMax = opts.alpha_max;
rhoBar = min(1.1*opts.rho, 0.75*opts.rho+0.25*opts.sigma);
sigmaBar = max(0.9*opts.sigma, 0.25*opts.rho+0.75*opts.sigma);

for trial = 1:opts.max_trials
    result.trials = trial;
    xTrial = x+alpha*direction;
    Ftrial = evaluator.value(xTrial);
    Jtrial = evaluator.jacobian(xTrial);
    phiTrial = max(legacy_directional_products(Jtrial, direction));
    armijo = Ftrial <= F0+alpha*opts.rho*phi0;
    if all(armijo) && abs(phiTrial) <= -opts.sigma*phi0
        result.alpha = alpha;
        result.status = 'ok';
        result.validated = true;
        result.legacy_exit = 'strong_wolfe';
        result.phi_trial = phiTrial;
        result.legacy_F = result.legacy_F+evaluator.problem.m;
        result.legacy_J = result.legacy_J+evaluator.problem.m;
        return
    end

    xMax = x+alphaMax*direction;
    Fmax = evaluator.value(xMax);
    Jmax = evaluator.jacobian(xMax);
    maxArmijo = Fmax <= F0+alphaMax*opts.rho*phi0;
    maxGrad = legacy_directional_products(Jmax, direction) < opts.sigma*phi0;
    if all(maxArmijo) && all(maxGrad)
        result.alpha = alphaMax;
        result.status = 'alphamax_unvalidated';
        result.legacy_exit = 'alphamax';
        result.phi_trial = max(legacy_directional_products(Jmax, direction));
        result.legacy_F = result.legacy_F+evaluator.problem.m;
        result.legacy_J = result.legacy_J+evaluator.problem.m;
        return
    end

    componentGrad = legacy_directional_products(Jtrial, direction);
    violator = find(~armijo | componentGrad > -opts.sigma*phi0, 1, 'first');
    if ~isempty(violator)
        result.legacy_F = result.legacy_F+1;
        result.legacy_J = result.legacy_J+1;
        alphaMax = alpha;
        [alpha, fAdd, jAdd, nestedExit] = derivative_search( ...
            evaluator, x, direction, alphaMax, violator, phi0, ...
            sigmaBar, rhoBar);
        result.legacy_F = result.legacy_F+fAdd;
        result.legacy_J = result.legacy_J+jAdd;
        result.legacy_exit = nestedExit;
    else
        alpha = (min(1.1*alpha, alphaMax)+alphaMax)/2;
    end

    if alpha <= opts.alpha_min
        result.alpha = opts.alpha_min;
        result.status = 'min_step';
        result.legacy_exit = 'alphamin';
        result.phi_trial = max(legacy_directional_products( ...
            evaluator.jacobian(x+result.alpha*direction), direction));
        return
    end
end

result.alpha = alpha;
result.status = 'max_trials';
result.legacy_exit = 'smax_fallthrough';
result.phi_trial = max(legacy_directional_products( ...
    evaluator.jacobian(x+alpha*direction), direction));
end

function [alpha, fCount, jCount, exitName] = derivative_search( ...
    evaluator, x, direction, alphaMax, objective, phi0, sigmaBar, rhoBar)
alpha0 = 0;
alpha1 = alphaMax/2;
alpha = alpha1;
fCount = 0;
jCount = 0;
exitName = 'dwolfe_max';
F0 = evaluator.value(x);

for iteration = 1:39
    F1 = evaluator.value(x+alpha1*direction);
    Falpha0 = evaluator.value(x+alpha0*direction);
    if F1(objective) > F0(objective)+alpha1*rhoBar*phi0 || ...
            (F1(objective) >= Falpha0(objective) && iteration > 1)
        fCount = fCount+2;
        [alpha, zF, zJ, exitName] = zoom_search( ...
            evaluator, x, direction, alpha0, alpha1, objective, ...
            phi0, sigmaBar, rhoBar, 'lower');
        fCount = fCount+zF;
        jCount = jCount+zJ;
        return
    end
    gradient = evaluator.jacobian(x+alpha1*direction);
    directional = gradient(objective,:)*direction;
    if abs(directional) <= -sigmaBar*phi0
        jCount = jCount+1;
        alpha = alpha1;
        exitName = 'dwolfe_curvature';
        return
    end
    if directional >= 0
        jCount = jCount+1;
        [alpha, zF, zJ, exitName] = zoom_search( ...
            evaluator, x, direction, alpha1, alpha0, objective, ...
            phi0, sigmaBar, rhoBar, 'upper');
        fCount = fCount+zF;
        jCount = jCount+zJ;
        return
    end
    alpha1 = (alpha1+alphaMax)/2;
    alpha = alpha1;
end
end

function [alpha, fCount, jCount, exitName] = zoom_search( ...
    evaluator, x, direction, first, second, objective, phi0, ...
    sigmaBar, rhoBar, orientation)
fCount = 0;
jCount = 0;
exitName = 'zoom_max';

if strcmp(orientation, 'lower')
    alpha0 = first;
    alpha1 = second;
    if evaluator.problem.m == 2
        base = direction;   % Reproduces swapped xk/dk arguments in zoom11/zoom21.
        searchDirection = x;
        Jbase = evaluator.jacobian(base);
        phiBase = max(legacy_directional_products(Jbase, searchDirection));
    else
        base = x;
        searchDirection = direction;
        phiBase = phi0;
    end
    Fbase = evaluator.value(base);
    for iteration = 1:20
        alphaMid = (alpha0+alpha1)/2;
        Fmid = evaluator.value(base+alphaMid*searchDirection);
        Fleft = evaluator.value(base+alpha0*searchDirection);
        if Fmid(objective) > Fbase(objective)+alphaMid*rhoBar*phiBase || ...
                Fmid(objective) >= Fleft(objective)
            fCount = fCount+2;
            alpha1 = alphaMid;
        else
            Jmid = evaluator.jacobian(base+alphaMid*searchDirection);
            derivative = Jmid(objective,:)*searchDirection;
            if abs(derivative) <= sigmaBar*abs(phiBase)
                jCount = jCount+1;
                alpha = alphaMid;
                exitName = 'zoom_curvature';
                return
            end
            if derivative*(alpha1-alpha0) >= 0
                jCount = jCount+1;
                alpha1 = alpha0;
            end
            alpha0 = alphaMid;
        end
        alpha = alphaMid;
    end
else
    alpha1 = first;
    alpha0 = second;
    base = x;
    searchDirection = direction;
    Fbase = evaluator.value(base);
    for iteration = 1:20
        alphaMid = (alpha0+alpha1)/2;
        Fmid = evaluator.value(base+alphaMid*searchDirection);
        Fright = evaluator.value(base+alpha1*searchDirection);
        if Fmid(objective) > Fbase(objective)+alphaMid*rhoBar*phi0 || ...
                Fmid(objective) >= Fright(objective)
            fCount = fCount+2;
            alpha0 = alphaMid;
        else
            Jmid = evaluator.jacobian(base+alphaMid*searchDirection);
            derivative = Jmid(objective,:)*searchDirection;
            if abs(derivative) <= sigmaBar*abs(phi0)
                jCount = jCount+1;
                alpha = alphaMid;
                exitName = 'zoom_curvature';
                return
            end
            if derivative*(alpha0-alpha1) >= 0
                jCount = jCount+1;
                alpha0 = alpha1;
            end
            if evaluator.problem.m ~= 2 || objective ~= 1
                alpha1 = alphaMid;
            end
        end
        alpha = alphaMid;
    end
end
end

function result = base_result()
result = struct('alpha', NaN, 'status', 'failed', 'validated', false, ...
    'legacy_exit', '', 'trials', 0, 'sites', 0, 'phi0', NaN, ...
    'phi_trial', NaN, 'legacy_F', 0, 'legacy_J', 0);
end
