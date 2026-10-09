function export_calibration_tables(phaseB,resultDir)
%EXPORT_CALIBRATION_TABLES Reproduce the Stage-1 human-readable CSV tables.

writetable(phaseB.summary.scores, ...
    fullfile(resultDir,'calibration_paper_r2_scores.csv'));
writetable(phaseB.summary.diagnostics, ...
    fullfile(resultDir,'calibration_paper_r2_diagnostics.csv'));
writetable(phaseB.summary.control_comparison, ...
    fullfile(resultDir,'calibration_paper_r2_control_comparison.csv'));
end
