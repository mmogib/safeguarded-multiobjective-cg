function cfg = extension_046_config(mcodeRoot,outputDir)
%EXTENSION_046_CONFIG Frozen HS+/LS+ append-only campaign from exchange 046.

if nargin < 1
    mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
end
if nargin < 2
    outputDir = fullfile(mcodeRoot,'data','results', ...
        'full_campaign_046_hs_ls');
end
cfg = full_campaign_config(mcodeRoot,outputDir);
cfg.campaign_id = 'unsafeguarded-hs-ls-046';
cfg.methods = {'HS+','LS+'};
cfg.chunk_size = 100;
cfg.chunk_candidates = 100;
cfg.preflight_problem_labels = strings(1,0);
cfg.reference_store_root = fullfile('full_campaign','preflight','chunk_100');
end
