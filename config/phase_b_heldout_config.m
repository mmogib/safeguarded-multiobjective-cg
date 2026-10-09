function cfg = phase_b_heldout_config(mcodeRoot, outputFile)
%PHASE_B_HELDOUT_CONFIG Frozen nine-arm held-out campaign from exchange 017.

methods = {'TTCGP','TTCGH','TTCGL'};
etas = [1 0.1];
jobs = repmat(struct('method','','mode','paper_r2','eta',NaN),1,9);
jobIndex = 0;
for eta = etas
    for methodIndex = 1:numel(methods)
        jobIndex = jobIndex+1;
        jobs(jobIndex).method = methods{methodIndex};
        jobs(jobIndex).eta = eta;
    end
end
for method = {'MOSD','PRP+','AVHZ+'}
    jobIndex = jobIndex+1;
    jobs(jobIndex).method = method{1};
end

cfg = struct('mcode_root',mcodeRoot,'output_file',outputFile, ...
    'jobs',jobs, ...
    'problem_indices',[2 3 4 8 9 10 11 12 13 15 16 20 21 24 25 27 28 29 30 34 36 39], ...
    'assca_compatible_indices',[3 4 9 10 11 13 15 16 20 21 27 28 30 34 36 39], ...
    'assca_incompatible_indices',[2 8 12 24 25 29], ...
    'trials',1:100,'parallel_workers',8);
end
