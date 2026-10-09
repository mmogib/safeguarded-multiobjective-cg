function tests = test_full_campaign_runner
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
testCase.TestData.root = root;
end

function testRunnerResumesSelectedPreflightStoreAndSealsExactly(testCase)
output = tempname;
cleanup = onCleanup(@() remove_if_present(output)); %#ok<NASGU>
cfg = full_campaign_config(testCase.TestData.root,output);
cfg.methods = {'MOSD'};
cfg.trials = 1:2;
cfg.problem_labels = ["NC10-1" "NC10-2"];
cfg.preflight_problem_labels = "NC10-1";
cfg.chunk_candidates = [1 2];
cfg.parallel_workers = 1;
cfg.max_iter = 2;
cfg.typical_shard_mib = [0 Inf];
cfg.tail_shard_mib_max = Inf;
cfg.lost_work_minutes = [0 Inf];
preflight = run_full_campaign_preflight(cfg);
store = preflight.selection.store_root;
verifyEqual(testCase,numel(campaignstore.missing_keys(store)),2);

first = run_full_campaign(cfg,store);
second = run_full_campaign(cfg,store);

verifyEqual(testCase,first.seal.runs,4);
verifyEqual(testCase,first.seal.blocks,2);
verifyEqual(testCase,second.seal,first.seal);
verifyEmpty(testCase,campaignstore.missing_keys(store));
inventory = campaignstore.inspect(store,true);
verifyEqual(testCase,numel(unique(inventory.run_keys)),4);
verifyTrue(testCase,isfile(fullfile(store,'archive_manifest.csv')));
reportDir = fullfile(output,'reports');
report = summarize_full_campaign(store,reportDir);
verifyNotEmpty(testCase,report.tables.outcomes);
verifyTrue(testCase,isfile(fullfile(reportDir,'full_campaign_report.mat')));
verifyTrue(testCase,isfile(fullfile(reportDir,'profile_curves.csv')));
verifyTrue(testCase,isfile(fullfile(reportDir, ...
    'front_coverage_matrices.csv')));
verifyTrue(testCase,isfile(fullfile(reportDir, ...
    'front_quality_definitions.txt')));
verifyTrue(testCase,isfield(report,'front_quality'));
end

function testRunnerRejectsPartialFrozenChunk(testCase)
output = tempname;
cleanup = onCleanup(@() remove_if_present(output)); %#ok<NASGU>
cfg = full_campaign_config(testCase.TestData.root,output);
cfg.methods = {'MOSD'};
cfg.trials = 1:2;
cfg.problem_labels = "NC10-1";
cfg.chunk_candidates = [1 2];
cfg.parallel_workers = 1;
cfg.max_iter = 2;
catalog = full_campaign_catalog(testCase.TestData.root);
catalog = catalog(strcmp({catalog.problem},'NC10-1'));
store = fullfile(output,'partial_store');
campaignstore.initialize(store,full_campaign_manifest(cfg,2,catalog));
[runs,iterations,extras] = build_full_campaign_payload( ...
    catalog,'MOSD',1,cfg);
campaignstore.write_block(store,'manual_partial',runs,iterations,extras);

verifyError(testCase,@() run_full_campaign(cfg,store), ...
    'mcode:PartialFrozenChunk');
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
