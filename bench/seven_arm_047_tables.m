function report = seven_arm_047_tables(runs,iterations)
%SEVEN_ARM_047_TABLES Build exchange-047 non-front reporting tables.

if any(runs.component_F~=runs.component_J)
    error('mcode:UnequalSevenArm047Evaluations', ...
        'Component F and J counts must agree on every reported run.');
end
report = struct( ...
    'outcomes',outcome_table(runs), ...
    'stopping_accuracy',stopping_table(runs), ...
    'descent',descent_table(runs,iterations), ...
    'paired_work',paired_reference_table(runs), ...
    'family_work',family_work_table(runs), ...
    'identical_iterations',identical_iteration_table(runs));
end

function output = outcome_table(runs)
methods = seven_arm_047_methods().display_name;
converged = zeros(7,1); iterationLimit = zeros(7,1);
lineSearch = zeros(7,1); nonDescent = zeros(7,1); successRate = zeros(7,1);
for m = 1:numel(methods)
    status = runs.status(runs.method==methods(m));
    known = ismember(status,["converged" "max_iter" ...
        "line_search_failed" "no_descent"]);
    if ~all(known)
        error('mcode:UnexpectedSevenArm047Status', ...
            'Unexpected terminal status for %s.',methods(m));
    end
    converged(m) = sum(status=="converged");
    iterationLimit(m) = sum(status=="max_iter");
    lineSearch(m) = sum(status=="line_search_failed");
    nonDescent(m) = sum(status=="no_descent");
    successRate(m) = converged(m)/numel(status);
end
output = table(methods,converged,iterationLimit,lineSearch,nonDescent, ...
    successRate,'VariableNames',{'method','converged','iteration_limit', ...
    'line_search','non_descent','success_rate'});
end

function output = stopping_table(runs)
methods = seven_arm_047_methods().display_name;
problemsDefined = zeros(7,1);
medianProblemMedian = NaN(7,1);
for m = 1:numel(methods)
    block = runs(runs.method==methods(m),:);
    problems = unique(block.problem,'stable');
    medians = NaN(numel(problems),1);
    for p = 1:numel(problems)
        use = block.problem==problems(p) & block.status=="converged";
        if any(use), medians(p) = median(block.v_norm(use),'omitnan'); end
    end
    valid = ~isnan(medians);
    problemsDefined(m) = sum(valid);
    if any(valid), medianProblemMedian(m) = median(medians(valid)); end
end
output = table(methods,problemsDefined,medianProblemMedian, ...
    'VariableNames',{'method','problems_defined', ...
    'median_problem_median_v_norm'});
end

function output = descent_table(runs,iterations)
methods = seven_arm_047_methods().display_name;
metadata = runs(runs.set_name=="NC10",{'run_key','method'});
joined = innerjoin(iterations,metadata,'Keys','run_key');
directionsFormed = zeros(7,1); violations = zeros(7,1);
violationRate = zeros(7,1); nonDescentViolations = zeros(7,1);
for m = 1:numel(methods)
    use = joined.method==methods(m);
    bad = use & ~joined.descent_bound_holds;
    directionsFormed(m) = sum(use);
    violations(m) = sum(bad);
    if directionsFormed(m)>0
        violationRate(m) = violations(m)/directionsFormed(m);
    else
        violationRate(m) = NaN;
    end
    nonDescentViolations(m) = sum(bad & joined.directional_value>=0);
end
output = table(methods,directionsFormed,violations,violationRate, ...
    nonDescentViolations,'VariableNames',{'method','directions_formed', ...
    'violations','violation_rate','non_descent_violations'});
end

function output = paired_reference_table(runs)
methods = seven_arm_047_methods().display_name;
pairedSuccesses = zeros(7,1); iterationRatio = NaN(7,1);
evaluationRatio = NaN(7,1);
reference = ordered(runs(runs.method=="SVPRP+",:));
for m = 1:numel(methods)
    current = ordered(runs(runs.method==methods(m),:));
    assert_paired(current,reference);
    both = current.status=="converged" & reference.status=="converged";
    pairedSuccesses(m) = sum(both);
    iterationRatio(m) = shifted_geomean( ...
        current.iterations(both),reference.iterations(both));
    evaluationRatio(m) = shifted_geomean( ...
        current.component_F(both),reference.component_F(both));
end
output = table(methods,pairedSuccesses,iterationRatio,evaluationRatio, ...
    'VariableNames',{'method','paired_successes', ...
    'iterations_over_SVPRP','component_F_J_over_SVPRP'});
end

function output = family_work_table(runs)
unsafeguardedMethods = ["VPRP+";"VHS+";"VLS+"];
safeguardedMethods = ["SVPRP+";"SVHS+";"SVLS+"];
slices = ["theorem-compatible archived";"H1-H5";"D1-D10"];
unsafeguarded = strings(9,1); safeguarded = strings(9,1);
slice = strings(9,1); pairedSuccesses = zeros(9,1);
iterationRatio = NaN(9,1); evaluationRatio = NaN(9,1);
row = 0;
for pair = 1:3
    for s = 1:3
        row = row+1;
        mask = slice_mask(runs,slices(s));
        left = ordered(runs(mask & runs.method==unsafeguardedMethods(pair),:));
        right = ordered(runs(mask & runs.method==safeguardedMethods(pair),:));
        assert_paired(left,right);
        both = left.status=="converged" & right.status=="converged";
        unsafeguarded(row) = unsafeguardedMethods(pair);
        safeguarded(row) = safeguardedMethods(pair);
        slice(row) = slices(s);
        pairedSuccesses(row) = sum(both);
        iterationRatio(row) = shifted_geomean( ...
            left.iterations(both),right.iterations(both));
        evaluationRatio(row) = shifted_geomean( ...
            left.component_F(both),right.component_F(both));
    end
end
output = table(unsafeguarded,safeguarded,slice,pairedSuccesses, ...
    iterationRatio,evaluationRatio,'VariableNames',{'unsafeguarded', ...
    'safeguarded','slice','paired_successes','iterations_ratio', ...
    'component_F_J_ratio'});
end

function output = identical_iteration_table(runs)
leftMethod = ["SVLS+";"SVPRP+"];
rightMethod = ["SVPRP+";"VSD"];
pairedSuccesses = zeros(2,1); identicalIterations = zeros(2,1);
for k = 1:2
    left = ordered(runs(runs.method==leftMethod(k),:));
    right = ordered(runs(runs.method==rightMethod(k),:));
    assert_paired(left,right);
    both = left.status=="converged" & right.status=="converged";
    pairedSuccesses(k) = sum(both);
    identicalIterations(k) = sum( ...
        left.iterations(both)==right.iterations(both));
end
output = table(leftMethod,rightMethod,pairedSuccesses,identicalIterations, ...
    'VariableNames',{'left_method','right_method','paired_successes', ...
    'identical_iterations'});
end

function mask = slice_mask(runs,name)
switch name
    case "theorem-compatible archived"
        mask = runs.tier==1 & runs.theorem_compatible;
    case "H1-H5"
        mask = runs.set_name=="E2";
    case "D1-D10"
        mask = runs.set_name=="NC10";
end
end

function rows = ordered(rows)
rows = sortrows(rows,{'problem','start_id'});
end

function assert_paired(left,right)
if height(left)~=height(right) || any(left.problem~=right.problem) || ...
        any(left.start_id~=right.start_id)
    error('mcode:UnpairedSevenArm047','Seven-arm task keys differ.');
end
end

function value = shifted_geomean(left,right)
if isempty(left), value = NaN; return; end
ratio = (double(left)+1)./(double(right)+1);
value = exp(mean(log(ratio)));
end
