function [directionNext, info] = revised_direction(directionPrevious, vCurrent, lambda, beta)
%REVISED_DIRECTION Construct the paper-r2 direction at the current iterate.
% p_{k-1}=d_{k-1}+lambda_{k-1}v_k and
% d_k=v_k+beta_k*||v_k||*p_hat are both unconditional.

p = directionPrevious+lambda*vCurrent;
pNorm = norm(p);
pHat = p/max(1, pNorm);
pHatNorm = norm(pHat);
vNorm = norm(vCurrent);
alignmentUndefined = pHatNorm == 0 || vNorm == 0;
if alignmentUndefined
    alignment = NaN;
else
    alignment = dot(pHat, vCurrent)/(pHatNorm*vNorm);
end
directionNext = vCurrent+beta*vNorm*pHat;
info = struct('p',p,'p_norm',pNorm,'p_hat',pHat, ...
    'alignment',alignment,'alignment_undefined',alignmentUndefined);
end
