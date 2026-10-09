function output = rerun_all_experiments(parallelWorkers)
%RERUN_ALL_EXPERIMENTS Recompute both campaigns and rebuild the reports.

if nargin < 1, parallelWorkers = 8; end
validateattributes(parallelWorkers,{'numeric'}, ...
    {'scalar','integer','positive'});

codeRoot = fileparts(mfilename('fullpath'));
addpath(codeRoot,fullfile(codeRoot,'problems'), ...
    fullfile(codeRoot,'core'),fullfile(codeRoot,'config'), ...
    fullfile(codeRoot,'bench'));
resultsRoot = fullfile(codeRoot,'data','results');

baseFolder = fullfile(resultsRoot,'reproduction_base');
cfg = full_campaign_config(codeRoot,baseFolder);
cfg.parallel_workers = parallelWorkers;
preflight = run_full_campaign_preflight(cfg);
if ~preflight.selection.passed
    error('reproduction:PreflightFailed', ...
        'The preliminary storage check did not pass.');
end
baseStore = preflight.selection.store_root;
run_full_campaign(cfg,baseStore);

expectedPrefix = [resultsRoot filesep];
if ~startsWith(baseStore,expectedPrefix)
    error('reproduction:UnexpectedStore', ...
        'The new campaign store is outside the expected results folder.');
end
baseStoreRelative = baseStore(numel(expectedPrefix)+1:end);

extensionFolder = fullfile(resultsRoot,'reproduction_hs_ls');
extensionCfg = extension_046_config(codeRoot,extensionFolder);
extensionCfg.parallel_workers = parallelWorkers;
extensionCfg.reference_store_root = baseStoreRelative;
extension = run_extension_046(extensionCfg);

reproductionRoot = fullfile(codeRoot,'reproduced_results');
if ~isfolder(reproductionRoot), mkdir(reproductionRoot); end
reproduction = struct('base_store',baseStore, ...
    'extension_store',extension.store_root);
save(fullfile(reproductionRoot,'reproduction_manifest.mat'), ...
    'reproduction');
report = reproduce_results();
reportDir = fullfile(reproductionRoot,'reports');
output = struct('base_store',baseStore, ...
    'extension_store',extension.store_root, ...
    'report_dir',reportDir,'report',report);
end
