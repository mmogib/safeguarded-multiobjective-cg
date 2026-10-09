function tests = test_nonlipschitz_screen
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'), ...
    fullfile(root,'config'),fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testTinyAuthorizedScreenProducesAllRows(testCase)
outputDir = tempname;
cfg = nonlipschitz_screen_config(testCase.TestData.root,outputDir);
cfg.problem_indices = [1 6];
cfg.trials = 1;
cfg.parallel_workers = 1;
cfg.max_iter = 2;

output = run_nonlipschitz_screen(cfg);
resumed = run_nonlipschitz_screen(cfg);

verifyEqual(testCase,numel(output.rows),6);
verifyEqual(testCase,numel(resumed.rows),6);
verifyEqual(testCase,height(output.summary.summary),6);
verifyTrue(testCase,isfile(fullfile(outputDir,'e1_summary.csv')));
verifyTrue(testCase,isfile(fullfile(outputDir,'e1_run_rows.csv')));
verifyTrue(testCase,isfile(fullfile(outputDir,'e1_paired_by_start.csv')));
verifyTrue(testCase,isfile(fullfile(outputDir,'accessibility_gate_rows.csv')));
summaryNames = output.summary.summary.Properties.VariableNames;
verifyTrue(testCase,all(ismember({'d_min_log10_q25','d_min_log10_median', ...
    'd_min_log10_q75','chi_max_min','chi_max_q25','chi_max_q75', ...
    'chi_max_log10_q25','chi_max_log10_median','chi_max_log10_q75', ...
    'd_contraction_q25','d_contraction_q75'},summaryNames)));
verifyEqual(testCase,numel(output.line_trial_files),6);
checkpointVariables = {whos('-file',cfg.checkpoint_file).name};
verifyFalse(testCase,ismember('lineTrials',checkpointVariables));
block = load(output.line_trial_files{1},'lineTrials','blockMetadata');
verifyTrue(testCase,istable(block.lineTrials));
verifyEqual(testCase,block.blockMetadata.method,'TTCGP');
verifyEqual(testCase,block.blockMetadata.problem,'E2-1');
end

function testUnauthorizedArmIsRejected(testCase)
outputDir = tempname;
cfg = nonlipschitz_screen_config(testCase.TestData.root,outputDir);
cfg.methods = {'TTCGP','TTCGH','TTCGL','SD'};
verifyError(testCase,@() run_nonlipschitz_screen(cfg), ...
    'mcode:UnauthorizedNonLipschitzArm');
end
