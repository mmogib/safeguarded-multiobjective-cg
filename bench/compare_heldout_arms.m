function comparison = compare_heldout_arms(rows, leftMethod, leftEta, ...
    rightMethod, rightEta, problemIndices)
%COMPARE_HELDOUT_ARMS Apply the frozen success-first pairwise convention.

left = select_arm(rows,leftMethod,leftEta,problemIndices);
right = select_arm(rows,rightMethod,rightEta,problemIndices);
left = sortrows(left,{'legacy_index','trial'});
right = sortrows(right,{'legacy_index','trial'});
if height(left) ~= height(right) || ...
        any(left.legacy_index~=right.legacy_index) || any(left.trial~=right.trial)
    error('mcode:UnpairedHeldoutArms','Held-out arms do not share task keys.');
end

metrics = {'iterations','component_F','component_J','qp_solves'};
aggregate = table();
perProblem = table();
for metricIndex = 1:numel(metrics)
    metric = metrics{metricIndex};
    aggregate = [aggregate; comparison_row(left,right,metric,"all")]; %#ok<AGROW>
    problems = unique(left.problem,'stable');
    for problemIndex = 1:numel(problems)
        use = left.problem==problems(problemIndex);
        row = comparison_row(left(use,:),right(use,:),metric,problems(problemIndex));
        perProblem = [perProblem; row]; %#ok<AGROW>
    end
end

comparison = struct('left_arm',arm_name(leftMethod,leftEta), ...
    'right_arm',arm_name(rightMethod,rightEta), ...
    'aggregate',aggregate,'per_problem',perProblem);
end

function selected = select_arm(rows, method, eta, problemIndices)
etaUse = (isnan(rows.eta) & isnan(eta)) | rows.eta==eta;
use = rows.method==string(method) & etaUse & ...
    ismember(rows.legacy_index,problemIndices);
selected = rows(use,:);
end

function row = comparison_row(left,right,metric,slice)
leftSuccess = left.status=="converged";
rightSuccess = right.status=="converged";
paired = leftSuccess & rightSuccess;
leftOnly = leftSuccess & ~rightSuccess;
rightOnly = ~leftSuccess & rightSuccess;
bothFailed = ~leftSuccess & ~rightSuccess;
if any(paired)
    ratios = left.(metric)(paired)./right.(metric)(paired);
    geometricMean = exp(mean(log(ratios)));
    wins = sum(ratios<1);
    ties = sum(ratios==1);
    losses = sum(ratios>1);
else
    geometricMean = NaN;
    wins = 0;
    ties = 0;
    losses = 0;
end
row = table(string(slice),string(metric),height(left),sum(leftSuccess), ...
    sum(rightSuccess),sum(paired),sum(leftOnly),sum(rightOnly),sum(bothFailed), ...
    geometricMean,wins,ties,losses, ...
    'VariableNames',{'slice','metric','tasks','left_successes', ...
    'right_successes','paired_successes','left_only_success','right_only_success', ...
    'both_failed','geomean_left_over_right','work_wins','work_ties','work_losses'});
end

function label = arm_name(method,eta)
label = string(method);
if ~isnan(eta)
    label = label+"_eta"+replace(string(sprintf('%.15g',eta)),'.','p');
end
end
