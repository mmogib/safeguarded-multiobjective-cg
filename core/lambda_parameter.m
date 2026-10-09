function [lambda, info] = lambda_parameter(q, mode)
%LAMBDA_PARAMETER Compute lambda using explicitly point-labelled quantities.

arguments
    q (1,1) struct
    mode (1,:) char {mustBeMember(mode, ...
        {'paper','paper_r2','legacy_driver','legacy_etasen'})}
end

switch mode
    case 'paper'
        % Deprecated: retained verbatim as evidence for the superseded formula.
        denominator = q.f_xnext_vprev;
        denominatorName = 'f_xnext_vprev';
        zeroTolerance = eps*max([1, abs(q.f_xnext_dprev), abs(denominator)]);
        isZero = ~isfinite(denominator) || abs(denominator) <= zeroTolerance;
    case 'paper_r2'
        denominator = -q.f_xnext_v;
        denominatorName = '-f_xnext_v';
        zeroTolerance = eps*max([1, abs(q.f_xnext_dprev), abs(denominator)]);
        isZero = ~isfinite(denominator) || denominator <= zeroTolerance;
    case 'legacy_driver'
        denominator = q.f_x0_v0;
        denominatorName = 'f_x0_v0';
        zeroTolerance = 0;
        isZero = denominator == 0;
    case 'legacy_etasen'
        denominator = q.f_x_v;
        denominatorName = 'f_x_v';
        zeroTolerance = 0;
        isZero = denominator == 0;
end

if isZero
    lambda = 0;
elseif strcmp(mode, 'paper_r2')
    lambda = max(q.f_xnext_dprev, 0)/denominator;
else
    lambda = max(0, -q.f_xnext_dprev/denominator);
end
if ~isfinite(lambda)
    lambda = 0;
    isZero = true;
end
info = struct('denominator', denominator, ...
    'denominator_name', denominatorName, ...
    'zero_tolerance', zeroTolerance, 'used_fallback', isZero);
end
