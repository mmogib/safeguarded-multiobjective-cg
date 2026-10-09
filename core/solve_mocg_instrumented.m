function result = solve_mocg_instrumented(prob,x0,opts)
%SOLVE_MOCG_INSTRUMENTED Trace a solve, then compute exposure metadata.

opts.trace_enabled = true;
result = solve_mocg(prob,x0,opts);
arguments = nonlipschitz_arguments(prob);
result.exposure = summarize_singular_exposure(arguments, ...
    result.trace.accepted_points,result.trace.line_trials);
end
