function output = run_extension_046(cfg)
%RUN_EXTENSION_046 Verify pairing, run HS+/LS+, seal, and report exchange 046.

if nargin < 1
    cfg = extension_046_config();
end
catalog = full_campaign_catalog(cfg.mcode_root);
referenceRoot = fullfile(cfg.mcode_root,'data','results', ...
    cfg.reference_store_root);
if ~isfile(fullfile(referenceRoot,'archive_manifest.csv'))
    error('mcode:MissingExtension046Reference', ...
        'The sealed exchange-041 reference store is unavailable.');
end

referenceBefore = reference_snapshot(referenceRoot);
referenceRuns = campaignstore.load_table(referenceRoot,'runs');
pairing = verify_extension_046_pairing(referenceRuns,catalog,cfg.trials);

storeRoot = fullfile(cfg.output_dir,'store');
campaignstore.initialize(storeRoot, ...
    full_campaign_manifest(cfg,cfg.chunk_size,catalog));
campaign = run_full_campaign(cfg,storeRoot);

referenceAfter = reference_snapshot(referenceRoot);
if ~isequaln(referenceBefore,referenceAfter)
    error('mcode:ReferenceCampaignChanged', ...
        'The sealed exchange-041 reference store changed during extension 046.');
end
report = summarize_extension_046(storeRoot,referenceRoot,cfg.report_dir);
if ~isfolder(cfg.report_dir), mkdir(cfg.report_dir); end
writetable(pairing,fullfile(cfg.report_dir,'pairing_verification.csv'));
writetable(referenceAfter, ...
    fullfile(cfg.report_dir,'reference_store_integrity.csv'));
output = struct('campaign',campaign,'pairing',pairing, ...
    'reference_store',referenceAfter,'report',report, ...
    'store_root',storeRoot,'report_dir',cfg.report_dir);
save(fullfile(cfg.report_dir,'extension_046_output.mat'),'output','-v7.3');
end

function snapshot = reference_snapshot(root)
inventory = campaignstore.inspect(root,true);
blocks = height(inventory.blocks);
runs = numel(unique(inventory.run_keys));
archiveManifestSha256 = string(campaignstore.file_sha256( ...
    fullfile(root,'archive_manifest.csv')));
campaignManifestSha256 = string(campaignstore.file_sha256( ...
    fullfile(root,'campaign_manifest.json')));
checkpointIndexSha256 = string(campaignstore.file_sha256( ...
    fullfile(root,'checkpoint_index.csv')));
snapshot = table(blocks,runs,archiveManifestSha256,campaignManifestSha256, ...
    checkpointIndexSha256,'VariableNames',{'blocks','runs', ...
    'archive_manifest_sha256','campaign_manifest_sha256', ...
    'checkpoint_index_sha256'});
end
