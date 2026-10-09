function result = validated_strong(evaluator, x, direction, alpha, opts)
%VALIDATED_STRONG Strong-Wolfe search using the proof-based predicate A(t).

recordTrials = isfield(opts,'record_trials') && opts.record_trials;
result = base_result(recordTrials);
F0 = evaluator.value(x);
J0 = evaluator.jacobian(x);
if ~isreal(F0) || ~isreal(J0) || ...
        any(~isfinite(F0)) || any(~isfinite(J0),'all')
    result.status = 'init_failed';
    return
end
gamma = max(J0*direction);
result.phi0 = gamma;
if ~isfinite(gamma) || gamma >= 0
    result.status = 'init_failed';
    return
end

alpha = min(max(alpha,opts.alpha_min),opts.alpha_max);
[point,result] = evaluate_point(evaluator,x,direction,alpha,F0,gamma,opts,result);
if point.accepted
    result = accept(result,point);
    return
end

if point.in_A
    a = point;
    [found,a,b,result] = expand_right( ...
        evaluator,x,direction,a,F0,gamma,opts,result);
    if strcmp(result.status,'ok')
        return
    end
    if ~found
        result.status = 'no_bracket';
        result.bracket = bracket_record(a,a);
        return
    end
else
    b = point;
    [found,a,result] = shrink_left(evaluator,x,direction,b,F0,gamma,opts,result);
    if strcmp(result.status,'ok')
        return
    end
    if ~found
        result.status = 'init_failed';
        result.bracket = bracket_record(a,b);
        return
    end
end

result.bracket = bracket_record(a,b);
while result.trials < opts.max_trials
    if abs(b.alpha-a.alpha) <= opts.alpha_min
        result.status = 'budget_exhausted';
        return
    end
    alphaMid = (a.alpha+b.alpha)/2;
    if alphaMid == a.alpha || alphaMid == b.alpha
        result.status = 'budget_exhausted';
        return
    end
    [mid,result] = evaluate_point(evaluator,x,direction,alphaMid, ...
        F0,gamma,opts,result);
    if mid.accepted
        result.bracket = bracket_record(a,b);
        result = accept(result,mid);
        return
    end
    if mid.in_A
        a = mid;
    else
        b = mid;
    end
    result.bracket = bracket_record(a,b);
end
result.status = 'budget_exhausted';
end

function [found,a,b,result] = expand_right( ...
    evaluator,x,direction,a,F0,gamma,opts,result)
found = false;
b = a;
while result.trials < opts.max_trials
    if a.alpha >= opts.alpha_max
        return
    end
    nextAlpha = min(2*a.alpha,opts.alpha_max);
    if nextAlpha == a.alpha
        return
    end
    [candidate,result] = evaluate_point(evaluator,x,direction,nextAlpha, ...
        F0,gamma,opts,result);
    if candidate.accepted
        result = accept(result,candidate);
        return
    end
    if candidate.in_A
        a = candidate;
    else
        b = candidate;
        found = true;
        return
    end
end
end

function [found,a,result] = shrink_left( ...
    evaluator,x,direction,b,F0,gamma,opts,result)
found = false;
a = b;
currentAlpha = b.alpha;
while result.trials < opts.max_trials
    nextAlpha = max(currentAlpha/2,opts.alpha_min);
    if nextAlpha == currentAlpha
        return
    end
    [candidate,result] = evaluate_point(evaluator,x,direction,nextAlpha, ...
        F0,gamma,opts,result);
    if candidate.accepted
        result = accept(result,candidate);
        return
    end
    a = candidate;
    if candidate.in_A
        found = true;
        return
    end
    currentAlpha = nextAlpha;
end
end

function [point,result] = evaluate_point( ...
    evaluator,x,direction,alpha,F0,gamma,opts,result)
result.trials = result.trials+1;
result.sites = result.sites+1;
point = struct('alpha',alpha,'q',NaN,'g',NaN,'phi',NaN, ...
    'in_A',false,'accepted',false);
Ftrial = evaluator.value(x+alpha*direction);
Jtrial = evaluator.jacobian(x+alpha*direction);
if ~isreal(Ftrial) || ~isreal(Jtrial) || ...
        any(~isfinite(Ftrial)) || any(~isfinite(Jtrial),'all')
    result = record_trial(result,x+alpha*direction,point);
    return
end
phi = max(Jtrial*direction);
q = max(Ftrial-F0-alpha*opts.rho*gamma);
g = phi-opts.sigma*gamma;
point.q = q;
point.g = g;
point.phi = phi;
point.in_A = q < 0 && g < 0;
point.accepted = all(Ftrial <= F0+alpha*opts.rho*gamma) && ...
    abs(phi) <= opts.sigma*abs(gamma);
result = record_trial(result,x+alpha*direction,point);
end

function result = record_trial(result,xTrial,point)
if ~result.record_trials
    return
end
record = struct('trial',result.trials,'point',xTrial,'alpha',point.alpha, ...
    'accepted',point.accepted,'q',point.q,'g',point.g,'phi',point.phi);
result.trial_records(end+1) = record;
end

function result = accept(result,point)
result.alpha = point.alpha;
result.status = 'ok';
result.validated = true;
result.phi_trial = point.phi;
end

function bracket = bracket_record(a,b)
bracket = struct('a',a.alpha,'b',b.alpha,'q_a',a.q,'q_b',b.q, ...
    'g_a',a.g,'g_b',b.g);
end

function result = base_result(recordTrials)
emptyBracket = struct('a',NaN,'b',NaN,'q_a',NaN,'q_b',NaN, ...
    'g_a',NaN,'g_b',NaN);
emptyTrials = struct('trial',{},'point',{},'alpha',{},'accepted',{}, ...
    'q',{},'g',{},'phi',{});
result = struct('alpha',NaN,'status','failed','validated',false, ...
    'legacy_exit','','trials',0,'sites',0,'phi0',NaN, ...
    'phi_trial',NaN,'legacy_F',0,'legacy_J',0,'bracket',emptyBracket, ...
    'record_trials',recordTrials,'trial_records',emptyTrials);
end
