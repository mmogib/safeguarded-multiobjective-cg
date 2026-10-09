function summary = summarize_heldout(rows, asscaCompatibleIndices)
%SUMMARIZE_HELDOUT Build failure-aware tables and performance profiles.

labels = heldout_arm_labels(rows);
arms = unique(labels,'stable');
problems = unique(rows.problem,'stable');

perProblem = table();
for armIndex = 1:numel(arms)
    for problemIndex = 1:numel(problems)
        use = labels==arms(armIndex) & rows.problem==problems(problemIndex);
        if ~any(use)
            continue
        end
        block = rows(use,:);
        success = block.status=="converged";
        perProblem = [perProblem; table(arms(armIndex),block.method(1), ...
            block.eta(1),problems(problemIndex),block.legacy_index(1), ...
            ismember(block.legacy_index(1),asscaCompatibleIndices), ...
            height(block),sum(success),conditional_median(block.iterations,success), ...
            conditional_median(block.component_F,success), ...
            conditional_median(block.component_J,success), ...
            conditional_median(block.qp_solves,success), ...
            conditional_median(block.wall_time,success), ...
            'VariableNames',{'arm','method','eta','problem','legacy_index', ...
            'assca_compatible','runs','successes','median_iterations', ...
            'median_component_F','median_component_J','median_qp_solves', ...
            'median_wall_time_descriptive'})]; %#ok<AGROW>
    end
end

[outcomeGroup,outcomeArm,outcomeStatus] = findgroups(labels,rows.status);
outcomeRuns = splitapply(@numel,rows.status,outcomeGroup);
outcomes = table(outcomeArm,outcomeStatus,outcomeRuns, ...
    'VariableNames',{'arm','status','runs'});

metrics = {'iterations','component_F','component_J','qp_solves'};
[taskGroup,~,~] = findgroups(rows.problem,rows.trial);
profileRatios = table();
for metricIndex = 1:numel(metrics)
    metric = metrics{metricIndex};
    best = splitapply(@best_success,rows.(metric),rows.status,taskGroup);
    ratio = inf(height(rows),1);
    success = rows.status=="converged";
    ratio(success) = rows.(metric)(success)./best(taskGroup(success));
    profileRatios = [profileRatios; table(labels,rows.problem,rows.trial, ...
        repmat(string(metric),height(rows),1),ratio,success, ...
        'VariableNames',{'arm','problem','trial','metric','ratio','success'})]; %#ok<AGROW>
end

profileCurves = table();
for metricIndex = 1:numel(metrics)
    metric = string(metrics{metricIndex});
    metricUse = profileRatios.metric==metric;
    finiteRatios = profileRatios.ratio(metricUse & isfinite(profileRatios.ratio));
    tauValues = [unique(finiteRatios); Inf];
    for armIndex = 1:numel(arms)
        armUse = metricUse & profileRatios.arm==arms(armIndex);
        armRatios = profileRatios.ratio(armUse);
        proportions = zeros(numel(tauValues),1);
        for tauIndex = 1:numel(tauValues)
            if isinf(tauValues(tauIndex))
                proportions(tauIndex) = mean(isfinite(armRatios));
            else
                proportions(tauIndex) = mean(armRatios<=tauValues(tauIndex));
            end
        end
        profileCurves = [profileCurves; table( ...
            repmat(arms(armIndex),numel(tauValues),1), ...
            repmat(metric,numel(tauValues),1),tauValues,proportions, ...
            'VariableNames',{'arm','metric','tau','proportion'})]; %#ok<AGROW>
    end
end

eventUse = rows.status=="no_descent";
noDescent = table(labels(eventUse),rows.method(eventUse),rows.problem(eventUse), ...
    rows.trial(eventUse),rows.no_descent_iteration(eventUse), ...
    rows.no_descent_value(eventUse),rows.no_descent_steepest_value(eventUse), ...
    rows.no_descent_steepest_norm_squared(eventUse), ...
    rows.no_descent_value(eventUse)./(-rows.no_descent_steepest_value(eventUse)), ...
    rows.no_descent_value(eventUse)./rows.no_descent_steepest_norm_squared(eventUse), ...
    'VariableNames',{'arm','method','problem','trial','iteration', ...
    'directional_value','steepest_directional_value','steepest_norm_squared', ...
    'directional_over_steepest','directional_over_norm_squared'});

summary = struct('per_problem',perProblem,'outcomes',outcomes, ...
    'profile_ratios',profileRatios,'profile_curves',profileCurves, ...
    'no_descent',noDescent);
end

function value = conditional_median(values, use)
if any(use)
    value = median(values(use));
else
    value = NaN;
end
end

function value = best_success(values, statuses)
successful = values(statuses=="converged");
if isempty(successful)
    value = Inf;
else
    value = min(successful);
end
end
