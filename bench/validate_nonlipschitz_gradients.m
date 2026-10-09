function report = validate_nonlipschitz_gradients(registry)
%VALIDATE_NONLIPSCHITZ_GRADIENTS Two-sided, distance-aware FD validation.

bands = 10.^(-(1:8));
rowCount = sum(arrayfun(@(p) numel(nonlipschitz_arguments(p)),registry))* ...
    2*numel(bands);
problem = strings(rowCount,1);
argument = strings(rowCount,1);
side = zeros(rowCount,1);
distance = zeros(rowCount,1);
firstError = zeros(rowCount,1);
bestError = zeros(rowCount,1);
relativeBestError = zeros(rowCount,1);
bestStepIndex = zeros(rowCount,1);
noCrossing = false(rowCount,1);
passed = false(rowCount,1);
row = 0;

for p = 1:numel(registry)
    prob = registry(p);
    args = nonlipschitz_arguments(prob);
    for j = 1:numel(args)
        arg = args(j);
        for signedSide = [-1,1]
            for band = bands
                row = row+1;
                x = arg.validation_anchor+signedSide*band*arg.validation_normal;
                gradient = arg.gradient(x);
                direction = gradient/norm(gradient);
                t0 = arg.value(x);
                initialStep = 0.2*abs(t0)/max(norm(gradient),realmin);
                initialStep = max(initialStep,16*eps(max(1,norm(x,inf))));
                [steps,crossingFree] = safe_steps(arg,x,direction,t0,initialStep);
                errors = directional_errors(prob,x,direction,steps);
                exact = prob.jacobian(x)*direction;
                [best,bestIndex] = min(errors);
                relative = best/max(1,norm(exact));

                problem(row) = prob.paper_label;
                argument(row) = arg.argument_id;
                side(row) = signedSide;
                distance(row) = band;
                firstError(row) = errors(1);
                bestError(row) = best;
                relativeBestError(row) = relative;
                bestStepIndex(row) = bestIndex;
                noCrossing(row) = crossingFree;
                passed(row) = crossingFree && relative <= 2e-3 && ...
                    best <= errors(1)*(1+1e-12);
            end
        end
    end
end

report = table(problem,argument,side,distance,firstError,bestError, ...
    relativeBestError,bestStepIndex,noCrossing,passed, ...
    'VariableNames',{'problem','argument','side','distance','first_error', ...
    'best_error','relative_best_error','best_step_index','no_crossing','passed'});
end

function [steps,noCrossing] = safe_steps(arg,x,direction,t0,initialStep)
step = initialStep;
noCrossing = false;
for attempt = 1:30
    plus = arg.value(x+step*direction);
    minus = arg.value(x-step*direction);
    if sign(plus) == sign(t0) && sign(minus) == sign(t0)
        noCrossing = true;
        break
    end
    step = step/2;
end
steps = step*0.5.^(0:10);
end

function errors = directional_errors(prob,x,direction,steps)
exact = prob.jacobian(x)*direction;
errors = zeros(size(steps));
for k = 1:numel(steps)
    h = steps(k);
    finiteDifference = (prob.value(x+h*direction)- ...
        prob.value(x-h*direction))/(2*h);
    errors(k) = norm(finiteDifference-exact,inf);
end
end
