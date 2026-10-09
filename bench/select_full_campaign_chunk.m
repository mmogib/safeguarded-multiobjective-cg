function selection = select_full_campaign_chunk(summary,cfg)
%SELECT_FULL_CAMPAIGN_CHUNK Apply the frozen exchange-041 preflight gate.

required = {'chunk_size','median_mib','max_mib','max_lost_work_minutes'};
if ~all(ismember(required,summary.Properties.VariableNames))
    error('mcode:InvalidPreflightSummary','Preflight summary columns are missing.');
end
sizeOK = summary.median_mib >= cfg.typical_shard_mib(1) & ...
    summary.median_mib <= cfg.typical_shard_mib(2) & ...
    summary.max_mib <= cfg.tail_shard_mib_max;
timeOK = summary.max_lost_work_minutes >= cfg.lost_work_minutes(1) & ...
    summary.max_lost_work_minutes <= cfg.lost_work_minutes(2);
admissible = sizeOK & timeOK;
if any(admissible)
    selected = max(summary.chunk_size(admissible));
    selection = result(true,selected,'admissible');
    return
end

upperSafe = all(summary.max_mib <= cfg.tail_shard_mib_max & ...
    summary.max_lost_work_minutes <= cfg.lost_work_minutes(2));
belowOneLowerBound = all(summary.median_mib < cfg.typical_shard_mib(1)) || ...
    all(summary.max_lost_work_minutes < cfg.lost_work_minutes(1));
if upperSafe && belowOneLowerBound
    selection = result(true,max(summary.chunk_size),'lower_bound_fallback');
else
    selection = result(false,NaN,'no_admissible_candidate');
end
end

function value = result(passed,chunk,status)
value = struct('passed',passed,'selected_chunk',chunk,'status',status);
end

