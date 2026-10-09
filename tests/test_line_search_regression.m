function tests = test_line_search_regression
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot,'core'),fullfile(mcodeRoot,'problems'), ...
    fullfile(mcodeRoot,'config'),fullfile(mcodeRoot,'bench'));
end

function testRecoversAllSavedPhaseBFailureStates(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
fixtureFile = fullfile(mcodeRoot,'data','results','phaseB', ...
    'line_search_failure_states.mat');
assumeTrue(testCase,isfile(fixtureFile), ...
    'The optional historical regression fixture is unavailable.');
saved = load(fixtureFile,'failure_states');
states = saved.failure_states;
registry = problem_registry(mcodeRoot);
opts = experiment('TTCGP','paper');
lineOpts = struct('mode','validated_strong','rho',opts.rho, ...
    'sigma',opts.sigma,'alpha_min',opts.alpha_min, ...
    'alpha_max',opts.alpha_max,'max_trials',opts.line_search_max_trials);
recovered = false(numel(states),1);
validated = false(numel(states),1);

for row = 1:numel(states)
    state = states(row);
    prob = registry(state.legacy_index);
    evaluator = Evaluator(prob,state.x0,'corrected');
    result = line_search(evaluator,state.x,state.direction, ...
        state.alpha_start,lineOpts);
    recovered(row) = strcmp(result.status,'ok');
    if recovered(row)
        F0 = evaluator.value(state.x);
        J0 = evaluator.jacobian(state.x);
        gamma = max(J0*state.direction);
        F = evaluator.value(state.x+result.alpha*state.direction);
        J = evaluator.jacobian(state.x+result.alpha*state.direction);
        phi = max(J*state.direction);
        validated(row) = all(F<=F0+opts.rho*result.alpha*gamma) && ...
            abs(phi)<=opts.sigma*abs(gamma);
    end
end

failed = find(~recovered | ~validated);
message = sprintf('Failed to recover %d of %d saved states; first rows: %s', ...
    numel(failed),numel(states),mat2str(failed(1:min(10,end))'));
verifyTrue(testCase,isempty(failed),message);
end
