function result = solve_mocg(prob, x0, opts)
%SOLVE_MOCG Run one multiobjective CG trial under an explicit policy set.

validate_options(opts);
trace = initialize_trace(opts,x0);
evaluator = Evaluator(prob, x0, opts.derivative_mode);
evaluator.value(x0);
J = evaluator.jacobian(x0);
steepest = steepest_dir(J, opts.qp_mode);

diagnostics = initial_diagnostics();
diagnostics.qp_time = steepest.qp_time;
legacyCounts = struct('ItN', 1, 'FeN', 1+prob.m, ...
    'GeN', 1+prob.m, 'NV', 2);
if ~strcmp(steepest.status, 'ok')
    diagnostics.qp_failures = 1;
    result = finish_result(steepest.status, x0, 1, evaluator, ...
        diagnostics, legacyCounts, prob, trace,steepest.theta, ...
        norm(steepest.v),steepest.t);
    return
end

x = x0;
v = steepest.v;
t = steepest.t;
theta = steepest.theta;
initialT = t;
direction = v;
diagnostics = update_direction_growth(diagnostics,direction,v);
iteration = 1;
trace = append_direction_trace(trace,iteration,theta,v,t,t, ...
    empty_direction_update(),diagnostics);
alpha = min(max(1/norm(direction), 1), opts.alpha_max);
status = '';

while true
    if theta >= -opts.theta_tol
        status = 'converged';
        break
    end
    if iteration >= opts.max_iter
        status = 'max_iter';
        break
    end
    if any(~isfinite([x; direction; theta]))
        status = 'nonfinite';
        diagnostics.nonfinite_events = diagnostics.nonfinite_events+1;
        break
    end

    lineOpts = struct('mode', opts.line_search_mode, 'rho', opts.rho, ...
        'sigma', opts.sigma, 'alpha_min', opts.alpha_min, ...
        'alpha_max', opts.alpha_max, ...
        'max_trials', opts.line_search_max_trials, ...
        'record_trials', trace.enabled);
    search = line_search(evaluator, x, direction, alpha, lineOpts);
    trace = append_line_trials(trace,search,iteration);
    trace = update_direction_search_trace(trace,iteration,search);
    diagnostics.line_search_trials = diagnostics.line_search_trials+search.trials;
    diagnostics.line_search_statuses{end+1} = search.status;
    legacyCounts.FeN = legacyCounts.FeN+search.legacy_F;
    legacyCounts.GeN = legacyCounts.GeN+search.legacy_J;
    if strcmp(opts.line_search_mode, 'validated_strong') && ~strcmp(search.status, 'ok')
        diagnostics.line_search_failure = struct('status',search.status, ...
            'bracket',search.bracket,'trials',search.trials,'sites',search.sites);
        status = 'line_search_failed';
        break
    end
    if ~isfinite(search.alpha)
        status = 'line_search_failed';
        break
    end

    xNext = x+search.alpha*direction;
    if trace.points_enabled
        trace.accepted_points(:,end+1) = xNext;
    end
    evaluator.value(xNext);
    legacyCounts.FeN = legacyCounts.FeN+prob.m;
    evaluator.begin_iteration(xNext, x);
    JNext = evaluator.jacobian(xNext);
    nextSteepest = steepest_dir(JNext, opts.qp_mode);
    diagnostics.qp_solves = diagnostics.qp_solves+1;
    diagnostics.qp_time = diagnostics.qp_time+nextSteepest.qp_time;
    legacyCounts.GeN = legacyCounts.GeN+prob.m;
    legacyCounts.NV = legacyCounts.NV+1;
    if ~strcmp(nextSteepest.status, 'ok')
        status = nextSteepest.status;
        diagnostics.qp_failures = diagnostics.qp_failures+1;
        break
    end

    if nextSteepest.theta >= -opts.theta_tol
        x = xNext;
        v = nextSteepest.v;
        t = nextSteepest.t;
        theta = nextSteepest.theta;
        J = JNext;
        iteration = iteration+1;
        legacyCounts.ItN = iteration;
        trace = append_steepest_terminal_trace(trace,iteration,theta,v,t);
        status = 'converged';
        break
    end

    vNext = nextSteepest.v;
    f_x_dprev = max_directional(J, direction, opts.derivative_mode);
    directionUpdate = empty_direction_update();
    if strcmp(opts.direction, 'steepest')
        directionNext = vNext;
    else
        f_x_vnext = max_directional(J, vNext, opts.derivative_mode);
        f_xnext_dprev = max_directional(JNext, direction, opts.derivative_mode);
        pValue = -nextSteepest.t+f_x_vnext;
        gradientDifference = JNext-J;
        gamma = gradient_difference_measure(gradientDifference, opts.derivative_mode);
        betaQ = struct('p', pValue, 'f_x_v', t, ...
            'f_xnext_d', f_xnext_dprev, 'f_x_d', f_x_dprev, ...
            'gamma', gamma);
        if strcmp(opts.mode, 'legacy') && strcmp(opts.beta_formula, 'PRP')
            if strcmp(opts.direction, 'threeterm')
                betaQ.f_x_v = initialT;
            else
                betaQ.f_x_v = max_directional(J, v, opts.derivative_mode);
            end
        elseif strcmp(opts.mode, 'legacy_etasen') && strcmp(opts.beta_formula, 'PRP')
            betaQ.f_x_v = initialT;
        end
        [rawBeta, betaInfo] = beta_formula(opts.beta_formula, betaQ, ...
            opts.direction, opts.derivative_mode, value_or_default(opts.mu, 1));
        [beta, safeguardInfo] = beta_safeguard(rawBeta, ...
            opts.beta_safeguard, opts.eta_bar);
        diagnostics.raw_beta(end+1) = rawBeta;
        directionUpdate.raw_beta = rawBeta;
        directionUpdate.beta_denominator_fallback = betaInfo.used_fallback;
        diagnostics.truncated_beta(end+1) = max(rawBeta, 0);
        diagnostics.clipped_beta(end+1) = beta;
        diagnostics.beta_denominator_fallbacks = ...
            diagnostics.beta_denominator_fallbacks+betaInfo.used_fallback;
        diagnostics.beta_nonfinite_resets = diagnostics.beta_nonfinite_resets+ ...
            betaInfo.nonfinite_reset;
        if betaInfo.used_fallback
            diagnostics.beta_fallback_details(end+1) = struct( ...
                'iteration',iteration+1,'denominator',betaInfo.denominator, ...
                'numerator',betaQ.p,'zero_tolerance',betaInfo.zero_tolerance, ...
                'policy',betaInfo.fallback_policy, ...
                'raw_before_reset',betaInfo.raw_before_reset, ...
                'nonfinite_reset',betaInfo.nonfinite_reset);
        end
        diagnostics.hs_beta_fallbacks = diagnostics.hs_beta_fallbacks+ ...
            (strcmp(opts.beta_formula,'HS') && betaInfo.used_fallback);
        if strcmp(opts.beta_formula,'HS') && betaInfo.used_fallback
            diagnostics.hs_beta_fallback_details(end+1) = struct( ...
                'iteration',iteration+1,'denominator',betaInfo.denominator, ...
                'numerator',betaQ.p,'zero_tolerance',betaInfo.zero_tolerance, ...
                'policy',betaInfo.fallback_policy);
        end
        diagnostics.beta_truncations = diagnostics.beta_truncations+safeguardInfo.truncated;
        diagnostics.beta_clips = diagnostics.beta_clips+safeguardInfo.clipped;

        if strcmp(opts.direction, 'threeterm')
            f_xnext_vprev = max_directional(JNext, v, opts.derivative_mode);
            f_xnext_vnext = max_directional(JNext, vNext, opts.derivative_mode);
            lambdaQ = struct('f_xnext_dprev', f_xnext_dprev, ...
                'f_xnext_vprev', f_xnext_vprev, ...
                'f_xnext_v', f_xnext_vnext, 'f_x_v', t, ...
                'f_x0_v0', initialT);
            [lambda, lambdaInfo] = lambda_parameter(lambdaQ, opts.lambda_mode);
            directionUpdate.raw_lambda = lambda;
            directionUpdate.lambda_denominator_fallback = lambdaInfo.used_fallback;
            diagnostics.lambda_values(end+1) = lambda;
            diagnostics.lambda_positive = diagnostics.lambda_positive+(lambda > 0);
            diagnostics.lambda_denominator_fallbacks = ...
                diagnostics.lambda_denominator_fallbacks+lambdaInfo.used_fallback;
            if strcmp(opts.lambda_mode, 'paper_r2')
                [directionNext, directionInfo] = revised_direction( ...
                    direction, vNext, lambda, beta);
                diagnostics.p_norm_values(end+1) = directionInfo.p_norm;
                diagnostics.alignment_values(end+1) = directionInfo.alignment;
                directionUpdate.p_norm = directionInfo.p_norm;
                directionUpdate.alignment = directionInfo.alignment;
                diagnostics.alignment_undefined = diagnostics.alignment_undefined+ ...
                    directionInfo.alignment_undefined;
            elseif lambda > 0
                pDirection = direction+lambda*v;
                normalizedP = pDirection/max(1, norm(pDirection));
                directionNext = vNext+beta*norm(vNext)*normalizedP;
            else
                directionNext = vNext;
            end
        elseif strcmp(opts.direction,'lindu')
            f_xnext_vnext = max_directional(JNext,vNext,opts.derivative_mode);
            [directionNext,linduInfo] = lindu_direction(direction,vNext,beta, ...
                f_xnext_dprev,f_xnext_vnext);
            diagnostics.lindu_correction_values(end+1) = linduInfo.correction;
            diagnostics.p_norm_values(end+1) = linduInfo.bracket_norm;
            directionUpdate.p_norm = linduInfo.bracket_norm;
        else
            directionNext = vNext+beta*direction;
        end
    end

    f_xnext_dnext = max_directional(JNext, directionNext, opts.derivative_mode);
    diagnostics = update_direction_growth(diagnostics,directionNext,vNext);
    trace = append_direction_trace(trace,iteration+1,nextSteepest.theta, ...
        vNext,nextSteepest.t,f_xnext_dnext,directionUpdate,diagnostics);
    if f_xnext_dnext >= 0
        diagnostics.descent_violations = diagnostics.descent_violations+1;
    end
    if strcmp(opts.mode, 'paper_r2') && strcmp(opts.direction, 'threeterm')
        invariantTolerance = 1e-10*max([1, abs(nextSteepest.t), abs(f_xnext_dnext)]);
        assert(f_xnext_dnext <= nextSteepest.t+invariantTolerance, ...
            'mcode:RevisedDescentInvariant', ...
            ['paper_r2 violated f(x_k,d_k) <= f(x_k,v_k)+tol: ' ...
             'f_d=%g, f_v=%g, tol=%g.'], ...
            f_xnext_dnext, nextSteepest.t, invariantTolerance);
    elseif strcmp(opts.mode, 'paper_r2') && ...
            ismember(opts.direction, {'twoterm','lindu'}) && f_xnext_dnext >= 0
        diagnostics.no_descent_event = struct( ...
            'iteration', iteration+1, ...
            'directional_value', f_xnext_dnext, ...
            'steepest_directional_value', nextSteepest.t, ...
            'steepest_norm_squared', norm(vNext)^2);
        x = xNext;
        v = vNext;
        t = nextSteepest.t;
        theta = nextSteepest.theta;
        direction = directionNext;
        J = JNext;
        iteration = iteration+1;
        legacyCounts.ItN = iteration;
        status = 'no_descent';
        break
    elseif strcmp(opts.mode, 'paper')
        invariantTolerance = 1e-10*max([1, abs(nextSteepest.t), abs(f_xnext_dnext)]);
        if strcmp(opts.direction, 'threeterm') && ...
                f_xnext_dnext > nextSteepest.t+invariantTolerance
            status = 'no_descent';
            break
        elseif strcmp(opts.direction, 'twoterm') && f_xnext_dnext >= 0
            status = 'no_descent';
            break
        end
    end

    if f_xnext_dnext ~= 0
        alpha = search.alpha*f_x_dprev/f_xnext_dnext;
    else
        alpha = 1;
    end
    alpha = min(max(alpha, 0.02), 100);
    x = xNext;
    v = vNext;
    t = nextSteepest.t;
    theta = nextSteepest.theta;
    direction = directionNext;
    J = JNext;
    iteration = iteration+1;
    legacyCounts.ItN = iteration;
end

result = finish_result(status, x, iteration, evaluator, ...
    diagnostics, legacyCounts, prob, trace,theta,norm(v),t);
end

function validate_options(opts)
required = {'method','mode','direction','beta_formula','beta_safeguard', ...
    'eta_bar','lambda_mode','line_search_mode','derivative_mode','qp_mode', ...
    'rho','sigma','theta_tol','max_iter','mu','alpha_min','alpha_max', ...
    'line_search_max_trials'};
for k = 1:numel(required)
    if ~isfield(opts, required{k})
        error('mcode:MissingOption', 'Missing option %s.', required{k});
    end
end
if ~(isnumeric(opts.rho) && isscalar(opts.rho) && isfinite(opts.rho) && ...
        isnumeric(opts.sigma) && isscalar(opts.sigma) && isfinite(opts.sigma) && ...
        0 < opts.rho && opts.rho < opts.sigma && opts.sigma < 1)
    error('mcode:InvalidWolfeParameters', ...
        'Line-search parameters must satisfy 0 < rho < sigma < 1.');
end
if ~(isnumeric(opts.alpha_min) && isscalar(opts.alpha_min) && ...
        isfinite(opts.alpha_min) && opts.alpha_min > 0 && ...
        isnumeric(opts.alpha_max) && isscalar(opts.alpha_max) && ...
        isfinite(opts.alpha_max) && opts.alpha_min <= opts.alpha_max)
    error('mcode:InvalidStepBounds', ...
        'Step bounds must satisfy 0 < alpha_min <= alpha_max < Inf.');
end
if ~(isnumeric(opts.line_search_max_trials) && ...
        isscalar(opts.line_search_max_trials) && ...
        isfinite(opts.line_search_max_trials) && ...
        opts.line_search_max_trials >= 1 && ...
        opts.line_search_max_trials == floor(opts.line_search_max_trials))
    error('mcode:InvalidLineSearchBudget', ...
        'line_search_max_trials must be a positive integer.');
end
if strcmp(opts.beta_safeguard, 'nonneg_capped')
    if isempty(opts.eta_bar)
        error('mcode:InvalidEtaBar', 'Capped beta requires eta_bar.');
    end
elseif ~isempty(opts.eta_bar)
    error('mcode:UnexpectedEtaBar', ...
        'eta_bar is accepted only for a capped beta safeguard.');
end
if strcmp(opts.beta_formula, 'AVHZ')
    if isempty(opts.mu)
        error('mcode:MissingMu', 'AVHZ requires mu.');
    end
elseif ~isempty(opts.mu)
    error('mcode:UnexpectedMu', 'mu is accepted only for AVHZ.');
end
end

function diagnostics = initial_diagnostics()
diagnostics = struct('lambda_values', [], 'lambda_positive', 0, ...
    'lambda_denominator_fallbacks', 0, 'p_norm_values', [], ...
    'alignment_values', [], 'alignment_undefined', 0, ...
    'lindu_correction_values', [], 'raw_beta', [], ...
    'truncated_beta', [], 'clipped_beta', [], ...
    'beta_denominator_fallbacks', 0, 'hs_beta_fallbacks', 0, ...
    'beta_nonfinite_resets', 0, ...
    'beta_fallback_details', struct('iteration',{},'denominator',{}, ...
    'numerator',{},'zero_tolerance',{},'policy',{}, ...
    'raw_before_reset',{},'nonfinite_reset',{}), ...
    'hs_beta_fallback_details', struct('iteration',{},'denominator',{}, ...
    'numerator',{},'zero_tolerance',{},'policy',{}), ...
    'beta_truncations', 0, ...
    'beta_clips', 0, 'descent_violations', 0, ...
    'no_descent_event', struct('iteration',{},'directional_value',{}, ...
        'steepest_directional_value',{},'steepest_norm_squared',{}), ...
    'line_search_trials', 0, 'line_search_statuses', {{}}, ...
    'line_search_failure', [], ...
    'qp_failures', 0, 'qp_solves', 1, 'nonfinite_events', 0, 'qp_time', 0, ...
    'correction_ratio_values',[],'direction_growth_values',[], ...
    'direction_angle_values',[],'max_direction_norm',0, ...
    'max_direction_over_v_norm',0);
end

function result = finish_result(status, x, iteration, evaluator, ...
    diagnostics, legacyCounts, prob, trace,theta,vNorm,steepestDirectional)
result = struct('status', status, 'x', x, 'F', evaluator.unscaled_value(x), ...
    'iterations', iteration, 'counts', evaluator.counts(), ...
    'legacy_counts', legacyCounts, 'diagnostics', diagnostics, ...
    'problem', prob.paper_label, 'trace', trace,'theta',theta, ...
    'v_norm',vNorm,'steepest_directional_value',steepestDirectional);
end

function diagnostics = update_direction_growth(diagnostics,direction,v)
directionNorm = norm(direction);
vNorm = norm(v);
if ~isfinite(directionNorm)
    directionNorm = Inf;
end
if vNorm == 0
    ratio = NaN;
elseif ~isfinite(vNorm)
    ratio = Inf;
else
    ratio = directionNorm/vNorm;
end
if vNorm == 0 || ~isfinite(vNorm)
    correctionRatio = NaN;
    angle = NaN;
else
    correctionRatio = norm(direction-v)/vNorm;
    if directionNorm == 0 || ~isfinite(directionNorm)
        angle = NaN;
    else
        cosine = dot(direction,v)/(directionNorm*vNorm);
        cosine = min(max(cosine,-1),1);
        angle = acosd(cosine);
    end
end
diagnostics.correction_ratio_values(end+1) = correctionRatio;
diagnostics.direction_growth_values(end+1) = ratio;
diagnostics.direction_angle_values(end+1) = angle;
diagnostics.max_direction_norm = max(diagnostics.max_direction_norm,directionNorm);
if ~isnan(ratio)
    diagnostics.max_direction_over_v_norm = max( ...
        diagnostics.max_direction_over_v_norm,ratio);
end
end

function trace = initialize_trace(opts,x0)
enabled = isfield(opts,'trace_enabled') && opts.trace_enabled;
pointsEnabled = enabled && (~isfield(opts,'trace_points_enabled') || ...
    opts.trace_points_enabled);
emptyTrials = struct('iteration',{},'trial',{},'point',{},'alpha',{}, ...
    'accepted',{},'q',{},'g',{},'phi',{});
emptyIterations = direction_trace_template();
emptyIterations = emptyIterations([]);
trace = struct('enabled',enabled,'accepted_points',[], ...
    'points_enabled',pointsEnabled,'line_trials',emptyTrials, ...
    'iterations',emptyIterations);
if pointsEnabled
    trace.accepted_points = x0;
end
end

function update = empty_direction_update()
update = struct('raw_beta',NaN,'raw_lambda',NaN, ...
    'beta_denominator_fallback',false, ...
    'lambda_denominator_fallback',false,'p_norm',NaN,'alignment',NaN);
end

function template = direction_trace_template()
template = struct('k',NaN,'accepted_step',NaN,'theta',NaN,'v_norm',NaN, ...
    'steepest_directional_value',NaN,'raw_beta',NaN,'raw_lambda',NaN, ...
    'beta_denominator_fallback',false, ...
    'lambda_denominator_fallback',false,'p_norm',NaN,'alignment',NaN, ...
    'correction_ratio',NaN,'direction_growth',NaN,'direction_angle',NaN, ...
    'line_search_status','','line_search_trials',0, ...
    'directional_value',NaN,'descent_gap',NaN,'descent_tolerance',NaN, ...
    'descent_bound_holds',false);
end

function trace = append_direction_trace(trace,k,theta,v,steepestDirectional, ...
    directionalValue,update,diagnostics)
if ~trace.enabled, return; end
tolerance = 1e-10*max([1,abs(steepestDirectional),abs(directionalValue)]);
record = direction_trace_template();
record.k = k;
record.theta = theta;
record.v_norm = norm(v);
record.steepest_directional_value = steepestDirectional;
record.raw_beta = update.raw_beta;
record.raw_lambda = update.raw_lambda;
record.beta_denominator_fallback = update.beta_denominator_fallback;
record.lambda_denominator_fallback = update.lambda_denominator_fallback;
record.p_norm = update.p_norm;
record.alignment = update.alignment;
record.correction_ratio = diagnostics.correction_ratio_values(end);
record.direction_growth = diagnostics.direction_growth_values(end);
record.direction_angle = diagnostics.direction_angle_values(end);
record.directional_value = directionalValue;
record.descent_gap = directionalValue-steepestDirectional;
record.descent_tolerance = tolerance;
record.descent_bound_holds = directionalValue <= steepestDirectional+tolerance;
trace.iterations(end+1) = record;
end

function trace = append_steepest_terminal_trace(trace,k,theta,v,steepestDirectional)
if ~trace.enabled, return; end
diagnostics = struct('correction_ratio_values',0, ...
    'direction_growth_values',1,'direction_angle_values',0);
trace = append_direction_trace(trace,k,theta,v,steepestDirectional, ...
    steepestDirectional,empty_direction_update(),diagnostics);
end

function trace = update_direction_search_trace(trace,k,search)
if ~trace.enabled || isempty(trace.iterations), return; end
index = find([trace.iterations.k]==k,1,'last');
if isempty(index), return; end
trace.iterations(index).line_search_status = search.status;
trace.iterations(index).line_search_trials = search.trials;
if strcmp(search.status,'ok')
    trace.iterations(index).accepted_step = search.alpha;
end
end

function trace = append_line_trials(trace,search,iteration)
if ~trace.enabled || ~isfield(search,'trial_records')
    return
end
for k = 1:numel(search.trial_records)
    source = search.trial_records(k);
    point = [];
    if trace.points_enabled, point = source.point; end
    record = struct('iteration',iteration,'trial',source.trial, ...
        'point',point,'alpha',source.alpha,'accepted',source.accepted, ...
        'q',source.q,'g',source.g,'phi',source.phi);
    trace.line_trials(end+1) = record;
end
end

function result = value_or_default(value, default)
if isempty(value)
    result = default;
else
    result = value;
end
end

function result = max_directional(J, direction, derivativeMode)
if strcmp(derivativeMode, 'legacy')
    result = max(legacy_directional_products(J, direction));
else
    result = max(J*direction);
end
end

function result = gradient_difference_measure(difference, derivativeMode)
if strcmp(derivativeMode, 'legacy')
    squaredNorms = zeros(size(difference,1), 1);
    for objective = 1:size(difference,1)
        squaredNorms(objective) = norm(difference(objective,:)')^2;
    end
    result = max(squaredNorms);
else
    result = max(sum(difference.^2, 2));
end
end
