function opts = experiment(method, mode)
%EXPERIMENT Return one of the five preregistered method configurations.

arguments
    method (1,:) char {mustBeMember(method, ...
        {'TTCGP','TTCGH','TTCGL','PRP+','HS+','LS+', ...
         'AVHZ+','MOSD','TT-PRP1'})}
    mode (1,:) char {mustBeMember(mode, ...
        {'paper','paper_r2','legacy','legacy_etasen'})}
end

opts = struct( ...
    'method', method, 'mode', mode, 'direction', '', ...
    'beta_formula', '', 'beta_safeguard', '', 'eta_bar', [], ...
    'lambda_mode', 'none', 'line_search_mode', '', ...
    'derivative_mode', '', 'qp_mode', '', ...
    'rho', 1e-4, 'sigma', 0.1, 'theta_tol', 5*sqrt(eps), ...
    'max_iter', 5000, 'mu', [], 'alpha_min', 1e-15, ...
    'alpha_max', 1e10, 'line_search_max_trials', 100, ...
    'trace_enabled', false);

switch method
    case 'TTCGP'
        opts.direction = 'threeterm';
        opts.beta_formula = 'PRP';
        opts.beta_safeguard = 'nonneg_capped';
        opts.eta_bar = 1;
    case 'TTCGH'
        opts.direction = 'threeterm';
        opts.beta_formula = 'HS';
        opts.beta_safeguard = 'nonneg_capped';
        opts.eta_bar = 1;
    case 'TTCGL'
        opts.direction = 'threeterm';
        opts.beta_formula = 'LS';
        opts.beta_safeguard = 'nonneg_capped';
        opts.eta_bar = 1;
    case 'PRP+'
        opts.direction = 'twoterm';
        opts.beta_formula = 'PRP';
        opts.beta_safeguard = 'nonneg';
    case 'HS+'
        opts.direction = 'twoterm';
        opts.beta_formula = 'HS';
        opts.beta_safeguard = 'nonneg';
    case 'LS+'
        opts.direction = 'twoterm';
        opts.beta_formula = 'LS';
        opts.beta_safeguard = 'nonneg';
    case 'AVHZ+'
        opts.direction = 'twoterm';
        opts.beta_formula = 'AVHZ';
        opts.beta_safeguard = 'nonneg';
        opts.mu = 1;
    case 'MOSD'
        opts.direction = 'steepest';
        opts.beta_formula = 'none';
        opts.beta_safeguard = 'none';
    case 'TT-PRP1'
        opts.direction = 'lindu';
        opts.beta_formula = 'PRP';
        opts.beta_safeguard = 'nonneg';
end

if strcmp(mode, 'paper')
    opts.lambda_mode = ternary(strcmp(opts.direction, 'threeterm'), 'paper', 'none');
    opts.line_search_mode = 'validated_strong';
    opts.derivative_mode = 'corrected';
    opts.qp_mode = 'corrected';
elseif strcmp(mode, 'paper_r2')
    opts.lambda_mode = ternary(strcmp(opts.direction, 'threeterm'), 'paper_r2', 'none');
    opts.line_search_mode = 'validated_strong';
    opts.derivative_mode = 'corrected';
    opts.qp_mode = 'corrected';
elseif strcmp(mode, 'legacy')
    opts.lambda_mode = ternary(strcmp(opts.direction, 'threeterm'), 'legacy_driver', 'none');
    opts.line_search_mode = 'legacy';
    opts.derivative_mode = 'legacy';
    opts.qp_mode = 'legacy';
    opts.theta_tol = 5*sqrt(2.22e-16);
else
    if ~strcmp(method, 'TTCGP')
        error('mcode:InvalidLegacyEtaSen', ...
            'legacy_etasen exists only for the TTCGP sensitivity driver.');
    end
    opts.lambda_mode = 'legacy_etasen';
    opts.line_search_mode = 'legacy';
    opts.derivative_mode = 'legacy';
    opts.qp_mode = 'legacy';
    opts.theta_tol = 5*sqrt(2.22e-16);
end
end

function result = ternary(condition, ifTrue, ifFalse)
if condition
    result = ifTrue;
else
    result = ifFalse;
end
end
