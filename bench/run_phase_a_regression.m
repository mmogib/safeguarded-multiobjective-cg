function phaseA = run_phase_a_regression(mcodeRoot, projectRoot)
%RUN_PHASE_A_REGRESSION Execute the 40-problem A2 campaign and comparisons.

resultDir = fullfile(mcodeRoot, 'data', 'results', 'phaseA');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
methodNames = {'TTCGP','TTCGH','TTCGL','PRP+','AVHZ+'};
jobs = repmat(struct('method','','mode','legacy','eta',NaN),1,5);
for k = 1:5
    jobs(k).method = methodNames{k};
end
cfg = struct('mcode_root', mcodeRoot, ...
    'output_file', fullfile(resultDir, 'legacy_port_campaign.mat'), ...
    'jobs', jobs, 'problem_indices', 1:40, 'trials', 1:100, ...
    'parallel_workers', 8);
campaign = run_campaign(cfg);
archiveRoot = fullfile(projectRoot, 'yahya_code', 'Objective_functions-2');
artifact = compare_archived_artifacts(campaign.rows, archiveRoot);
snapshot = prepare_legacy_oracle(mcodeRoot, archiveRoot);
oracle = [];
oracleFiles = {'oracle_TTCGP_output.mat','oracle_TTCGH_output.mat', ...
    'oracle_TTCGL_output.mat','oracle_PRP_output.mat','oracle_AVHZ_output.mat'};
if all(cellfun(@(name) isfile(fullfile(snapshot.path,name)), oracleFiles))
    oracle = compare_same_toolchain_oracle(campaign.rows, snapshot.path);
end
phaseA = struct('manifest',campaign.manifest,'artifact',artifact, ...
    'oracle',oracle,'oracle_snapshot',snapshot, ...
    'blocked_problem',41,'blocker','AP11.mat is absent from the archive.');
save(fullfile(resultDir,'phase_a_regression_report.mat'),'phaseA','-v7.3');
end
