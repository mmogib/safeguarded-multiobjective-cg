function phaseB = run_phase_b_calibration(mcodeRoot)
%RUN_PHASE_B_CALIBRATION Run the paper-r2 calibration authorized in exchange 010.

resultDir = fullfile(mcodeRoot, 'data', 'results', 'phaseB');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
outputFile = fullfile(resultDir, 'calibration_paper_r2_campaign.mat');
cfg = phase_b_calibration_config(mcodeRoot, outputFile);
[startSummary,startCoordinates] = archived_start_ranges(mcodeRoot);
writetable(startSummary,fullfile(resultDir,'archived_start_ranges_summary.csv'));
writetable(startCoordinates,fullfile(resultDir,'archived_start_ranges_by_coordinate.csv'));
campaign = run_campaign(cfg);
expectedRows = numel(cfg.jobs)*numel(cfg.problem_indices)*numel(cfg.trials);
if height(campaign.rows) ~= expectedRows
    error('mcode:IncompleteCalibration', ...
        'Expected %d calibration rows, found %d.', expectedRows, height(campaign.rows));
end
candidates = unique([cfg.jobs.eta], 'stable');
selectionCandidates = candidates(candidates > 0);
summary = summarize_calibration(campaign.rows,candidates,selectionCandidates);
summary.control_comparison = compare_calibration_control( ...
    campaign.rows,0,summary.selected_eta);
phaseB = struct('manifest',campaign.manifest,'summary',summary, ...
    'corrected_jacobians',all(campaign.rows.derivative_mode == "corrected"), ...
    'start_ranges_summary',startSummary, ...
    'start_ranges_by_coordinate',startCoordinates);
save(fullfile(resultDir,'calibration_paper_r2_report.mat'),'phaseB','-v7.3');
export_calibration_tables(phaseB,resultDir);
end
