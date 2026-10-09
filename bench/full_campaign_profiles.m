function output = full_campaign_profiles(runs)
%FULL_CAMPAIGN_PROFILES Ordinary and failure-aware work profiles by slice.

metrics = {'iterations','component_F','component_J', ...
    'line_search_trials','qp_solves'};
slices = full_campaign_slices(runs);
ratios = table(); curves = table();
for sliceIndex = 1:height(slices)
    sliceName = slices.name(sliceIndex);
    block = runs(slices.mask{sliceIndex},:);
    methods = unique(block.method,'stable');
    [taskGroup,~,~] = findgroups(block.problem,block.start_id);
    for metricIndex = 1:numel(metrics)
        metric = string(metrics{metricIndex});
        % Operation counts are nonnegative and can be zero when a start is
        % already stationary.  Shift every count by one so ratios remain
        % defined without changing ordering or success classification.
        work = double(block.(metric))+1;
        best = splitapply(@best_success,work,block.status,taskGroup);
        success = block.status=="converged";
        ratio = inf(height(block),1);
        ratio(success) = work(success)./best(taskGroup(success));
        metricRows = table(repmat(sliceName,height(block),1),block.run_key, ...
            block.method,block.problem,block.start_id, ...
            repmat(metric,height(block),1),ratio,success, ...
            'VariableNames',{'slice','run_key','method','problem','start_id', ...
            'metric','ratio','success'});
        ratios = [ratios;metricRows]; %#ok<AGROW>

        finiteValues = unique(ratio(isfinite(ratio)));
        tau = [finiteValues;Inf];
        for methodIndex = 1:numel(methods)
            methodMask = block.method==methods(methodIndex);
            methodRatios = ratio(methodMask);
            methodSuccess = success(methodMask);
            proportion = zeros(numel(tau),1);
            for q = 1:numel(tau)
                if isinf(tau(q))
                    proportion(q) = mean(methodSuccess);
                else
                    proportion(q) = mean(methodRatios<=tau(q));
                end
            end
            curves = [curves;table(repmat(sliceName,numel(tau),1), ...
                repmat(methods(methodIndex),numel(tau),1), ...
                repmat(metric,numel(tau),1),tau,proportion, ...
                'VariableNames',{'slice','method','metric','tau', ...
                'proportion'})]; %#ok<AGROW>
        end
    end
end
output = struct('ratios',ratios,'curves',curves);
end

function value = best_success(values,status)
successful = values(status=="converged");
if isempty(successful), value = Inf; else, value = min(successful); end
end
