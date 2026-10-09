function tests = test_gradients
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
testCase.TestData.registry = problem_registry(mcodeRoot);
end

function testDomainSafeDirectionalCentralDifferences(testCase)
registry = testCase.TestData.registry;
oldState = rng;
cleanup = onCleanup(@() rng(oldState)); %#ok<NASGU>
rng(240916, 'twister');

for k = 1:numel(registry)
    prob = registry(k);
    x = prob.safe_point;
    J = prob.jacobian(x);
    for directionIndex = 1:3
        direction = randn(prob.n, 1);
        direction = direction / norm(direction);
        h = central_step(x, direction);
        assert_domain(prob, x+h*direction);
        assert_domain(prob, x-h*direction);
        fd = (prob.value(x+h*direction)-prob.value(x-h*direction))/(2*h);
        exact = J*direction;
        tolerance = 1e-8 + 1e-6*abs(fd);
        verifyLessThanOrEqual(testCase, abs(exact-fd), tolerance, ...
            sprintf('%s, direction %d', prob.paper_label, directionIndex));
    end
end
end

function testSelectedCoordinateCentralDifferences(testCase)
registry = testCase.TestData.registry;
selectedProblems = [1:35, 39:41];

for k = selectedProblems
    prob = registry(k);
    x = prob.safe_point;
    J = prob.jacobian(x);
    coordinates = unique(round(linspace(1, prob.n, min(prob.n, 5))));
    for coordinate = coordinates
        direction = zeros(prob.n, 1);
        direction(coordinate) = 1;
        h = central_step(x, direction);
        fd = (prob.value(x+h*direction)-prob.value(x-h*direction))/(2*h);
        exact = J(:, coordinate);
        tolerance = 1e-8 + 1e-6*abs(fd);
        verifyLessThanOrEqual(testCase, abs(exact-fd), tolerance, ...
            sprintf('%s, coordinate %d', prob.paper_label, coordinate));
    end
end
end

function h = central_step(x, direction)
h = eps^(1/3)*max(1, norm(x, inf))/max(1, norm(direction, inf));
end

function assert_domain(prob, x)
switch prob.legacy_index
    case 3
        assert(abs(x(1)) < 9);
    case 13
        assert(all(x > 0));
    case {31, 32, 33}
        assert(x(1) > 0);
end
end
