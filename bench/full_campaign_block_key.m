function key = full_campaign_block_key(prefix,method,problem,trials)
%FULL_CAMPAIGN_BLOCK_KEY Filesystem-safe deterministic shard key.

safeMethod = regexprep(method,'[^A-Za-z0-9]+','-');
safeProblem = regexprep(problem,'[^A-Za-z0-9]+','-');
key = sprintf('%s_%s_%s_%03d-%03d',prefix,safeMethod,safeProblem, ...
    trials(1),trials(end));
end

