function [ratios,scores,gate] = reduce_eta_study_work(perProblem,runs,cfg)
%REDUCE_ETA_STUDY_WORK Apply the exchange-036 per-metric work gate.

[ratios,scores] = make_work_scores(perProblem,cfg);
gate = evaluate_gate(runs,scores,cfg);
end

function [ratios,scores] = make_work_scores(perProblem,cfg)
metrics = {'iterations','vector_F','vector_J'};
scoreNames = {'ItN_ratio','FeN_ratio','GeN_ratio'};
slices = analysis_slices(perProblem,cfg);
ratios = table();
scores = table();
for sliceIndex = 1:numel(slices)
    block = perProblem(slices(sliceIndex).use,:);
    positives = block(block.eta>0,:);
    methods = unique(positives.method,'stable');
    problems = unique(positives.problem,'stable');
    for eta = cfg.grid
        successes = 0;
        runsCount = 0;
        for methodIndex = 1:numel(methods)
            method = methods(methodIndex);
            for problemIndex = 1:numel(problems)
                problem = problems(problemIndex);
                for metricIndex = 1:numel(metrics)
                    metric = metrics{metricIndex};
                    field = ['median_' metric];
                    reference = positives(positives.method==method & ...
                        positives.problem==problem,:);
                    if isempty(reference), continue; end
                    best = min(reference.(field),[],'omitnan');
                    if eta == 0
                        candidate = block(block.method=="MOSD" & ...
                            block.problem==problem,:);
                        arm = "MOSD";
                    else
                        candidate = block(block.method==method & ...
                            block.problem==problem & block.eta==eta,:);
                        arm = method;
                    end
                    if isempty(candidate), continue; end
                    ratio = candidate.(field)/best;
                    ratios = [ratios;table(string(slices(sliceIndex).name), ...
                        eta,method,arm,problem,string(metric),candidate.(field), ...
                        best,ratio,candidate.successes,candidate.runs, ...
                        'VariableNames',{'set_name','eta','target_method','arm', ...
                        'problem','metric','median_work','best_positive_median', ...
                        'ratio','successes','runs'})]; %#ok<AGROW>
                end
                if eta == 0
                    candidate = block(block.method=="MOSD" & ...
                        block.problem==problem,:);
                else
                    candidate = block(block.method==method & ...
                        block.problem==problem & block.eta==eta,:);
                end
                if ~isempty(candidate)
                    successes = successes+candidate.successes;
                    runsCount = runsCount+candidate.runs;
                end
            end
        end
        current = ratios(ratios.set_name==string(slices(sliceIndex).name) & ...
            ratios.eta==eta,:);
        etaOne = ratios(ratios.set_name==string(slices(sliceIndex).name) & ...
            ratios.eta==1,:);
        metricScores = NaN(1,numel(metrics));
        wins = NaN(1,numel(metrics));
        ties = NaN(1,numel(metrics));
        losses = NaN(1,numel(metrics));
        for metricIndex = 1:numel(metrics)
            metric = string(metrics{metricIndex});
            metricCurrent = current(current.metric==metric,:);
            metricEtaOne = etaOne(etaOne.metric==metric,:);
            if isempty(metricCurrent)
                metricScores(metricIndex) = NaN;
            elseif any(~isfinite(metricCurrent.ratio))
                metricScores(metricIndex) = Inf;
            else
                metricScores(metricIndex) = ...
                    exp(mean(log(metricCurrent.ratio)));
            end
            if ~isempty(metricCurrent) && ~isempty(metricEtaOne)
                compare = metricCurrent.ratio./metricEtaOne.ratio;
                tolerance = 10*eps(max(1,max(abs(compare))));
                wins(metricIndex) = sum(compare<1-tolerance);
                ties(metricIndex) = sum(abs(compare-1)<=tolerance);
                losses(metricIndex) = sum(compare>1+tolerance);
            end
        end
        scores = [scores;table(string(slices(sliceIndex).name),eta, ...
            successes,runsCount,metricScores(1),metricScores(2), ...
            metricScores(3),wins(1),ties(1),losses(1),wins(2),ties(2), ...
            losses(2),wins(3),ties(3),losses(3), ...
            'VariableNames',[{'set_name','eta','successes','runs'}, ...
            scoreNames,{'ItN_wins_vs_eta_one','ItN_ties_vs_eta_one', ...
            'ItN_losses_vs_eta_one','FeN_wins_vs_eta_one', ...
            'FeN_ties_vs_eta_one','FeN_losses_vs_eta_one', ...
            'GeN_wins_vs_eta_one','GeN_ties_vs_eta_one', ...
            'GeN_losses_vs_eta_one'}])]; %#ok<AGROW>
    end
end
end

function gate = evaluate_gate(runs,scores,cfg)
primaryScores = scores(scores.set_name=="primary15" & scores.eta>0,:);
etaOne = primaryScores(primaryScores.eta==1,:);
bestSuccesses = max(primaryScores.successes);
eligible = primaryScores.successes==bestSuccesses;
scoreNames = {'ItN_ratio','FeN_ratio','GeN_ratio'};
etaOneScores = zeros(1,numel(scoreNames));
bestScores = zeros(1,numel(scoreNames));
scoreRatios = zeros(1,numel(scoreNames));
for k = 1:numel(scoreNames)
    etaOneScores(k) = etaOne.(scoreNames{k});
    bestScores(k) = min(primaryScores.(scoreNames{k})(eligible));
    scoreRatios(k) = etaOneScores(k)/bestScores(k);
end
criterion1 = etaOne.successes==bestSuccesses;
criterion2 = all(scoreRatios<=1.01);
etaOneRuns = runs(runs.set_name=="primary15" & runs.eta==1,:);
otherRuns = runs(runs.set_name=="primary15" & runs.eta>0 & runs.eta~=1,:);
etaOneCategories = unique(etaOneRuns.line_search_failure_status( ...
    etaOneRuns.line_search_failure_status~=""));
otherCategories = unique(otherRuns.line_search_failure_status( ...
    otherRuns.line_search_failure_status~=""));
newCategories = setdiff(etaOneCategories,otherCategories);
criterion3 = isempty(newCategories);
qViolations = sum(etaOneRuns.q_violation_count);
gViolations = sum(etaOneRuns.g_violation_count);
criterion4 = qViolations==0 && gViolations==0;
gate = table(criterion1,criterion2,criterion3,criterion4, ...
    criterion1&&criterion2&&criterion3&&criterion4,etaOne.successes, ...
    bestSuccesses,etaOneScores(1),etaOneScores(2),etaOneScores(3), ...
    bestScores(1),bestScores(2),bestScores(3),scoreRatios(1), ...
    scoreRatios(2),scoreRatios(3),qViolations,gViolations, ...
    strjoin(newCategories,';'),cfg.invariant_abs_tol,cfg.invariant_rel_tol, ...
    'VariableNames',{'criterion1_success','criterion2_work', ...
    'criterion3_line_search','criterion4_invariants','pass', ...
    'successes_eta_one','best_positive_successes','ItN_ratio_eta_one', ...
    'FeN_ratio_eta_one','GeN_ratio_eta_one', ...
    'best_positive_ItN_ratio','best_positive_FeN_ratio', ...
    'best_positive_GeN_ratio','ItN_ratio_to_best','FeN_ratio_to_best', ...
    'GeN_ratio_to_best','q_violations','g_violations', ...
    'new_line_search_categories','invariant_abs_tol','invariant_rel_tol'});
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
