function [starts,metadata] = nonlipschitz_starts(prob)
%NONLIPSCHITZ_STARTS Deterministic starts from the frozen E1/E2 design.

if strcmp(prob.set_name,'NL10')
    oldState = rng;
    cleanup = onCleanup(@() rng(oldState)); %#ok<NASGU>
    rng(prob.start_seed,'twister');
    starts = prob.lower_bound+(prob.upper_bound-prob.lower_bound).*rand(prob.n,100);
    metadata = struct('seed',prob.start_seed,'u',[],'rho',[],'sigma',[]);
    return
end

uValues = linspace(-2,2,10);
rhoValues = 10.^(-(1:5));
sigmaValues = [-1,1];
starts = zeros(prob.n,100);
uRecord = zeros(1,100);
rhoRecord = zeros(1,100);
sigmaRecord = zeros(1,100);
column = 0;

unitVectors = [];
if prob.local_index == 5
    oldState = rng;
    cleanup = onCleanup(@() rng(oldState)); %#ok<NASGU>
    rng(20260928,'twister');
    unitVectors = randn(8,10);
    unitVectors = unitVectors./vecnorm(unitVectors);
end

for r = 1:10
    for rho = rhoValues
        for sigma = sigmaValues
            column = column+1;
            starts(:,column) = one_start(prob.local_index,uValues(r),rho,sigma, ...
                unitVectors,r);
            uRecord(column) = uValues(r);
            rhoRecord(column) = rho;
            sigmaRecord(column) = sigma;
        end
    end
end
metadata = struct('seed',20260928,'u',uRecord,'rho',rhoRecord, ...
    'sigma',sigmaRecord);
end

function x = one_start(d,u,rho,sigma,unitVectors,r)
switch d
    case {1,4}
        x = [u;sigma*rho];
    case 2
        gamma = [u;u^2];
        normal = [-2*u;1]/sqrt(1+4*u^2);
        x = gamma+sigma*rho*normal;
    case 3
        a = fzero(@(v) v+0.5*sin(v)-u,u);
        gamma = [a;0.5*sin(a)];
        normal = [-0.5*cos(a);1];
        normal = normal/norm(normal);
        x = gamma+sigma*rho*normal;
    case 5
        z = 0.5*unitVectors(:,r);
        normalNorm = sqrt(1+0.25*(z'*z));
        h = sigma*rho*normalNorm;
        x = [u;0.25*(z'*z)+h;z];
end
end
