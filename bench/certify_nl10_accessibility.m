function result = certify_nl10_accessibility(prob,x0)
%CERTIFY_NL10_ACCESSIBILITY Search for a concrete regular level-set witness.
% A failed floating search is reported as unresolved, never inaccessible.

if ~strcmp(prob.set_name,'NL10')
    error('mcode:InvalidCertificateProblem','Certificate search is NL10-only.');
end
args = nonlipschitz_arguments(prob);
bestUpper = Inf;
bestDetail = [];
evaluations = 0;

for j = 1:numel(args)
    arg = args(j);
    for c = 1:numel(arg.witness_components)
        componentInfo = arg.witness_components{c};
        bounds = componentInfo.bounds;
        grid = linspace(bounds(1),bounds(2),161);
        values = zeros(size(grid));
        for q = 1:numel(grid)
            values(q) = candidate_value(prob,x0,componentInfo.map,grid(q));
        end
        evaluations = evaluations+numel(grid);
        [~,order] = sort(values);
        candidateParameters = grid(order(1:min(5,numel(order))));
        for rank = 1:min(5,numel(order))
            index = order(rank);
            left = grid(max(1,index-1));
            right = grid(min(numel(grid),index+1));
            if left < right
                parameter = fminbnd(@(u) candidate_value( ...
                    prob,x0,componentInfo.map,u),left,right);
                candidateParameters(end+1) = parameter; %#ok<AGROW>
                evaluations = evaluations+1;
            end
        end
        for parameter = candidateParameters
            witness = componentInfo.map(parameter);
            [certified,detail] = is_accessible_witness(prob,arg,x0,witness);
            if detail.max_difference < bestUpper
                bestUpper = detail.max_difference;
                bestDetail = detail;
            end
            if certified
                result = finish('certified_accessible',detail.max_difference, ...
                    detail,evaluations);
                return
            end
        end
    end
end

result = finish('unresolved',bestUpper,bestDetail,evaluations);
end

function value = candidate_value(prob,x0,map,parameter)
value = max(prob.value(map(parameter))-prob.value(x0));
end

function result = finish(status,bestUpper,detail,evaluations)
if isempty(detail)
    witness = [];
    argumentId = '';
    differences = [];
else
    witness = detail.witness;
    argumentId = detail.argument_id;
    differences = detail.component_differences;
end
result = struct('status',status,'best_upper_bound',bestUpper, ...
    'witness',witness,'argument_id',argumentId, ...
    'component_differences',differences,'search_evaluations',evaluations);
end
