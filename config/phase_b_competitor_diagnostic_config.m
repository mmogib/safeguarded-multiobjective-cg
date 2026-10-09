function cfg = phase_b_competitor_diagnostic_config(mcodeRoot, outputFile)
%PHASE_B_COMPETITOR_DIAGNOSTIC_CONFIG Calibration-only PRP+/AVHZ+ diagnostic.

methods = {'PRP+','AVHZ+'};
jobs = repmat(struct('method','','mode','paper_r2','eta',NaN), ...
    1, numel(methods));
for methodIndex = 1:numel(methods)
    jobs(methodIndex).method = methods{methodIndex};
end

cfg = struct('mcode_root',mcodeRoot,'output_file',outputFile, ...
    'jobs',jobs, ...
    'problem_indices',[1 5 6 7 22 17 18 19 23 26 31 32 33 35 40], ...
    'trials',1:100,'parallel_workers',8);
end
