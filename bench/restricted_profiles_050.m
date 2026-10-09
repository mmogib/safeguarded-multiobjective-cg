function report = restricted_profiles_050(sevenArmRatios)
%RESTRICTED_PROFILES_050 Rebase profiles over the exchange-050 method sets.

required = {'slice','run_key','method','problem','start_id', ...
    'metric','ratio','success'};
if ~all(ismember(required,sevenArmRatios.Properties.VariableNames))
    error('mcode:InvalidRestrictedProfileInput', ...
        'The input must be the full-resolution seven-arm ratio table.');
end

sets = profile_sets();
metrics = ["iterations";"component_F_J"];
queryTau = [1;1.05;1.1;1.25;1.5;2;4];
source = sevenArmRatios(sevenArmRatios.slice=="all66",:);
ratios = table();
values = table();
limits = table();
curves = table();
crossings = table();

for setIndex = 1:height(sets)
    methods = sets.methods{setIndex};
    for metricIndex = 1:numel(metrics)
        metric = metrics(metricIndex);
        block = source(source.metric==metric & ...
            ismember(source.method,methods),:);
        instances = validate_paired_block(block,methods, ...
            sets.comparison(setIndex),metric);

        [taskGroup,~,~] = findgroups(block.problem,block.start_id);
        bestScaled = splitapply(@best_success_ratio, ...
            block.ratio,block.success,taskGroup);
        success = logical(block.success) & isfinite(bestScaled(taskGroup));
        rebased = NaN(height(block),1);
        rebased(success) = block.ratio(success)./bestScaled(taskGroup(success));
        largestFinite = max(rebased(success));
        rM = 2*max(4,largestFinite);
        rebased(~success) = rM;

        comparison = repmat(sets.comparison(setIndex),height(block),1);
        ratios = [ratios;table(comparison,block.run_key,block.method, ...
            block.problem,block.start_id,repmat(metric,height(block),1), ...
            rebased,success,'VariableNames',{'comparison','run_key', ...
            'method','problem','start_id','metric','ratio','success'})]; %#ok<AGROW>
        limits = [limits;table(sets.comparison(setIndex),metric, ...
            instances,largestFinite,rM,'VariableNames',{'comparison', ...
            'metric','instances','largest_finite_ratio','r_M'})]; %#ok<AGROW>

        for methodIndex = 1:numel(methods)
            use = block.method==methods(methodIndex);
            methodRatio = rebased(use);
            methodSuccess = success(use);
            count = arrayfun(@(tau) sum(methodRatio<=tau),queryTau);
            rho = count/instances;
            values = [values;table( ...
                repmat(sets.comparison(setIndex),numel(queryTau),1), ...
                repmat(metric,numel(queryTau),1), ...
                repmat(methods(methodIndex),numel(queryTau),1), ...
                queryTau,count,repmat(instances,numel(queryTau),1),rho, ...
                false(numel(queryTau),1),'VariableNames',{'comparison', ...
                'metric','method','tau','count','instances','rho', ...
                'is_plateau'})]; %#ok<AGROW>
            plateauCount = sum(methodSuccess);
            values = [values;table(sets.comparison(setIndex),metric, ...
                methods(methodIndex),NaN,plateauCount,instances, ...
                plateauCount/instances,true,'VariableNames', ...
                {'comparison','metric','method','tau','count', ...
                'instances','rho','is_plateau'})]; %#ok<AGROW>

            [tau,rho] = exact_curve(methodRatio,methodSuccess, ...
                instances,largestFinite);
            curves = [curves;table( ...
                repmat(sets.comparison(setIndex),numel(tau),1), ...
                repmat(metric,numel(tau),1), ...
                repmat(methods(methodIndex),numel(tau),1),tau,rho, ...
                'VariableNames',{'comparison','metric','method', ...
                'tau','rho'})]; %#ok<AGROW>
        end

        if startsWith(sets.comparison(setIndex),"pair_")
            crossings = [crossings;crossing_row(sets.comparison(setIndex), ...
                metric,methods,rebased,success,block.method,instances, ...
                largestFinite)]; %#ok<AGROW>
        end
    end
end

report = struct('sets',sets,'ratios',ratios,'values',values, ...
    'limits',limits,'curves',curves,'crossings',crossings);
end

function sets = profile_sets()
comparison = ["pair_PRP";"pair_HS";"pair_LS";"safeguarded"];
file_stem = ["profile_pair_PRP_all66";"profile_pair_HS_all66"; ...
    "profile_pair_LS_all66";"profile_safeguarded_all66"];
methods = { ...
    ["SVPRP+";"VPRP+"]; ...
    ["SVHS+";"VHS+"]; ...
    ["SVLS+";"VLS+"]; ...
    ["SVPRP+";"SVHS+";"SVLS+";"VSD"]};
sets = table(comparison,file_stem,methods);
end

function instances = validate_paired_block(block,methods,comparison,metric)
if isempty(block)
    error('mcode:IncompleteRestrictedProfiles', ...
        'No rows found for %s/%s.',comparison,metric);
end
referenceTasks = strings(0,1);
for methodIndex = 1:numel(methods)
    part = block(block.method==methods(methodIndex),:);
    tasks = sort(part.problem+"__"+compose('%06d',part.start_id));
    if methodIndex==1
        referenceTasks = tasks;
    elseif ~isequal(tasks,referenceTasks)
        error('mcode:UnpairedRestrictedProfiles', ...
            '%s does not use one common task set.',comparison);
    end
end
instances = numel(referenceTasks);
if instances==0 || height(block)~=instances*numel(methods)
    error('mcode:UnpairedRestrictedProfiles', ...
        '%s contains duplicate or missing task rows.',comparison);
end
end

function value = best_success_ratio(ratio,success)
successful = ratio(logical(success));
if isempty(successful), value = Inf; else, value = min(successful); end
end

function [tau,rho] = exact_curve(ratio,success,instances,xMax)
tau = unique(ratio(success));
rho = arrayfun(@(value) sum(ratio<=value)/instances,tau);
if isempty(tau) || tau(1)>1
    tau = [1;tau];
    rho = [0;rho];
end
if tau(end)<xMax
    tau(end+1,1) = xMax;
    rho(end+1,1) = mean(success);
end
end

function row = crossing_row(comparison,metric,methods,ratio,success, ...
        methodColumn,instances,xMax)
safeUse = methodColumn==methods(1);
plainUse = methodColumn==methods(2);
safeRatio = ratio(safeUse);
plainRatio = ratio(plainUse);
safeSuccess = success(safeUse);
plainSuccess = success(plainUse);
candidate = unique([1;safeRatio(safeSuccess);plainRatio(plainSuccess)]);
candidate = candidate(candidate<=xMax);
safeRho = arrayfun(@(tau) sum(safeRatio<=tau)/instances,candidate);
plainRho = arrayfun(@(tau) sum(plainRatio<=tau)/instances,candidate);
index = find(safeRho>=plainRho,1,'first');
if isempty(index)
    crosses = false;
    tau = NaN;
    safeAtCrossing = NaN;
    plainAtCrossing = NaN;
else
    crosses = true;
    tau = candidate(index);
    safeAtCrossing = safeRho(index);
    plainAtCrossing = plainRho(index);
end
row = table(comparison,metric,methods(1),methods(2),crosses,tau, ...
    safeAtCrossing,plainAtCrossing,'VariableNames',{'comparison', ...
    'metric','safeguarded_method','partner_method','crosses','tau', ...
    'safeguarded_rho','partner_rho'});
end
