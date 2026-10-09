function [beta, info] = beta_safeguard(rawBeta, policy, etaBar)
%BETA_SAFEGUARD Apply truncation independently of the beta formula.

arguments
    rawBeta (1,1) double
    policy (1,:) char {mustBeMember(policy, {'nonneg','nonneg_capped'})}
    etaBar = []
end

truncated = rawBeta < 0;
beta = max(rawBeta, 0);
clipped = false;
if strcmp(policy, 'nonneg_capped')
    if isempty(etaBar) || ~isscalar(etaBar) || ~isfinite(etaBar) || etaBar < 0
        error('mcode:InvalidEtaBar', ...
            'eta_bar must be a finite nonnegative scalar for nonneg_capped.');
    end
    clipped = beta > etaBar;
    beta = min(beta, etaBar);
elseif ~isempty(etaBar)
    error('mcode:UnexpectedEtaBar', ...
        'eta_bar is accepted only with the nonneg_capped safeguard.');
end
info = struct('raw', rawBeta, 'truncated', truncated, 'clipped', clipped);
end
