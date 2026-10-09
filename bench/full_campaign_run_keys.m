function keys = full_campaign_run_keys(catalog,methods,trials)
%FULL_CAMPAIGN_RUN_KEYS Deterministic keys ordered by method/problem/start.

keys = strings(numel(methods)*numel(catalog)*numel(trials),1);
row = 0;
for methodIndex = 1:numel(methods)
    for problemIndex = 1:numel(catalog)
        for trial = trials
            row = row+1;
            keys(row) = full_campaign_run_key( ...
                catalog(problemIndex),methods{methodIndex},trial);
        end
    end
end
end
