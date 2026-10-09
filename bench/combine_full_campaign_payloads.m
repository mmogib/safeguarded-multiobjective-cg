function [runs,iterations,extras] = combine_full_campaign_payloads(payloads)
%COMBINE_FULL_CAMPAIGN_PAYLOADS Concatenate one immutable shard payload.

if isempty(payloads)
    error('mcode:EmptyCampaignBlock','A campaign block cannot be empty.');
end
runs = payloads{1}.runs;
iterations = payloads{1}.iterations;
extras = payloads{1}.extras;
for k = 2:numel(payloads)
    payload = payloads{k};
    runs = [runs;payload.runs]; %#ok<AGROW>
    iterations = [iterations;payload.iterations]; %#ok<AGROW>
    names = fieldnames(extras);
    for j = 1:numel(names)
        name = names{j};
        extras.(name) = [extras.(name);payload.extras.(name)];
    end
end
end
