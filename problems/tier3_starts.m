function [starts,metadata] = tier3_starts(prob)
%TIER3_STARTS Deterministic NC10 starts paired with the inherited family.

if ~strcmp(prob.set_name,'NC10')
    error('mcode:InvalidTier3Problem','Tier-3 starts require an NC10 problem.');
end
oldState = rng;
cleanup = onCleanup(@() rng(oldState));
rng(prob.start_seed,'twister');
starts = prob.lower_bound+(prob.upper_bound-prob.lower_bound).*rand(prob.n,100);
metadata = struct('seed',prob.start_seed);
end
