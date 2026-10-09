function report = full_campaign_reporting_tables(runs,iterations,tier2,tier3)
%FULL_CAMPAIGN_REPORTING_TABLES Build non-front exchange-041 summaries.

report = struct();
report.outcomes = outcome_table(runs);
report.per_problem = per_problem_table(runs);
report.paired_work = paired_work_table(runs);
report.cpu_descriptive = cpu_table(runs);
report.failure_classes = failure_table(runs);
report.tier2_exposure = tier2_exposure_table(runs,tier2);
report.tier3_exposure = tier3_exposure_table(runs,tier3);
report.tier3_descent = tier3_descent_table(runs,iterations);
end

function output = outcome_table(runs)
slices = full_campaign_slices(runs);
output = table();
for s = 1:height(slices)
    block = runs(slices.mask{s},:);
    [group,method,status] = findgroups(block.method,block.status);
    count = splitapply(@numel,block.start_id,group);
    converged = count.*double(status=="converged");
    output = [output;table(repmat(slices.name(s),numel(method),1), ...
        method,status,count,converged, ...
        'VariableNames',{'slice','method','status','runs','converged'})]; %#ok<AGROW>
end
end

function output = per_problem_table(runs)
[group,tier,setName,problem,method,stratum] = findgroups( ...
    runs.tier,runs.set_name,runs.problem,runs.method,runs.exposure_stratum);
total = splitapply(@numel,runs.start_id,group);
converged = splitapply(@(s) sum(s=="converged"),runs.status,group);
medianTheta = splitapply(@(x) median(x,'omitnan'),runs.theta,group);
medianVNorm = splitapply(@(x) median(x,'omitnan'),runs.v_norm,group);
medianIterations = splitapply(@success_median,runs.iterations,runs.status,group);
medianF = splitapply(@success_median,runs.component_F,runs.status,group);
medianJ = splitapply(@success_median,runs.component_J,runs.status,group);
medianTrials = splitapply(@success_median,runs.line_search_trials,runs.status,group);
medianQP = splitapply(@success_median,runs.qp_solves,runs.status,group);
output = table(tier,setName,problem,method,stratum,total,converged, ...
    medianTheta,medianVNorm,medianIterations,medianF,medianJ,medianTrials, ...
    medianQP,'VariableNames',{'tier','set_name','problem','method', ...
    'exposure_stratum','runs','converged','median_theta','median_v_norm', ...
    'median_iterations','median_component_F','median_component_J', ...
    'median_line_search_trials','median_qp_solves'});
end

function output = paired_work_table(runs)
metrics = {'iterations','component_F','component_J', ...
    'line_search_trials','qp_solves'};
slices = full_campaign_slices(runs);
output = table();
for s = 1:height(slices)
    block = runs(slices.mask{s},:);
    methods = unique(block.method,'stable');
    for leftIndex = 1:numel(methods)-1
        for rightIndex = leftIndex+1:numel(methods)
            left = sortrows(block(block.method==methods(leftIndex),:), ...
                {'problem','start_id'});
            right = sortrows(block(block.method==methods(rightIndex),:), ...
                {'problem','start_id'});
            if height(left)~=height(right) || any(left.problem~=right.problem) || ...
                    any(left.start_id~=right.start_id)
                error('mcode:UnpairedFullCampaign','Campaign task keys differ.');
            end
            both = left.status=="converged" & right.status=="converged";
            for metricIndex = 1:numel(metrics)
                metric = metrics{metricIndex};
                if any(both)
                    % Shift nonnegative work counts by one.  This keeps
                    % paired ratios defined for starts stationary at k=0.
                    ratio = (double(left.(metric)(both))+1)./ ...
                        (double(right.(metric)(both))+1);
                    geometricMean = exp(mean(log(ratio)));
                else
                    ratio = [];
                    geometricMean = NaN;
                end
                output = [output;table(slices.name(s),methods(leftIndex), ...
                    methods(rightIndex),string(metric),height(left),sum(both), ...
                    sum(left.status=="converged" & right.status~="converged"), ...
                    sum(left.status~="converged" & right.status=="converged"), ...
                    sum(left.status~="converged" & right.status~="converged"), ...
                    geometricMean,sum(ratio<1),sum(ratio==1),sum(ratio>1), ...
                    'VariableNames',{'slice','left_method','right_method', ...
                    'metric','tasks','paired_successes','left_only_success', ...
                    'right_only_success','both_failed', ...
                    'geomean_left_over_right','wins','ties','losses'})]; %#ok<AGROW>
            end
        end
    end
end
end

function output = cpu_table(runs)
[group,method,problem] = findgroups(runs.method,runs.problem);
wall = splitapply(@success_median,runs.wall_time,runs.status,group);
evaluation = splitapply(@success_median,runs.evaluation_time,runs.status,group);
qp = splitapply(@success_median,runs.qp_time,runs.status,group);
output = table(method,problem,wall,evaluation,qp,'VariableNames', ...
    {'method','problem','median_wall_time_descriptive', ...
    'median_evaluation_time_descriptive','median_qp_time_descriptive'});
end

function output = failure_table(runs)
failureClass = runs.status;
if ismember('line_search_failure',runs.Properties.VariableNames)
    for k = 1:height(runs)
        detail = runs.line_search_failure{k};
        if runs.status(k)=="line_search_failed" && isstruct(detail) && ...
                isfield(detail,'status')
            failureClass(k) = "line_search_"+string(detail.status);
        end
    end
end
[group,tier,setName,problem,method,failure] = findgroups( ...
    runs.tier,runs.set_name,runs.problem,runs.method,failureClass);
count = splitapply(@numel,runs.start_id,group);
output = table(tier,setName,problem,method,failure,count, ...
    'VariableNames',{'tier','set_name','problem','method','failure_class','runs'});
end

function output = tier2_exposure_table(runs,exposure)
if isempty(exposure), output = empty_exposure_summary('tier2'); return; end
keys = unique(exposure.run_key,'stable');
rows = table();
for q = 1:numel(keys)
    block = exposure(exposure.run_key==keys(q) & exposure.k>1,:);
    metadata = runs(runs.run_key==keys(q),:);
    rows = [rows;table(keys(q),metadata.method,metadata.problem, ...
        metadata.exposure_stratum,safe_min(block.d),safe_max(block.chi), ...
        'VariableNames',{'run_key','method','problem','exposure_stratum', ...
        'min_d_post0','max_chi_post0'})]; %#ok<AGROW>
end
output = rows;
end

function output = tier3_exposure_table(runs,exposure)
if isempty(exposure), output = empty_exposure_summary('tier3'); return; end
keys = unique(exposure.run_key,'stable');
rows = table();
for q = 1:numel(keys)
    block = exposure(exposure.run_key==keys(q) & exposure.k>1,:);
    metadata = runs(runs.run_key==keys(q),:);
    rows = [rows;table(keys(q),metadata.method,metadata.problem, ...
        metadata.exposure_stratum,safe_min(block.d), ...
        safe_max(block.actual_exposure),safe_max(block.inverse_t_envelope), ...
        'VariableNames',{'run_key','method','problem','exposure_stratum', ...
        'min_d_post0','max_actual_post0','max_inverse_t_envelope_post0'})]; %#ok<AGROW>
end
output = rows;
end

function output = tier3_descent_table(runs,iterations)
metadata = runs(runs.tier==3,{'run_key','method','problem'});
joined = innerjoin(iterations,metadata,'Keys','run_key');
if isempty(joined)
    output = table(); return
end
[group,method,problem] = findgroups(joined.method,joined.problem);
computed = splitapply(@numel,joined.k,group);
violations = splitapply(@(x) sum(~x),joined.descent_bound_holds,group);
maxGap = splitapply(@max,joined.descent_gap,group);
output = table(method,problem,computed,violations,maxGap, ...
    'VariableNames',{'method','problem','computed_directions', ...
    'bound_violations','max_descent_gap'});
end

function value = success_median(values,status)
use = status=="converged";
if any(use), value = median(values(use),'omitnan'); else, value = NaN; end
end

function value = safe_min(values)
values = values(~isnan(values));
if isempty(values), value = NaN; else, value = min(values); end
end

function value = safe_max(values)
values = values(~isnan(values));
if isempty(values), value = NaN; else, value = max(values); end
end

function value = empty_exposure_summary(kind)
if strcmp(kind,'tier2')
    names = {'run_key','method','problem','exposure_stratum', ...
        'min_d_post0','max_chi_post0'};
else
    names = {'run_key','method','problem','exposure_stratum', ...
        'min_d_post0','max_actual_post0','max_inverse_t_envelope_post0'};
end
types = [repmat({'string'},1,4),repmat({'double'},1,numel(names)-4)];
value = table('Size',[0 numel(names)],'VariableTypes',types, ...
    'VariableNames',names);
end
