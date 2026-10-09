function contract = tier3_retention_contract()
%TIER3_RETENTION_CONTRACT Baseline primitives plus separate NC10 diagnostics.

contract = campaignstore.baseline_retention_contract();
common = {'run_key','argument_id','r','d','distance_kind','status', ...
    'actual_exposure','inverse_t_envelope'};
contract.extras.accepted_exposure = [common {'k'}];
contract.extras.line_trial_exposure = [common ...
    {'k','trial','alpha','accepted'}];
end

