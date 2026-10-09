function stage0 = run_phase_b_stage0(mcodeRoot)
%RUN_PHASE_B_STAGE0 Run and summarize only exchange 010 Stage 0.

resultDir = fullfile(mcodeRoot,'data','results','phaseB');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
outputFile = fullfile(resultDir,'stage0_revised_direction.mat');
cfg = phase_b_stage0_config(mcodeRoot,outputFile);
campaign = run_campaign(cfg);
expectedRows = numel(cfg.jobs)*numel(cfg.problem_indices)*numel(cfg.trials);
if height(campaign.rows) ~= expectedRows
    error('mcode:IncompleteStage0', ...
        'Expected %d Stage 0 rows, found %d.',expectedRows,height(campaign.rows));
end
summary = summarize_stage0(campaign.rows);
stage0 = struct('manifest',campaign.manifest,'summary',summary, ...
    'corrected_jacobians',all(campaign.rows.derivative_mode == "corrected"), ...
    'rows',height(campaign.rows));
save(fullfile(resultDir,'stage0_revised_direction_report.mat'),'stage0','-v7.3');
end
