function output = reproduce_figures()
%REPRODUCE_FIGURES Recreate the performance-profile figures.

codeRoot = fileparts(mfilename('fullpath'));
addpath(codeRoot,fullfile(codeRoot,'problems'), ...
    fullfile(codeRoot,'core'),fullfile(codeRoot,'config'), ...
    fullfile(codeRoot,'bench'));

resultsRoot = fullfile(codeRoot,'reproduced_results');
reportFile = fullfile(resultsRoot,'reports','results_report.mat');
if ~isfile(reportFile)
    error('reproduction:MissingReport', ...
        'Run reproduce_results before reproduce_figures.');
end

figureDir = fullfile(resultsRoot,'figures');
pairReportDir = fullfile(resultsRoot,'pair_profiles');
recipe = export_profile_figures_049(reportFile,figureDir);
profileReport = generate_profile_figures_050( ...
    reportFile,pairReportDir,figureDir);
output = struct('figure_dir',figureDir, ...
    'pair_report_dir',pairReportDir,'recipe',recipe, ...
    'profile_report',profileReport);
end
