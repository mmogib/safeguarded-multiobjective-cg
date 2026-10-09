function output = nonlipschitz_performance_profiles(rows)
%NONLIPSCHITZ_PERFORMANCE_PROFILES Failure-aware E3 profiles, excluding CPU.

metrics = {'iterations','component_F','component_J', ...
    'line_search_trials','qp_solves'};
[taskGroup,~,~] = findgroups(rows.problem,rows.trial);
ratios = table();
for metricIndex = 1:numel(metrics)
    metric = metrics{metricIndex};
    best = splitapply(@best_success,rows.(metric),rows.status,taskGroup);
    ratio = inf(height(rows),1);
    success = rows.status == "converged";
    ratio(success) = rows.(metric)(success)./best(taskGroup(success));
    ratios = [ratios; table(rows.method,rows.problem,rows.trial, ...
        repmat(string(metric),height(rows),1),ratio,success, ...
        'VariableNames',{'method','problem','trial','metric','ratio', ...
        'success'})]; %#ok<AGROW>
end

methods = unique(rows.method,'stable');
curves = table();
sliceNames = "all";
if any(startsWith(ratios.problem,"E2-")), sliceNames(end+1) = "E2"; end
if any(startsWith(ratios.problem,"NL10-")), sliceNames(end+1) = "NL10"; end
sliceNames = [sliceNames,unique(ratios.problem,'stable')'];
for sliceIndex = 1:numel(sliceNames)
    slice = sliceNames(sliceIndex);
    sliceUse = select_slice(ratios.problem,slice);
    for metricIndex = 1:numel(metrics)
        metric = string(metrics{metricIndex});
        metricUse = sliceUse & ratios.metric == metric;
        finiteRatios = ratios.ratio(metricUse & isfinite(ratios.ratio));
        tauValues = [unique(finiteRatios);Inf];
        for methodIndex = 1:numel(methods)
            methodUse = metricUse & ratios.method == methods(methodIndex);
            methodRatios = ratios.ratio(methodUse);
            proportions = zeros(numel(tauValues),1);
            for tauIndex = 1:numel(tauValues)
                if isinf(tauValues(tauIndex))
                    proportions(tauIndex) = mean(isfinite(methodRatios));
                else
                    proportions(tauIndex) = mean(methodRatios <= tauValues(tauIndex));
                end
            end
            curves = [curves; table( ...
                repmat(slice,numel(tauValues),1), ...
                repmat(methods(methodIndex),numel(tauValues),1), ...
                repmat(metric,numel(tauValues),1),tauValues,proportions, ...
                'VariableNames',{'slice','method','metric','tau', ...
                'proportion'})]; %#ok<AGROW>
        end
    end
end
output = struct('ratios',ratios,'curves',curves);
end

function use = select_slice(problems,slice)
if slice=="all"
    use = true(size(problems));
elseif slice=="E2"
    use = startsWith(problems,"E2-");
elseif slice=="NL10"
    use = startsWith(problems,"NL10-");
else
    use = problems==slice;
end
end

function value = best_success(values,statuses)
successful = values(statuses == "converged");
if isempty(successful), value = Inf; else, value = min(successful); end
end
