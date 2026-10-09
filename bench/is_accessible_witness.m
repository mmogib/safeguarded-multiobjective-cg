function [certified,detail] = is_accessible_witness(prob,arg,x0,witness)
%IS_ACCESSIBLE_WITNESS Conservatively verify a regular singular witness.

t = arg.value(witness);
gradientNorm = norm(arg.gradient(witness));
differences = prob.value(witness)-prob.value(x0);
scale = max([1;abs(prob.value(x0));abs(prob.value(witness))]);
valueTolerance = 128*eps(scale);
argumentTolerance = 128*eps(max(1,norm(witness,inf)))* ...
    max(1,gradientNorm);

exactRegular = t == 0 && gradientNorm > 0;
approximatelyRegular = abs(t) <= argumentTolerance && gradientNorm > argumentTolerance;
exactDominated = all(differences <= 0);
strictDominated = max(differences) <= -valueTolerance;

certified = (exactRegular && exactDominated) || ...
    (approximatelyRegular && strictDominated);
if abs(t) <= argumentTolerance && gradientNorm <= argumentTolerance
    status = 'degenerate_zero';
elseif certified
    status = 'certified_accessible';
else
    status = 'unresolved';
end
detail = struct('status',status,'argument_value',t, ...
    'gradient_norm',gradientNorm,'component_differences',differences, ...
    'max_difference',max(differences),'value_tolerance',valueTolerance, ...
    'argument_tolerance',argumentTolerance,'witness',witness, ...
    'argument_id',arg.argument_id);
end
