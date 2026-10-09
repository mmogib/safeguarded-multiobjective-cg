function manifest = full_campaign_manifest(cfg,chunkSize,catalog)
%FULL_CAMPAIGN_MANIFEST Shared immutable-store manifest for exchange 041.

if nargin < 3
    catalog = full_campaign_catalog(cfg.mcode_root);
end
if isfield(cfg,'problem_labels') && ~isempty(cfg.problem_labels)
    use = ismember(string({catalog.problem}),string(cfg.problem_labels));
    catalog = catalog(use);
end
hashCfg = cfg;
hashCfg.output_dir = '';
hashCfg.preflight_dir = '';
hashCfg.report_dir = '';
manifest = struct('schema_version',cfg.schema_version, ...
    'campaign_id',cfg.campaign_id, ...
    'configuration_hash',campaign_hash(hashCfg), ...
    'chunk_size',chunkSize, ...
    'retention_profile','baseline_v1', ...
    'retention_contract',full_campaign_retention_contract(), ...
    'expected_run_keys',full_campaign_run_keys(catalog,cfg.methods,cfg.trials));
end

