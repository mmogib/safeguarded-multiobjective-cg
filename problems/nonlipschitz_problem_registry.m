function registry = nonlipschitz_problem_registry()
%NONLIPSCHITZ_PROBLEM_REGISTRY Separate E2 and corrected inherited families.

template = struct('nonlipschitz_index',[],'paper_label','','set_name','', ...
    'family','','local_index',[],'m',[],'n',[],'safe_point',[], ...
    'value',[],'jacobian',[],'legacy_jacobian',[], ...
    'lower_bound',[],'upper_bound',[],'start_seed',[], ...
    'singular_value',[],'pareto_projection',[]);
registry = repmat(template,1,15);

for d = 1:5
    n = 2;
    m = 2;
    if d == 5
        n = 10;
        m = 3;
    end
    fun = @(x,request) probs.e2(x,request,d);
    registry(d) = make_problem(template,d,sprintf('E2-%d',d),'E2','e2', ...
        d,m,n,fun,[],[],NaN,@(x) e2_h(x,d),@(x) e2_project(x,d));
    registry(d).safe_point = zeros(n,1);
    registry(d).safe_point(2) = 0.25;
end

lower = [-3 -2 -2 -5 -2 0 -3 -2 -3 -2; ...
         -3 -2 -2 -5 -2 0 -3 -2 -3 -2];
upper = [3 2 2 5 2 6 3 5 3 6; ...
         3 2 2 5 2 6 3 5 3 6];
for d = 1:10
    k = 5+d;
    fun = @(x,request) probs.nl10(x,request,d);
    registry(k) = make_problem(template,k,sprintf('NL10-%d',d),'NL10', ...
        'nl10',d,2,2,fun,lower(:,d),upper(:,d),20260928, ...
        @(x) NaN,@(x) x);
    registry(k).safe_point = (lower(:,d)+upper(:,d))/2+[0.13;-0.17];
end
end

function prob = make_problem(template,index,label,setName,family,localIndex, ...
    m,n,fun,lower,upper,seed,singularValue,projection)
prob = template;
prob.nonlipschitz_index = index;
prob.paper_label = label;
prob.set_name = setName;
prob.family = family;
prob.local_index = localIndex;
prob.m = m;
prob.n = n;
prob.value = @(x) fun(x,'value');
prob.jacobian = @(x) fun(x,'jacobian');
prob.legacy_jacobian = prob.jacobian;
prob.lower_bound = lower;
prob.upper_bound = upper;
prob.start_seed = seed;
prob.singular_value = singularValue;
prob.pareto_projection = projection;
end

function h = e2_h(x,d)
switch d
    case {1,4}
        h = x(2);
    case 2
        h = x(2)-x(1)^2;
    case 3
        h = x(2)-0.5*sin(x(1));
    case 5
        h = x(2)-0.25*sum(x(3:10).^2);
end
end

function projected = e2_project(x,d)
switch d
    case {1,4}
        s = min(max(x(1),-1),1);
        projected = [s;0];
    case 2
        s = min(max(x(1),-1),1);
        projected = [s;s^2];
    case 3
        q = min(max(x(1)+x(2),-1),1);
        u = fzero(@(v) v+0.5*sin(v)-q,q);
        projected = [u;0.5*sin(u)];
    case 5
        s = min(max(x(1),-1),1);
        projected = [s;zeros(9,1)];
end
end
