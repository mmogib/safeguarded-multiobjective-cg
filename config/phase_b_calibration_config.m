function cfg = phase_b_calibration_config(mcodeRoot, outputFile)
%PHASE_B_CALIBRATION_CONFIG Amended future calibration from exchange 010.

% eta=0 is the steepest-descent control.  It is reported but is not an
% admissible selected parameter for the paper's positive-eta method.
candidates = [0 0.01 0.05 0.1 0.2 0.3 0.5 0.7 0.9 1 2 5 10];
methods = {'TTCGP','TTCGH','TTCGL'};
jobs = repmat(struct('method','','mode','paper_r2','eta',NaN), ...
    1, numel(candidates)*numel(methods));
jobIndex = 0;
for eta = candidates
    for methodIndex = 1:numel(methods)
        jobIndex = jobIndex+1;
        jobs(jobIndex).method = methods{methodIndex};
        jobs(jobIndex).eta = eta;
    end
end

cfg = struct('mcode_root', mcodeRoot, 'output_file', outputFile, ...
    'jobs', jobs, ...
    'problem_indices', [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40], ...
    'trials', 1:100, 'parallel_workers', 8);
end
