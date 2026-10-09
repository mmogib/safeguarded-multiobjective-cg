function summary = summarize_eta_study(rows,cfg)
%SUMMARIZE_ETA_STUDY Reduce the exchange-035 mechanism/robustness campaign.

ensure_folder(cfg.output_dir);
runs = make_run_table(rows);
mechanismPerRun = make_mechanism_per_run(rows);
mechanismPerProblem = aggregate_mechanism_by_problem(mechanismPerRun);
mechanismAggregate = aggregate_mechanism_across_problems( ...
    mechanismPerProblem,cfg);
outcomes = make_outcomes(runs);
workPerProblem = make_work_per_problem(runs);
[problemRatios,workScores,gate] = reduce_eta_study_work( ...
    workPerProblem,runs,cfg);
cpu = make_cpu_summary(runs);

writetable(runs,fullfile(cfg.output_dir,'eta_study_run_rows.csv'));
writetable(mechanismPerRun, ...
    fullfile(cfg.output_dir,'eta_study_mechanism_per_run.csv'));
writetable(mechanismPerProblem, ...
    fullfile(cfg.output_dir,'eta_study_mechanism_per_problem.csv'));
writetable(mechanismAggregate, ...
    fullfile(cfg.output_dir,'eta_study_mechanism_aggregate.csv'));
writetable(outcomes,fullfile(cfg.output_dir,'eta_study_outcomes.csv'));
writetable(workPerProblem, ...
    fullfile(cfg.output_dir,'eta_study_work_per_problem.csv'));
writetable(problemRatios, ...
    fullfile(cfg.output_dir,'eta_study_problem_ratios.csv'));
writetable(workScores,fullfile(cfg.output_dir,'eta_study_work_scores.csv'));
writetable(cpu,fullfile(cfg.output_dir,'eta_study_cpu_descriptive.csv'));
writetable(gate,fullfile(cfg.output_dir,'eta_study_gate.csv'));

summary = struct('runs',runs,'mechanism_per_run',mechanismPerRun, ...
    'mechanism_per_problem',mechanismPerProblem, ...
    'mechanism_aggregate',mechanismAggregate,'outcomes',outcomes, ...
    'work_per_problem',workPerProblem,'problem_ratios',problemRatios, ...
    'work_scores',workScores,'cpu',cpu,'gate',gate);
end

function runs = make_run_table(rows)
runs = table(string({rows.set_name})',string({rows.problem})', ...
    [rows.problem_index]',logical([rows.natural_domain])', ...
    string({rows.method})',[rows.eta]',[rows.trial]', ...
    string({rows.status})',[rows.iterations]',[rows.theta]', ...
    [rows.v_norm]',[rows.steepest_directional_value]', ...
    [rows.vector_F]',[rows.vector_J]',[rows.qp_solves]', ...
    [rows.line_search_trials]',[rows.wall_time]', ...
    [rows.evaluation_time]',[rows.qp_time]', ...
    string({rows.line_search_failure_status})',[rows.qp_failures]', ...
    [rows.nonfinite_events]',[rows.q_violation_count]', ...
    [rows.g_violation_count]',[rows.max_q_excess]',[rows.max_g_excess]', ...
    'VariableNames',{'set_name','problem','problem_index','natural_domain', ...
    'method','eta','trial','status','iterations','theta','v_norm', ...
    'steepest_directional_value','vector_F','vector_J','qp_solves', ...
    'line_search_trials','wall_time','evaluation_time','qp_time', ...
    'line_search_failure_status','qp_failures','nonfinite_events', ...
    'q_violation_count','g_violation_count','max_q_excess','max_g_excess'});
end

function result = make_mechanism_per_run(rows)
n = numel(rows);
result = table('Size',[n 22], ...
    'VariableTypes',{'string','string','double','string','double','double', ...
    'double','double','double','double','double','double','double','double', ...
    'double','double','double','double','double','double','double','double'}, ...
    'VariableNames',{'set_name','problem','problem_index','method','eta', ...
    'trial','directions','q_median','q_p90','q_p99','q_max','g_median', ...
    'g_p90','g_p99','g_max','angle_median','angle_p90','angle_p99', ...
    'angle_max','beta_observations','cap_active_rate', ...
    'lower_truncation_rate'});
for k = 1:n
    q = finite_values(rows(k).q_values);
    g = finite_values(rows(k).g_values);
    a = finite_values(rows(k).angle_values);
    qStats = distribution_stats(q);
    gStats = distribution_stats(g);
    aStats = distribution_stats(a);
    result.set_name(k) = string(rows(k).set_name);
    result.problem(k) = string(rows(k).problem);
    result.problem_index(k) = rows(k).problem_index;
    result.method(k) = string(rows(k).method);
    result.eta(k) = rows(k).eta;
    result.trial(k) = rows(k).trial;
    result.directions(k) = numel(rows(k).q_values);
    result{k,8:11} = qStats;
    result{k,12:15} = gStats;
    result{k,16:19} = aStats;
    result.beta_observations(k) = numel(rows(k).cap_active_values);
    result.cap_active_rate(k) = logical_rate(rows(k).cap_active_values);
    result.lower_truncation_rate(k) = ...
        logical_rate(rows(k).lower_truncation_values);
end
end

function result = aggregate_mechanism_by_problem(runSummary)
keys = unique(runSummary(:,{'set_name','problem','problem_index','method','eta'}), ...
    'rows','stable');
valueNames = runSummary.Properties.VariableNames(7:end);
result = table();
for k = 1:height(keys)
    use = runSummary.set_name==keys.set_name(k) & ...
        runSummary.problem==keys.problem(k) & ...
        runSummary.method==keys.method(k) & runSummary.eta==keys.eta(k);
    block = runSummary(use,:);
    values = zeros(1,numel(valueNames));
    for j = 1:numel(valueNames)
        name = valueNames{j};
        if endsWith(name,'_max')
            values(j) = max(block.(name),[],'omitnan');
        else
            values(j) = median(block.(name),'omitnan');
        end
    end
    row = [keys(k,:),array2table(values,'VariableNames',valueNames)];
    row.runs = height(block);
    result = [result;row]; %#ok<AGROW>
end
end

function result = aggregate_mechanism_across_problems(perProblem,cfg)
slices = analysis_slices(perProblem,cfg);
valueNames = perProblem.Properties.VariableNames(6:end);
result = table();
for sliceIndex = 1:numel(slices)
    source = perProblem(slices(sliceIndex).use,:);
    pairs = unique(source(:,{'method','eta'}),'rows','stable');
    for k = 1:height(pairs)
        block = source(source.method==pairs.method(k) & ...
            source.eta==pairs.eta(k),:);
        values = zeros(1,numel(valueNames));
        for j = 1:numel(valueNames)
            name = valueNames{j};
            if endsWith(name,'_max')
                values(j) = max(block.(name),[],'omitnan');
            else
                values(j) = median(block.(name),'omitnan');
            end
        end
        row = [table(string(slices(sliceIndex).name),pairs.method(k), ...
            pairs.eta(k),height(block),'VariableNames', ...
            {'set_name','method','eta','problems'}), ...
            array2table(values,'VariableNames',valueNames)];
        result = [result;row]; %#ok<AGROW>
    end
end
end

function outcomes = make_outcomes(runs)
[group,setName,method,eta,problem,status] = findgroups(runs.set_name, ...
    runs.method,runs.eta,runs.problem,runs.status);
count = splitapply(@numel,runs.trial,group);
outcomes = table(setName,method,eta,problem,status,count, ...
    'VariableNames',{'set_name','method','eta','problem','status','runs'});
end

function result = make_work_per_problem(runs)
keys = unique(runs(:,{'set_name','problem','method','eta'}),'rows','stable');
metrics = {'iterations','vector_F','vector_J','qp_solves','line_search_trials'};
result = table();
for k = 1:height(keys)
    block = runs(runs.set_name==keys.set_name(k) & ...
        runs.problem==keys.problem(k) & runs.method==keys.method(k) & ...
        runs.eta==keys.eta(k),:);
    success = block.status=="converged";
    values = NaN(1,numel(metrics));
    for j = 1:numel(metrics)
        values(j) = conditional_median(block.(metrics{j}),success);
    end
    result = [result;keys(k,:),table(height(block),sum(success), ...
        'VariableNames',{'runs','successes'}), ...
        array2table(values,'VariableNames',strcat('median_',metrics))]; %#ok<AGROW>
end
end

function cpu = make_cpu_summary(runs)
keys = unique(runs(:,{'set_name','problem','method','eta'}),'rows','stable');
cpu = table();
for k = 1:height(keys)
    block = runs(runs.set_name==keys.set_name(k) & ...
        runs.problem==keys.problem(k) & runs.method==keys.method(k) & ...
        runs.eta==keys.eta(k),:);
    success = block.status=="converged";
    cpu = [cpu;keys(k,:),table(sum(success), ...
        conditional_median(block.wall_time,success), ...
        conditional_median(block.evaluation_time,success), ...
        conditional_median(block.qp_time,success), ...
        'VariableNames',{'successes','median_wall_time_descriptive', ...
        'median_evaluation_time_descriptive','median_qp_time_descriptive'})]; %#ok<AGROW>
end
end

function slices = analysis_slices(source,cfg)
isPrimary = source.set_name=="primary15";
isE2 = source.set_name=="E2";
if ismember('problem_index',source.Properties.VariableNames)
    noNatural = ~ismember(source.problem_index,cfg.natural_domain_indices);
else
    noNatural = ~ismember(source.problem,["TE8-15","TE8-30","TE8-50"]);
end
slices = struct('name',{'primary15','primary12_no_TE8','E2'}, ...
    'use',{isPrimary,isPrimary & noNatural,isE2});
slices = slices(arrayfun(@(s) any(s.use),slices));
end

function values = finite_values(values)
values = values(isfinite(values));
end

function stats = distribution_stats(values)
if isempty(values)
    stats = NaN(1,4);
else
    stats = [median(values),quantile(values,0.9),quantile(values,0.99), ...
        max(values)];
end
end

function value = logical_rate(values)
if isempty(values), value = NaN; else, value = mean(logical(values)); end
end

function value = conditional_median(values,use)
if any(use), value = median(values(use),'omitnan'); else, value = NaN; end
end

function ensure_folder(path)
if ~isfolder(path), mkdir(path); end
end
