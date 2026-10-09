function certificate = tier3_levelset_certificate(prob,x0)
%TIER3_LEVELSET_CERTIFICATE Explicit bound for one common lower level set.
% Every kernel term is nonnegative. Thus F_i(x)<=F_i(x0)=c_i bounds each
% argument in objective i by r_i=max(1,sqrt(c_i)). The problem-specific
% formulas below reconstruct componentwise bounds on x from those argument
% bounds. Consequently L(x0) is contained in the returned compact box.

if ~strcmp(prob.set_name,'NC10')
    error('mcode:InvalidCertificateProblem', ...
        'Tier-3 level-set certificates are NC10-only.');
end
c = prob.value(x0);
if numel(c) ~= 2 || any(~isfinite(c)) || any(c < -64*eps(max(1,max(abs(c)))))
    error('mcode:InvalidLevelValue', ...
        'The start must have two finite nonnegative objective values.');
end
c = max(c,0);
r = oscillatory_sublevel_radius(c);

switch prob.local_index
    case 1
        bound = [r(1);1+r(1)];
        proofId = 'P1_F1_coordinate_reconstruction';
    case 2
        bound = [1+r(1);1+2*r(1)];
        proofId = 'P2_F1_invertible_affine_pair';
    case 3
        bound = [1+r(1);2+3*r(1)];
        proofId = 'P3_F1_invertible_affine_pair';
    case 4
        bound = [2+r(1);1+r(1)];
        proofId = 'P4_F1_coordinate_reconstruction';
    case 5
        bound = [1+r(1);2+r(2)];
        proofId = 'P5_cross_objective_affine_terms';
    case 6
        bound = sqrt(1+r(1))*[1;1];
        proofId = 'P6_F1_radial_argument';
    case 7
        bound = [1+(r(1)+2*r(2))/7; ...
                 1+(3*r(1)+r(2))/7];
        proofId = 'P7_joint_invertible_affine_pair';
    case 8
        bound = [1+r(1);1+2*r(1)];
        proofId = 'P8_F1_invertible_affine_pair';
    case 9
        bound = [1+r(1);(1+r(1))^2+r(1)];
        proofId = 'P9_F1_parabola_plus_coordinate';
    case 10
        bound = [r(1);2*r(1)];
        proofId = 'P10_F1_invertible_affine_pair';
    otherwise
        error('mcode:InvalidNC10Problem','NC10 problem index must lie in 1:10.');
end

certificate = struct('problem',prob.paper_label,'start',x0, ...
    'objective_upper',c,'argument_radius',r,'abs_bound',bound, ...
    'proof_id',proofId,'passed',all(isfinite(bound)) && all(bound > 0));
end
