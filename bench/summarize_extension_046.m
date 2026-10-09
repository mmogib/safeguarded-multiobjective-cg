function report = summarize_extension_046(storeRoot,referenceStoreRoot,outputDir)
%SUMMARIZE_EXTENSION_046 Report the sealed HS+/LS+ campaign from exchange 046.

require_sealed(storeRoot);
require_sealed(referenceStoreRoot);
if ~isfolder(outputDir), mkdir(outputDir); end

runs = campaignstore.load_table(storeRoot,'runs');
iterations = campaignstore.load_table(storeRoot,'iterations');
fallbackEvents = campaignstore.load_table(storeRoot,'beta_fallback_events');
referenceRuns = campaignstore.load_table(referenceStoreRoot,'runs');
referenceRuns = referenceRuns(referenceRuns.method=="TTCGP",:);

validate_runs(runs,referenceRuns);
[outcomes,statusDetails] = outcome_table(runs);
[descent,descentViolations] = descent_table(runs,iterations);
pairedWork = paired_work_table(runs,referenceRuns);
[fallbacks,fallbackPolicies] = fallback_tables( ...
    runs,iterations,fallbackEvents);

report = struct('outcomes',outcomes,'status_details',statusDetails, ...
    'descent',descent,'descent_violations',descentViolations, ...
    'paired_work',pairedWork,'fallbacks',fallbacks, ...
    'fallback_policies',fallbackPolicies);
names = fieldnames(report);
for k = 1:numel(names)
    value = report.(names{k});
    if istable(value)
        writetable(value,fullfile(outputDir,[names{k} '.csv']));
    end
end
save(fullfile(outputDir,'extension_046_report.mat'),'report','-v7.3');
end

function require_sealed(root)
if ~isfile(fullfile(root,'archive_manifest.csv'))
    error('campaignstore:UnsealedCampaign', ...
        'Extension reporting requires sealed stores.');
end
end

function validate_runs(runs,reference)
if height(runs) ~= 13200 || ...
        ~isequal(sort(unique(runs.method)),sort(["HS+";"LS+"])) || ...
        numel(unique(runs.run_key)) ~= 13200
    error('mcode:InvalidExtension046Runs', ...
        'The extension store is not the complete 13,200-run HS+/LS+ campaign.');
end
if height(reference) ~= 6600 || numel(unique(reference.run_key)) ~= 6600
    error('mcode:InvalidExtension046Reference', ...
        'The reference store does not contain 6,600 unique TTCGP runs.');
end
end

function [output,details] = outcome_table(runs)
methods = ["HS+";"LS+"];
converged = zeros(2,1); iterationLimit = zeros(2,1);
lineSearch = zeros(2,1); nonDescent = zeros(2,1); successRate = zeros(2,1);
for k = 1:2
    status = runs.status(runs.method==methods(k));
    known = ismember(status,["converged" "max_iter" ...
        "line_search_failed" "no_descent"]);
    if ~all(known)
        unknown = strjoin(cellstr(unique(status(~known))),', ');
        error('mcode:UnexpectedExtension046Status', ...
            'Unexpected terminal status for %s: %s.',methods(k),unknown);
    end
    converged(k) = sum(status=="converged");
    iterationLimit(k) = sum(status=="max_iter");
    lineSearch(k) = sum(status=="line_search_failed");
    nonDescent(k) = sum(status=="no_descent");
    successRate(k) = converged(k)/numel(status);
end
output = table(methods,converged,iterationLimit,lineSearch,nonDescent, ...
    successRate,'VariableNames',{'method','converged','iteration_limit', ...
    'line_search','non_descent','success_rate'});
[group,method,status] = findgroups(runs.method,runs.status);
count = splitapply(@numel,runs.start_id,group);
details = table(method,status,count, ...
    'VariableNames',{'method','status','runs'});
end

function [output,violationsTable] = descent_table(runs,iterations)
metadata = runs(runs.set_name=="NC10", ...
    {'run_key','method','problem','start_id'});
joined = innerjoin(iterations,metadata,'Keys','run_key');
isViolation = ~joined.descent_bound_holds;
violationsTable = joined(isViolation,{'run_key','method','problem', ...
    'start_id','k','steepest_directional_value','directional_value', ...
    'descent_gap','descent_tolerance'});
if ~isempty(violationsTable)
    violationsTable.non_descent = violationsTable.directional_value>=0;
end
methods = ["HS+";"LS+"];
directionsFormed = zeros(2,1); violations = zeros(2,1);
violationRate = zeros(2,1); nonDescentViolations = zeros(2,1);
for k = 1:2
    use = joined.method==methods(k);
    directionsFormed(k) = sum(use);
    violations(k) = sum(use & isViolation);
    violationRate(k) = violations(k)/directionsFormed(k);
    nonDescentViolations(k) = sum(use & isViolation & ...
        joined.directional_value>=0);
end
output = table(methods,directionsFormed,violations,violationRate, ...
    nonDescentViolations,'VariableNames',{'method','directions_formed', ...
    'violations','violation_rate','non_descent_violations'});
end

function output = paired_work_table(runs,reference)
methods = ["HS+";"LS+"];
pairedSuccesses = zeros(2,1); iterationRatio = zeros(2,1);
componentEvaluationRatio = zeros(2,1);
for k = 1:2
    left = sortrows(runs(runs.method==methods(k),:),{'problem','start_id'});
    right = sortrows(reference,{'problem','start_id'});
    if height(left)~=height(right) || any(left.problem~=right.problem) || ...
            any(left.start_id~=right.start_id) || ...
            any(~cellfun(@isequaln,left.x0,right.x0))
        error('mcode:UnpairedExtension046', ...
            'Extension and TTCGP task keys or starts differ for %s.',methods(k));
    end
    both = left.status=="converged" & right.status=="converged";
    pairedSuccesses(k) = sum(both);
    iterationRatio(k) = shifted_geomean( ...
        left.iterations(both),right.iterations(both));
    fRatio = shifted_geomean(left.component_F(both),right.component_F(both));
    jRatio = shifted_geomean(left.component_J(both),right.component_J(both));
    if abs(fRatio-jRatio) > 1e-14
        error('mcode:UnequalExtension046EvaluationRatios', ...
            'Objective and Jacobian evaluation ratios differ for %s.',methods(k));
    end
    componentEvaluationRatio(k) = fRatio;
end
output = table(methods,pairedSuccesses,iterationRatio, ...
    componentEvaluationRatio,'VariableNames',{'method','paired_successes', ...
    'iterations_over_TTCGP','component_F_J_over_TTCGP'});
end

function value = shifted_geomean(left,right)
ratio = (double(left)+1)./(double(right)+1);
value = exp(mean(log(ratio)));
end

function [summary,policies] = fallback_tables(runs,iterations,events)
metadata = runs(:,{'run_key','method','set_name'});
iterationRows = innerjoin(iterations,metadata,'Keys','run_key');
iterationRows = iterationRows(~isnan(iterationRows.raw_beta),:);
if isempty(events)
    eventRows = table();
else
    eventRows = innerjoin(events,metadata,'Keys','run_key');
end
methods = ["HS+";"LS+"];
scopes = ["all66";"D1-D10"];
method = strings(4,1); scope = strings(4,1); updates = zeros(4,1);
fallbackCount = zeros(4,1); fallbackPercentage = zeros(4,1);
nonfiniteResets = zeros(4,1); nonfinitePercentage = zeros(4,1);
row = 0;
for s = 1:2
    for m = 1:2
        row = row+1;
        method(row) = methods(m); scope(row) = scopes(s);
        useIterations = iterationRows.method==methods(m);
        useEvents = false(height(eventRows),1);
        if ~isempty(eventRows), useEvents = eventRows.method==methods(m); end
        if scopes(s)=="D1-D10"
            useIterations = useIterations & iterationRows.set_name=="NC10";
            if ~isempty(eventRows)
                useEvents = useEvents & eventRows.set_name=="NC10";
            end
        end
        updates(row) = sum(useIterations);
        fallbackCount(row) = sum(useEvents);
        fallbackPercentage(row) = 100*fallbackCount(row)/updates(row);
        if ~isempty(eventRows)
            nonfiniteResets(row) = sum(eventRows.nonfinite_reset(useEvents));
        end
        nonfinitePercentage(row) = 100*nonfiniteResets(row)/updates(row);
    end
end
summary = table(method,scope,updates,fallbackCount,fallbackPercentage, ...
    nonfiniteResets,nonfinitePercentage,'VariableNames',{'method','scope', ...
    'updates','fallback_count','fallback_percentage', ...
    'nonfinite_resets','nonfinite_percentage'});

policies = extension_046_fallback_policies(eventRows);
end
