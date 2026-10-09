function output = summarize_full_campaign(storeRoot,outputDir)
%SUMMARIZE_FULL_CAMPAIGN Export exchange-041 reports from a sealed store.

if ~isfile(fullfile(storeRoot,'archive_manifest.csv'))
    error('campaignstore:UnsealedCampaign', ...
        'Full-campaign reporting requires a sealed store.');
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(storeRoot),'reports');
end
if ~isfolder(outputDir), mkdir(outputDir); end
runs = campaignstore.load_table(storeRoot,'runs');
iterations = campaignstore.load_table(storeRoot,'iterations');
tier2 = campaignstore.load_table(storeRoot,'tier2_accepted_exposure');
tier3 = campaignstore.load_table(storeRoot,'tier3_accepted_exposure');
tables = full_campaign_reporting_tables(runs,iterations,tier2,tier3);
profiles = full_campaign_profiles(runs);
fronts = full_campaign_front_metrics(runs);
frontQuality = full_campaign_front_quality(runs);

names = fieldnames(tables);
for k = 1:numel(names)
    writetable(tables.(names{k}),fullfile(outputDir,[names{k} '.csv']));
end
writetable(profiles.ratios,fullfile(outputDir,'profile_ratios.csv'));
writetable(profiles.curves,fullfile(outputDir,'profile_curves.csv'));
writetable(fronts,fullfile(outputDir,'front_metrics.csv'));
write_full_campaign_front_quality(frontQuality,outputDir);
output = struct('tables',tables,'profiles',profiles,'front_metrics',fronts, ...
    'front_quality',frontQuality);
save(fullfile(outputDir,'full_campaign_report.mat'),'output','-v7.3');
end
