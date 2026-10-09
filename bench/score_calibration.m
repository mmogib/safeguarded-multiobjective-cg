function [scores, selectedEta] = score_calibration(rows, candidates, selectionCandidates)
%SCORE_CALIBRATION Apply the preregistered success/ItN/FeN/GeN rule.

candidates = candidates(:);
if nargin < 3
    selectionCandidates = candidates;
else
    selectionCandidates = selectionCandidates(:);
end
selectionEligible = ismember(candidates,selectionCandidates);
if isempty(selectionCandidates) || any(~ismember(selectionCandidates,candidates))
    error('mcode:InvalidSelectionCandidates', ...
        'Selection candidates must be a nonempty subset of reported candidates.');
end
successes = zeros(numel(candidates),1);
aggregate = inf(numel(candidates),1);
metrics = {'iterations','component_F','component_J'};
[groups, methodNames, problemNames] = findgroups(rows.method, rows.problem); %#ok<ASGLU>
groupIds = unique(groups);
ratios = cell(numel(candidates),1);
for candidateIndex = 1:numel(candidates)
    ratios{candidateIndex} = [];
    selected = rows.eta == candidates(candidateIndex);
    successes(candidateIndex) = sum(selected & rows.status == "converged");
end

for groupIndex = groupIds'
    inGroup = groups == groupIndex;
    for metricIndex = 1:numel(metrics)
        medians = nan(numel(candidates),1);
        for candidateIndex = 1:numel(candidates)
            use = inGroup & rows.eta == candidates(candidateIndex) & ...
                rows.status == "converged";
            if any(use)
                medians(candidateIndex) = median(rows.(metrics{metricIndex})(use));
            end
        end
        % A diagnostic control must not alter the preregistered positive-arm
        % normalization or the selected positive parameter.
        baseline = min(medians(selectionEligible), [], 'omitnan');
        for candidateIndex = 1:numel(candidates)
            ratios{candidateIndex}(end+1) = medians(candidateIndex)/baseline; %#ok<AGROW>
        end
    end
end

for candidateIndex = 1:numel(candidates)
    values = ratios{candidateIndex};
    if ~isempty(values) && all(isfinite(values)) && all(values > 0)
        aggregate(candidateIndex) = exp(mean(log(values)));
    end
end

maxSuccess = max(successes(selectionEligible));
eligible = selectionEligible & successes == maxSuccess;
minimumScore = min(aggregate(eligible));
withinTieBand = eligible & aggregate <= 1.01*minimumScore;
tieCandidates = find(withinTieBand);
[~, closest] = min(abs(candidates(tieCandidates)-1));
selectedIndex = tieCandidates(closest);
selectedEta = candidates(selectedIndex);
scores = table(candidates, successes, aggregate, selectionEligible, withinTieBand, ...
    (1:numel(candidates))' == selectedIndex, ...
    'VariableNames', {'eta','successes','score','selection_eligible', ...
    'within_tie_band','selected'});
end
