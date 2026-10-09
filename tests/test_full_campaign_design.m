function tests = test_full_campaign_design
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'config'),fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testFrozenConfigurationHasSevenArmsAndCandidateChunks(testCase)
cfg = full_campaign_config(testCase.TestData.root,tempname);

verifyEqual(testCase,string(cfg.methods), ...
    ["TTCGP" "TTCGH" "TTCGL" "MOSD" "PRP+" "AVHZ+" "TT-PRP1"]);
verifyEqual(testCase,cfg.mode,'paper_r2');
verifyEqual(testCase,cfg.eta_bar,1);
verifyEqual(testCase,cfg.trials,1:100);
verifyEqual(testCase,cfg.chunk_candidates,[25 50 100]);
verifyEqual(testCase,cfg.preflight_problem_labels, ...
    ["NC10-1" "NC10-5" "NC10-6" "NC10-7" "NC10-9"]);
end

function testCatalogContainsEveryFrozenPartition(testCase)
catalog = full_campaign_catalog(testCase.TestData.root);

verifyEqual(testCase,numel(catalog),66);
verifyEqual(testCase,sum([catalog.tier]==1),41);
verifyEqual(testCase,sum(strcmp({catalog.set_name},'E2')),5);
verifyEqual(testCase,sum(strcmp({catalog.set_name},'NL10')),10);
verifyEqual(testCase,sum(strcmp({catalog.set_name},'NC10')),10);
verifyEqual(testCase,string({catalog([catalog.tier3_primary]).problem}), ...
    ["NC10-1" "NC10-5" "NC10-6" "NC10-7" "NC10-9"]);

unbounded = string({catalog([catalog.unbounded_level_set]).problem});
verifyEqual(testCase,unbounded, ...
    ["DGO1" "MLF1" "TE4" "Toi4" "Hill" "Lov5"]);
natural = string({catalog([catalog.natural_domain]).problem});
verifyEqual(testCase,natural,["DGO2" "TE6" "TE8-15" "TE8-30" "TE8-50"]);
verifyEqual(testCase,unique(string({catalog(strcmp({catalog.set_name}, ...
    'NL10')).exposure_stratum}),'stable'), ...
    ["smooth_control" "limited" "moderate" "strong"]);
end

function testEveryTierOneProblemHasOneHundredArchivedStarts(testCase)
catalog = full_campaign_catalog(testCase.TestData.root);
for k = find([catalog.tier]==1)
    starts = catalog(k).starts();
    verifySize(testCase,starts,[catalog(k).prob.n 100],catalog(k).problem);
end
end

function testRunKeysAreUniqueAndComplete(testCase)
cfg = full_campaign_config(testCase.TestData.root,tempname);
catalog = full_campaign_catalog(testCase.TestData.root);
keys = full_campaign_run_keys(catalog,cfg.methods,cfg.trials);

verifyEqual(testCase,numel(keys),46200);
verifyEqual(testCase,numel(unique(keys)),46200);
verifyTrue(testCase,all(startsWith(keys,"paper_r2__")));
verifyTrue(testCase,any(contains(keys,"__NC10-9__start100")));
end

function testRetentionContractExtendsBaselineWithSeparatedExtras(testCase)
baseline = campaignstore.baseline_retention_contract();
contract = full_campaign_retention_contract();

verifyTrue(testCase,all(ismember(baseline.runs,contract.runs)));
verifyTrue(testCase,all(ismember(baseline.iterations,contract.iterations)));
verifyTrue(testCase,all(ismember({'directional_value','descent_gap', ...
    'descent_tolerance','descent_bound_holds'},contract.iterations)));
verifyEqual(testCase,sort(string(fieldnames(contract.extras))),sort([ ...
    "line_trials";"tier2_accepted_exposure";"tier2_line_trial_exposure"; ...
    "tier3_accepted_exposure";"tier3_line_trial_exposure"]));
end

