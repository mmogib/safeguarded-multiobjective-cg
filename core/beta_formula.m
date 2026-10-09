function [rawBeta, info] = beta_formula(name, q, direction, mode, mu)
%BETA_FORMULA Compute an unsafeguarded CG parameter.

arguments
    name (1,:) char {mustBeMember(name, {'PRP','HS','LS','AVHZ'})}
    q (1,1) struct
    direction (1,:) char {mustBeMember(direction, {'twoterm','threeterm','lindu'})}
    mode (1,:) char {mustBeMember(mode, {'legacy','corrected'})}
    mu (1,1) double = 1
end

switch name
    case 'PRP'
        denominator = -q.f_x_v;
    case 'HS'
        denominator = q.f_xnext_d - q.f_x_d;
    case 'LS'
        denominator = -q.f_x_d;
    case 'AVHZ'
        denominator = q.f_xnext_d - q.f_x_d;
end

scale = max([1, abs(q.p), abs(q.f_x_v), abs(q.f_xnext_d), ...
    abs(q.f_x_d), abs(q.gamma)]);
if strcmp(mode, 'legacy')
    if strcmp(direction, 'threeterm')
        zeroTolerance = eps;
        isZero = abs(denominator) <= zeroTolerance;
    else
        zeroTolerance = 0;
        isZero = denominator == 0;
    end
else
    zeroTolerance = eps * scale;
    isZero = ~isfinite(denominator) || abs(denominator) <= zeroTolerance;
end

fallbackPolicy = 'none';
if isZero
    if strcmp(mode, 'corrected') && strcmp(name, 'HS')
        % A vanishing HS denominator makes beta undefined.  Setting beta=0
        % reduces this update to the steepest direction and preserves descent.
        fallbackPolicy = 'hs_scale_aware_zero_to_steepest';
    elseif strcmp(mode, 'corrected')
        fallbackPolicy = 'scale_aware_zero_to_zero';
    else
        fallbackPolicy = 'legacy_zero_to_zero';
    end
end
info = struct('denominator', denominator, ...
    'zero_tolerance', zeroTolerance, 'used_fallback', isZero, ...
    'fallback_policy', fallbackPolicy, 'raw_before_reset', NaN, ...
    'nonfinite_reset', false);
if isZero
    rawBeta = 0;
elseif strcmp(name, 'AVHZ')
    if strcmp(mode, 'legacy')
        rawBeta = (1/denominator)* ...
            (q.p - (mu*q.f_xnext_d*q.gamma)/denominator);
    else
        rawBeta = (q.p - mu*q.f_xnext_d*q.gamma/denominator)/denominator;
    end
else
    rawBeta = q.p/denominator;
end

info.raw_before_reset = rawBeta;
if ~isfinite(rawBeta)
    rawBeta = 0;
    info.used_fallback = true;
    info.nonfinite_reset = true;
    if strcmp(mode, 'corrected') && strcmp(name, 'HS')
        info.fallback_policy = 'hs_nonfinite_to_steepest';
    else
        info.fallback_policy = 'nonfinite_to_zero';
    end
end
end
