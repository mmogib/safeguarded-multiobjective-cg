function tests = test_full_campaign_preflight
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
testCase.TestData.root = root;
end

function testSelectorTakesLargestFullyAdmissibleCandidate(testCase)
summary = fixture_summary([25 50 100],[20 40 70],[60 90 120],[12 22 25]);
cfg = full_campaign_config(testCase.TestData.root,tempname);

selection = select_full_campaign_chunk(summary,cfg);

verifyTrue(testCase,selection.passed);
verifyEqual(testCase,selection.selected_chunk,50);
verifyEqual(testCase,selection.status,'admissible');
end

function testSelectorUsesLargestLowerBoundFallbackOnlyWhenUpperBoundsHold(testCase)
summary = fixture_summary([25 50 100],[1 3 8],[5 9 15],[1 2 4]);
cfg = full_campaign_config(testCase.TestData.root,tempname);

selection = select_full_campaign_chunk(summary,cfg);

verifyTrue(testCase,selection.passed);
verifyEqual(testCase,selection.selected_chunk,100);
verifyEqual(testCase,selection.status,'lower_bound_fallback');

summary.max_mib(3) = 140;
summary.max_lost_work_minutes(2) = 35;
summary.max_lost_work_minutes(3) = 40;
selection = select_full_campaign_chunk(summary,cfg);
verifyFalse(testCase,selection.passed);
verifyTrue(testCase,isnan(selection.selected_chunk));
verifyEqual(testCase,selection.status,'no_admissible_candidate');
end

function testReducedPreflightWritesSameRunsAtTwoChunkSizes(testCase)
output = tempname;
cleanup = onCleanup(@() remove_if_present(output)); %#ok<NASGU>
cfg = full_campaign_config(testCase.TestData.root,output);
cfg.methods = {'MOSD'};
cfg.trials = 1:4;
cfg.parallel_workers = 1;
cfg.max_iter = 2;
cfg.preflight_problem_labels = "NC10-1";
cfg.chunk_candidates = [2 4];
cfg.typical_shard_mib = [0 Inf];
cfg.tail_shard_mib_max = Inf;
cfg.lost_work_minutes = [0 Inf];

lastwarn('');
report = run_full_campaign_preflight(cfg);
[~,warningId] = lastwarn;

verifyTrue(testCase,report.selection.passed);
verifyEmpty(testCase,warningId);
verifyEqual(testCase,report.selection.selected_chunk,4);
verifyEqual(testCase,height(report.summary),2);
for chunk = [2 4]
    root = fullfile(cfg.preflight_dir,"chunk_"+string(chunk));
    inventory = campaignstore.inspect(root,true);
    verifyEqual(testCase,numel(inventory.run_keys),4);
    verifyEqual(testCase,height(inventory.blocks),4/chunk);
    verifyEqual(testCase,numel(campaignstore.missing_keys(root)),260);
end
end

function summary = fixture_summary(chunk,medianMiB,maxMiB,lostMinutes)
summary = table(chunk(:),medianMiB(:),maxMiB(:),lostMinutes(:), ...
    'VariableNames',{'chunk_size','median_mib','max_mib', ...
    'max_lost_work_minutes'});
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
