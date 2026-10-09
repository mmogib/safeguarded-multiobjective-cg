function key = full_campaign_run_key(entry,method,startId)
%FULL_CAMPAIGN_RUN_KEY One deterministic exchange-041 run identifier.

key = "paper_r2__"+string(method)+"__"+string(entry.set_name)+"__"+ ...
    string(entry.problem)+"__start"+compose('%03d',startId);
end

