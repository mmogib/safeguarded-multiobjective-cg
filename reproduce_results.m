function report = reproduce_results()
%REPRODUCE_RESULTS Recreate final tables from locally generated result data.

codeRoot = fileparts(mfilename('fullpath'));
addpath(codeRoot,fullfile(codeRoot,'problems'), ...
    fullfile(codeRoot,'core'),fullfile(codeRoot,'config'), ...
    fullfile(codeRoot,'bench'));

reproductionRoot = fullfile(codeRoot,'reproduced_results');
manifestFile = fullfile(reproductionRoot,'reproduction_manifest.mat');
if ~isfile(manifestFile)
    error('reproduction:MissingManifest', ...
        ['No completed experiment data were found. Run ' ...
        'rerun_all_experiments first.']);
end
saved = load(manifestFile,'reproduction');
if ~isfield(saved,'reproduction') || ...
        ~isfield(saved.reproduction,'base_store') || ...
        ~isfield(saved.reproduction,'extension_store')
    error('reproduction:InvalidManifest', ...
        'The local reproduction manifest is incomplete.');
end
baseStore = saved.reproduction.base_store;
extensionStore = saved.reproduction.extension_store;
if ~isfolder(baseStore) || ~isfolder(extensionStore)
    error('reproduction:MissingStore', ...
        ['A generated result store is missing. Resume ' ...
        'rerun_all_experiments first.']);
end

outputDir = fullfile(reproductionRoot,'reports');
report = summarize_seven_arm_047(baseStore,extensionStore,outputDir);
end
