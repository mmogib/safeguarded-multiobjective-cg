function tests = test_nonlipschitz_comparison
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'), ...
    fullfile(root,'config'),fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testSevenArmSmokeCheckpointsAndResumes(testCase)
outputDir = tempname;
cfg = nonlipschitz_comparison_config(testCase.TestData.root,outputDir);
cfg.problem_indices = [1 6];
cfg.trials = 1;
cfg.parallel_workers = 1;
cfg.max_iter = 2;
assumeTrue(testCase,isfile(cfg.gate_source_file), ...
    'The optional accepted accessibility gate is unavailable.');

first = run_nonlipschitz_comparison(cfg);
second = run_nonlipschitz_comparison(cfg);

verifyEqual(testCase,numel(first.rows),14);
verifyEqual(testCase,numel(second.rows),14);
keys = string({second.rows.method})+"/"+string({second.rows.problem})+ ...
    "/"+string([second.rows.trial]);
verifyEqual(testCase,numel(unique(keys)),14);
verifyEqual(testCase,numel(second.line_trial_files),14);
verifyTrue(testCase,all(isfile(second.line_trial_files)));
verifyTrue(testCase,all(strcmp( ...
    {second.rows(strcmp({second.rows.set_name},'E2')).gate_status}, ...
    'analytically_accessible')));
nl10 = second.rows(strcmp({second.rows.set_name},'NL10'));
verifyTrue(testCase,all(ismember({nl10.gate_status}, ...
    {'certified_accessible','unresolved'})));
required = {'theta','v_norm','steepest_directional_value', ...
    'component_F','component_J','line_search_trials','qp_solves', ...
    'max_direction_norm','max_direction_over_v_norm','x','F', ...
    'd_min_post0','chi_max_post0'};
verifyTrue(testCase,all(isfield(second.rows,required)));
checkpointVariables = {whos('-file',cfg.checkpoint_file).name};
verifyFalse(testCase,ismember('lineTrials',checkpointVariables));
end

function testUnauthorizedArmSetIsRejected(testCase)
cfg = nonlipschitz_comparison_config(testCase.TestData.root,tempname);
cfg.methods{end+1} = 'UNAUTHORIZED';
verifyError(testCase,@() run_nonlipschitz_comparison(cfg), ...
    'mcode:UnauthorizedNonLipschitzComparison');
end

