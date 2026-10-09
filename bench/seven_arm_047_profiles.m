function output = seven_arm_047_profiles(runs,maxPoints)
%SEVEN_ARM_047_PROFILES Failure-aware Dolan--More profile data.

if nargin < 2, maxPoints = 300; end
if maxPoints < 2
    error('mcode:InvalidProfilePointLimit','At least two points are required.');
end
if any(runs.component_F~=runs.component_J)
    error('mcode:UnequalSevenArm047Evaluations', ...
        'Component F and J counts must agree on every reported run.');
end

methods = seven_arm_047_methods().display_name;
slices = profile_slices(runs);
metricNames = ["iterations";"component_F_J"];
metricColumns = ["iterations";"component_F"];
queryTau = [1;1.05;1.1;1.25;1.5;2;4];
ratios = table(); values = table(); limits = table();
curves = table(); downsampling = table();

for s = 1:height(slices)
    block = runs(slices.mask{s},:);
    if isempty(block), continue; end
    [taskGroup,~,~] = findgroups(block.problem,block.start_id);
    taskCount = numel(unique(taskGroup));
    for metricIndex = 1:numel(metricNames)
        metric = metricNames(metricIndex);
        work = double(block.(metricColumns(metricIndex)))+1;
        best = splitapply(@best_success,work,block.status,taskGroup);
        success = block.status=="converged";
        ratio = NaN(height(block),1);
        ratio(success) = work(success)./best(taskGroup(success));
        largestFinite = max(ratio(success));
        rM = 2*max(4,largestFinite);
        ratio(~success) = rM;
        limits = [limits;table(slices.name(s),metric,taskCount, ...
            largestFinite,rM,'VariableNames',{'slice','metric','instances', ...
            'largest_finite_ratio','r_M'})]; %#ok<AGROW>
        ratios = [ratios;table(repmat(slices.name(s),height(block),1), ...
            block.run_key,block.method,block.problem,block.start_id, ...
            repmat(metric,height(block),1),ratio,success, ...
            'VariableNames',{'slice','run_key','method','problem', ...
            'start_id','metric','ratio','success'})]; %#ok<AGROW>

        for m = 1:numel(methods)
            use = block.method==methods(m);
            if sum(use)~=taskCount
                error('mcode:UnpairedSevenArm047', ...
                    '%s is missing profile instances in %s.', ...
                    methods(m),slices.name(s));
            end
            methodRatio = ratio(use);
            methodSuccess = success(use);
            count = arrayfun(@(tau) sum(methodRatio<=tau),queryTau);
            rho = count/taskCount;
            values = [values;table( ...
                repmat(slices.name(s),numel(queryTau),1), ...
                repmat(metric,numel(queryTau),1), ...
                repmat(methods(m),numel(queryTau),1),queryTau,count, ...
                repmat(taskCount,numel(queryTau),1),rho, ...
                false(numel(queryTau),1),'VariableNames',{'slice','metric', ...
                'method','tau','count','instances','rho','is_plateau'})]; %#ok<AGROW>
            plateauCount = sum(methodSuccess);
            values = [values;table(slices.name(s),metric,methods(m),NaN, ...
                plateauCount,taskCount,plateauCount/taskCount,true, ...
                'VariableNames',{'slice','metric','method','tau','count', ...
                'instances','rho','is_plateau'})]; %#ok<AGROW>

            [exactTau,exactRho] = exact_curve( ...
                methodRatio,methodSuccess,taskCount,largestFinite);
            [keptTau,keptRho,maxDeviation] = ...
                reduce_curve(exactTau,exactRho,maxPoints);
            curves = [curves;table( ...
                repmat(slices.name(s),numel(keptTau),1), ...
                repmat(metric,numel(keptTau),1), ...
                repmat(methods(m),numel(keptTau),1),keptTau,keptRho, ...
                'VariableNames',{'slice','metric','method','tau','rho'})]; %#ok<AGROW>
            downsampling = [downsampling;table(slices.name(s),metric, ...
                methods(m),numel(exactTau),numel(keptTau),maxDeviation, ...
                'VariableNames',{'slice','metric','method','exact_points', ...
                'retained_points','max_vertical_deviation'})]; %#ok<AGROW>
        end
    end
end
output = struct('ratios',ratios,'values',values,'limits',limits, ...
    'curves',curves,'downsampling',downsampling);
end

function slices = profile_slices(runs)
name = ["all66";"archived41";"H1-H15";"D1-D10"];
mask = {true(height(runs),1);runs.tier==1;runs.tier==2;runs.tier==3};
slices = table(name,mask);
end

function value = best_success(values,status)
successful = values(status=="converged");
if isempty(successful), value = Inf; else, value = min(successful); end
end

function [tau,rho] = exact_curve(ratio,success,instances,largestFinite)
tau = unique(ratio(success));
rho = arrayfun(@(value) sum(ratio<=value)/instances,tau);
if isempty(tau) || tau(1)>1
    tau = [1;tau];
    rho = [0;rho];
end
if tau(end)<largestFinite
    tau(end+1,1) = largestFinite;
    rho(end+1,1) = mean(success);
end
end

function [keptTau,keptRho,maxDeviation] = reduce_curve(tau,rho,maxPoints)
if numel(tau)<=maxPoints
    keptTau = tau; keptRho = rho; maxDeviation = 0; return
end
targets = linspace(rho(1),rho(end),maxPoints)';
indices = zeros(maxPoints,1);
for k = 1:maxPoints
    indices(k) = find(rho>=targets(k),1,'first');
end
indices = unique([1;indices;numel(tau)],'stable');
if numel(indices)>maxPoints
    indices = unique(round(linspace(1,numel(tau),maxPoints)))';
end
keptTau = tau(indices);
keptRho = rho(indices);
approximation = zeros(size(rho));
for k = 1:numel(tau)
    previous = find(keptTau<=tau(k),1,'last');
    approximation(k) = keptRho(previous);
end
maxDeviation = max(abs(rho-approximation));
end
