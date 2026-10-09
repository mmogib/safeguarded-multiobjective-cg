function [runs,iterations,extras,result] = build_full_campaign_payload( ...
    entry,method,startId,cfg)
%BUILD_FULL_CAMPAIGN_PAYLOAD Execute one run and retain the shared schema.

starts = entry.starts();
x0 = starts(:,startId);
opts = experiment(method,cfg.mode);
if startsWith(method,'TTCG')
    opts.eta_bar = cfg.eta_bar;
end
opts.max_iter = cfg.max_iter;
opts.trace_enabled = true;
opts.trace_points_enabled = entry.tier >= 2;
started = tic;
result = solve_mocg(entry.prob,x0,opts);
wallTime = toc(started);
key = full_campaign_run_key(entry,method,startId);

runs = make_run_table(key,entry,method,startId,x0,result,wallTime,cfg);
iterations = make_iteration_table(key,result.trace.iterations);
extras = empty_extras();
extras.line_trials = make_line_trial_table(key,result.trace.line_trials);
extras.beta_fallback_events = make_beta_fallback_table( ...
    key,opts.beta_formula,result.diagnostics.beta_fallback_details);
if entry.tier == 2
    arguments = nonlipschitz_arguments(entry.prob);
    extras.tier2_accepted_exposure = tier2_accepted_table( ...
        key,arguments,result.trace.accepted_points);
    extras.tier2_line_trial_exposure = tier2_trial_table( ...
        key,arguments,result.trace.line_trials);
elseif entry.tier == 3
    arguments = nonlipschitz_arguments(entry.prob);
    extras.tier3_accepted_exposure = tier3_accepted_table( ...
        key,arguments,result.trace.accepted_points);
    extras.tier3_line_trial_exposure = tier3_trial_table( ...
        key,arguments,result.trace.line_trials);
end
end

function runs = make_run_table(key,entry,method,startId,x0,result,wallTime,cfg)
counts = result.counts;
diagnostics = result.diagnostics;
runs = table(key,startId,{x0},{result.x},{result.F},string(result.status), ...
    result.iterations,counts.vector_F,counts.vector_J,counts.component_F, ...
    counts.component_J,diagnostics.qp_solves, ...
    diagnostics.line_search_trials,result.theta,result.v_norm, ...
    result.steepest_directional_value,wallTime,counts.evaluation_time, ...
    diagnostics.qp_time,{diagnostics.line_search_failure}, ...
    diagnostics.qp_failures,diagnostics.nonfinite_events, ...
    {diagnostics.no_descent_event},entry.tier,string(entry.set_name), ...
    string(entry.problem),entry.problem_index,string(method),string(cfg.mode), ...
    cfg.eta_bar,entry.theorem_compatible,entry.unbounded_level_set, ...
    entry.natural_domain,string(entry.exposure_stratum),entry.tier3_primary, ...
    'VariableNames',{'run_key','start_id','x0','x_final','F_final','status', ...
    'iterations','vector_F','vector_J','component_F','component_J', ...
    'qp_solves','line_search_trials','theta','v_norm', ...
    'steepest_directional_value','wall_time','evaluation_time','qp_time', ...
    'line_search_failure','qp_failures','nonfinite_events','no_descent_event', ...
    'tier','set_name','problem','problem_index','method','mode','eta_bar', ...
    'theorem_compatible','unbounded_level_set','natural_domain', ...
    'exposure_stratum','tier3_primary'});
end

function iterations = make_iteration_table(key,records)
if isempty(records)
    iterations = empty_iteration_table();
    return
end
if isscalar(records)
    iterations = struct2table(records,'AsArray',true);
else
    iterations = struct2table(records(:));
end
iterations.run_key = repmat(key,height(iterations),1);
iterations = movevars(iterations,'run_key','Before',1);
end

function value = empty_iteration_table()
names = full_campaign_retention_contract().iterations;
types = repmat({'double'},1,numel(names));
types(ismember(names,{'run_key','line_search_status'})) = {'string'};
types(ismember(names,{'beta_denominator_fallback', ...
    'lambda_denominator_fallback','descent_bound_holds'})) = {'logical'};
value = table('Size',[0 numel(names)],'VariableTypes',types, ...
    'VariableNames',names);
end

function value = make_line_trial_table(key,records)
if isempty(records)
    value = empty_table({'run_key','k','trial','alpha','accepted','q','g','phi'}, ...
        {'string','double','double','double','logical','double','double','double'});
    return
end
n = numel(records);
value = table(repmat(key,n,1),[records.iteration]',[records.trial]', ...
    [records.alpha]',logical([records.accepted]'),[records.q]',[records.g]', ...
    [records.phi]','VariableNames', ...
    {'run_key','k','trial','alpha','accepted','q','g','phi'});
end

function value = make_beta_fallback_table(key,betaFormula,records)
names = {'run_key','k','beta_formula','policy','denominator','numerator', ...
    'zero_tolerance','raw_before_reset','nonfinite_reset'};
types = {'string','double','string','string','double','double','double', ...
    'double','logical'};
if isempty(records)
    value = empty_table(names,types);
    return
end
n = numel(records);
value = table(repmat(key,n,1),[records.iteration]', ...
    repmat(string(betaFormula),n,1),string({records.policy})', ...
    [records.denominator]',[records.numerator]', ...
    [records.zero_tolerance]',[records.raw_before_reset]', ...
    logical([records.nonfinite_reset]'),'VariableNames',names);
end

function extras = empty_extras()
extras = struct( ...
    'line_trials',empty_table( ...
        {'run_key','k','trial','alpha','accepted','q','g','phi'}, ...
        {'string','double','double','double','logical','double','double','double'}), ...
    'beta_fallback_events',empty_table( ...
        {'run_key','k','beta_formula','policy','denominator','numerator', ...
        'zero_tolerance','raw_before_reset','nonfinite_reset'}, ...
        {'string','double','string','string','double','double','double', ...
        'double','logical'}), ...
    'tier2_accepted_exposure',empty_tier2(false), ...
    'tier2_line_trial_exposure',empty_tier2(true), ...
    'tier3_accepted_exposure',empty_tier3(false), ...
    'tier3_line_trial_exposure',empty_tier3(true));
end

function value = tier2_accepted_table(key,arguments,points)
nArgs = numel(arguments);
n = size(points,2)*nArgs;
[runKey,k,argumentId,r,d,distanceKind,status,chi] = ...
    tier2_columns(n,key);
row = 0;
for pointIndex = 1:size(points,2)
    observation = evaluate_singular_exposure(arguments,points(:,pointIndex));
    for j = 1:nArgs
        row = row+1;
        [argumentId(row),r(row),d(row),distanceKind(row),status(row),chi(row)] = ...
            tier2_entry(observation.entries(j));
        k(row) = pointIndex;
    end
end
value = table(runKey,k,argumentId,r,d,distanceKind,status,chi, ...
    'VariableNames',{'run_key','k','argument_id','r','d','distance_kind', ...
    'status','chi'});
end

function value = tier2_trial_table(key,arguments,records)
nArgs = numel(arguments);
n = numel(records)*nArgs;
[runKey,k,argumentId,r,d,distanceKind,status,chi] = ...
    tier2_columns(n,key);
trial = zeros(n,1); alpha = zeros(n,1); accepted = false(n,1);
row = 0;
for q = 1:numel(records)
    observation = evaluate_singular_exposure(arguments,records(q).point);
    for j = 1:nArgs
        row = row+1;
        [argumentId(row),r(row),d(row),distanceKind(row),status(row),chi(row)] = ...
            tier2_entry(observation.entries(j));
        k(row) = records(q).iteration;
        trial(row) = records(q).trial;
        alpha(row) = records(q).alpha;
        accepted(row) = records(q).accepted;
    end
end
value = table(runKey,k,argumentId,r,d,distanceKind,status,chi, ...
    trial,alpha,accepted,'VariableNames',{'run_key','k','argument_id','r', ...
    'd','distance_kind','status','chi','trial','alpha','accepted'});
end

function [runKey,k,argumentId,r,d,distanceKind,status,chi] = tier2_columns(n,key)
runKey = repmat(key,n,1); k = zeros(n,1); argumentId = strings(n,1);
r = zeros(n,1); d = zeros(n,1); distanceKind = strings(n,1);
status = strings(n,1); chi = zeros(n,1);
end

function [argumentId,r,d,distanceKind,status,chi] = tier2_entry(entry)
argumentId = string(entry.argument_id); r = entry.r; d = entry.d;
distanceKind = string(entry.distance_kind); status = string(entry.status);
chi = entry.chi;
end

function value = tier3_accepted_table(key,arguments,points)
nArgs = numel(arguments);
n = size(points,2)*nArgs;
[runKey,k,argumentId,r,d,distanceKind,status,actual,envelope] = ...
    tier3_columns(n,key);
row = 0;
for pointIndex = 1:size(points,2)
    observation = evaluate_tier3_exposure(arguments,points(:,pointIndex));
    for j = 1:nArgs
        row = row+1;
        [argumentId(row),r(row),d(row),distanceKind(row),status(row), ...
            actual(row),envelope(row)] = tier3_entry(observation.entries(j));
        k(row) = pointIndex;
    end
end
value = table(runKey,k,argumentId,r,d,distanceKind,status,actual,envelope, ...
    'VariableNames',{'run_key','k','argument_id','r','d','distance_kind', ...
    'status','actual_exposure','inverse_t_envelope'});
end

function value = tier3_trial_table(key,arguments,records)
nArgs = numel(arguments);
n = numel(records)*nArgs;
[runKey,k,argumentId,r,d,distanceKind,status,actual,envelope] = ...
    tier3_columns(n,key);
trial = zeros(n,1); alpha = zeros(n,1); accepted = false(n,1);
row = 0;
for q = 1:numel(records)
    observation = evaluate_tier3_exposure(arguments,records(q).point);
    for j = 1:nArgs
        row = row+1;
        [argumentId(row),r(row),d(row),distanceKind(row),status(row), ...
            actual(row),envelope(row)] = tier3_entry(observation.entries(j));
        k(row) = records(q).iteration;
        trial(row) = records(q).trial;
        alpha(row) = records(q).alpha;
        accepted(row) = records(q).accepted;
    end
end
value = table(runKey,k,argumentId,r,d,distanceKind,status,actual,envelope, ...
    trial,alpha,accepted,'VariableNames',{'run_key','k','argument_id','r', ...
    'd','distance_kind','status','actual_exposure','inverse_t_envelope', ...
    'trial','alpha','accepted'});
end

function [runKey,k,argumentId,r,d,distanceKind,status,actual,envelope] = ...
    tier3_columns(n,key)
runKey = repmat(key,n,1); k = zeros(n,1); argumentId = strings(n,1);
r = zeros(n,1); d = zeros(n,1); distanceKind = strings(n,1);
status = strings(n,1); actual = zeros(n,1); envelope = zeros(n,1);
end

function [argumentId,r,d,distanceKind,status,actual,envelope] = tier3_entry(entry)
argumentId = string(entry.argument_id); r = entry.r; d = entry.d;
distanceKind = string(entry.distance_kind); status = string(entry.status);
actual = entry.actual_exposure; envelope = entry.inverse_t_envelope;
end

function value = empty_tier2(withTrial)
names = {'run_key','k','argument_id','r','d','distance_kind','status','chi'};
types = {'string','double','string','double','double','string','string','double'};
if withTrial
    names = [names,{'trial','alpha','accepted'}];
    types = [types,{'double','double','logical'}];
end
value = empty_table(names,types);
end

function value = empty_tier3(withTrial)
names = {'run_key','k','argument_id','r','d','distance_kind','status', ...
    'actual_exposure','inverse_t_envelope'};
types = {'string','double','string','double','double','string','string', ...
    'double','double'};
if withTrial
    names = [names,{'trial','alpha','accepted'}];
    types = [types,{'double','double','logical'}];
end
value = empty_table(names,types);
end

function value = empty_table(names,types)
value = table('Size',[0 numel(names)],'VariableTypes',types, ...
    'VariableNames',names);
end
