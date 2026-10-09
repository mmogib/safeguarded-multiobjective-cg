function tests = test_campaign
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
addpath(fullfile(mcodeRoot, 'core'));
addpath(fullfile(mcodeRoot, 'config'));
addpath(fullfile(mcodeRoot, 'bench'));
end

function testCampaignCheckpointsAndResumesWithoutDuplicates(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
cfg = struct();
cfg.mcode_root = mcodeRoot;
cfg.output_file = fullfile(work, 'checkpoint.mat');
cfg.jobs = struct('method', 'TTCGP', 'mode', 'legacy', 'eta', NaN);
cfg.problem_indices = 1;
cfg.trials = [1 2];

first = run_campaign(cfg);
second = run_campaign(cfg);

verifyEqual(testCase, height(first.rows), 2);
verifyEqual(testCase, height(second.rows), 2);
verifyEqual(testCase, first.manifest.hash, second.manifest.hash);
verifyEqual(testCase, sort(second.rows.trial)', [1 2]);
verifyTrue(testCase, isfile(cfg.output_file));
end

function testChangedConfigurationCannotReuseCheckpoint(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(work, 'checkpoint.mat'), ...
    'jobs', struct('method', 'TTCGP', 'mode', 'legacy', 'eta', NaN), ...
    'problem_indices', 1, 'trials', 1);
run_campaign(cfg);
cfg.problem_indices = 2;

verifyError(testCase, @() run_campaign(cfg), 'mcode:CheckpointHashMismatch');
end

function testParallelCampaignSchedulesEachTrialAndPreservesOrder(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
poolCleanup = onCleanup(@() delete(gcp('nocreate'))); %#ok<NASGU>
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(work, 'parallel_checkpoint.mat'), ...
    'jobs', struct('method', 'TTCGP', 'mode', 'legacy', 'eta', NaN), ...
    'problem_indices', 1, 'trials', [3 1 2], 'parallel_workers', 2);

campaign = run_campaign(cfg);

verifyEqual(testCase, height(campaign.rows), 3);
verifyEqual(testCase, campaign.rows.trial', [3 1 2]);
verifyEqual(testCase, numel(unique(campaign.rows.trial)), 3);
end

function testArchivedComparatorChecksPerTrialCountsAndObjectives(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(mcodeRoot);
archiveRoot = fullfile(projectRoot,'yahya_code','Objective_functions-2');
assumeTrue(testCase,isfolder(archiveRoot), ...
    'The optional unpublished legacy archive is unavailable.');
work = tempname;
mkdir(work);
cleanup = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(work, 'checkpoint.mat'), ...
    'jobs', struct('method', 'TTCGP', 'mode', 'legacy', 'eta', NaN), ...
    'problem_indices', 1, 'trials', [1 2]);
campaign = run_campaign(cfg);

report = compare_archived_artifacts(campaign.rows, ...
    archiveRoot);

verifyEqual(testCase, report.total, 2);
verifyEqual(testCase, report.mismatches, 0);
verifyEmpty(testCase, report.details);
end

function testCampaignHashIgnoresDisposableWorktree(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
cfg = struct('mcode_root', mcodeRoot, ...
    'jobs', struct('method', 'TTCGP', 'mode', 'legacy', 'eta', NaN), ...
    'problem_indices', 1, 'trials', 1);
before = campaign_hash(cfg);
probe = fullfile(mcodeRoot, '.work', 'ignored_hash_probe.m');
folder = fileparts(probe);
if ~isfolder(folder)
    mkdir(folder);
end
fid = fopen(probe, 'w');
fprintf(fid, 'disp(''ignored'');\n');
fclose(fid);
cleanup = onCleanup(@() delete(probe)); %#ok<NASGU>

after = campaign_hash(cfg);

verifyEqual(testCase, after, before);
end
