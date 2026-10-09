function registry = tier3_problem_registry()
%TIER3_PROBLEM_REGISTRY Coercive non-C1 NC10 family.

template = struct('tier3_index',[],'paper_label','','set_name','NC10', ...
    'family','nc10','local_index',[],'m',2,'n',2,'safe_point',[], ...
    'value',[],'jacobian',[],'legacy_jacobian',[], ...
    'lower_bound',[],'upper_bound',[],'start_seed',20260928, ...
    'singular_value',[],'pareto_projection',[]);
registry = repmat(template,1,10);
lower = [-3 -2 -2 -5 -2 0 -3 -2 -3 -2; ...
         -3 -2 -2 -5 -2 0 -3 -2 -3 -2];
upper = [3 2 2 5 2 6 3 5 3 6; ...
         3 2 2 5 2 6 3 5 3 6];

for d = 1:10
    fun = @(x,request) probs.nc10(x,request,d);
    prob = template;
    prob.tier3_index = d;
    prob.paper_label = sprintf('NC10-%d',d);
    prob.local_index = d;
    prob.value = @(x) fun(x,'value');
    prob.jacobian = @(x) fun(x,'jacobian');
    prob.legacy_jacobian = prob.jacobian;
    prob.lower_bound = lower(:,d);
    prob.upper_bound = upper(:,d);
    prob.safe_point = (lower(:,d)+upper(:,d))/2+[0.13;-0.17];
    prob.singular_value = @(x) NaN;
    prob.pareto_projection = @(x) x;
    registry(d) = prob;
end
end

