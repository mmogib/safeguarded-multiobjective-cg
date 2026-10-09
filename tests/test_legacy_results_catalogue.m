function tests = test_legacy_results_catalogue
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testCatalogueHashesAndClassifiesLegacyArtifacts(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root,'s'));
campaign = fullfile(root,'campaignA');
mkdir(campaign);
rows = table("run-1",1,'VariableNames',{'run_key','iterations'});
manifest = struct('schema_version',5);
save(fullfile(campaign,'run_campaign.mat'),'rows','manifest','-v7.3');
manifestSaved = struct('study_version',1);
save(fullfile(campaign,'eta_checkpoint.mat'),'rows','manifestSaved','-v7.3');
lineTrials = table(1,0.5,'VariableNames',{'trial','alpha'});
blockMetadata = struct('storage_version',1);
save(fullfile(campaign,'line_trials.mat'), ...
    'lineTrials','blockMetadata','-v7.3');
writetable(rows,fullfile(campaign,'summary.csv'));
output = fullfile(root,'legacy_results_catalogue.csv');

catalogue = campaignstore.build_legacy_catalogue(root,output);

verifyTrue(testCase,isfile(output));
verifyEqual(testCase,height(catalogue),4);
verifyEqual(testCase,catalogue.relative_path,sort(catalogue.relative_path));
verifyFalse(testCase,any(contains(catalogue.relative_path, ...
    'legacy_results_catalogue.csv')));
verifyEqual(testCase,unique(catalogue.campaign),"campaignA");
verifyTrue(testCase,all(catalogue.file_bytes>0));
verifyTrue(testCase,all(strlength(catalogue.sha256)==64));
verifyEqual(testCase,catalogue.schema_type(endsWith( ...
    catalogue.relative_path,'run_campaign.mat')),"run_campaign_v5");
verifyEqual(testCase,catalogue.schema_type(endsWith( ...
    catalogue.relative_path,'eta_checkpoint.mat')),"eta_study_checkpoint");
verifyEqual(testCase,catalogue.schema_type(endsWith( ...
    catalogue.relative_path,'line_trials.mat')),"line_trial_block");
verifyEqual(testCase,catalogue.schema_type(endsWith( ...
    catalogue.relative_path,'summary.csv')),"derived_csv");
verifyTrue(testCase,all(strlength(catalogue.reader)>0));

reloaded = readtable(output,'TextType','string');
verifyEqual(testCase,reloaded,catalogue);
end
