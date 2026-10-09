classdef Evaluator < handle
    %EVALUATOR Scaled problem access with exact, iteration-scoped lazy caches.

    properties (SetAccess = private)
        problem
        scale
        derivative_mode
    end

    properties (Access = private)
        cache_x = {}
        cache_raw_F = {}
        cache_F = {}
        cache_J = {}
        counter_state
    end

    methods
        function obj = Evaluator(problem, x0, derivativeMode)
            arguments
                problem (1,1) struct
                x0 (:,1) double
                derivativeMode (1,:) char {mustBeMember(derivativeMode, {'legacy','corrected'})}
            end
            obj.problem = problem;
            obj.derivative_mode = derivativeMode;
            obj.counter_state = struct( ...
                'vector_F', 0, 'vector_J', 0, ...
                'component_F', 0, 'component_J', 0, ...
                'evaluation_time', 0);

            started = tic;
            if strcmp(derivativeMode, 'legacy')
                rawJ = problem.legacy_jacobian(x0);
            else
                rawJ = problem.jacobian(x0);
            end
            elapsed = toc(started);
            obj.counter_state.vector_J = 1;
            obj.counter_state.component_J = problem.m;
            obj.counter_state.evaluation_time = elapsed;
            obj.scale = 1 ./ max(1, vecnorm(rawJ, inf, 2));
            obj.cache_x = {x0};
            obj.cache_raw_F = {[]};
            obj.cache_F = {[]};
            obj.cache_J = {obj.scale .* rawJ};
        end

        function F = value(obj, x)
            idx = obj.find_point(x);
            if idx == 0
                idx = obj.append_point(x);
            end
            if isempty(obj.cache_F{idx})
                started = tic;
                rawF = obj.problem.value(x);
                elapsed = toc(started);
                obj.cache_raw_F{idx} = rawF;
                obj.cache_F{idx} = obj.scale .* rawF;
                obj.counter_state.vector_F = obj.counter_state.vector_F + 1;
                obj.counter_state.component_F = obj.counter_state.component_F + obj.problem.m;
                obj.counter_state.evaluation_time = obj.counter_state.evaluation_time + elapsed;
            end
            F = obj.cache_F{idx};
        end

        function J = jacobian(obj, x)
            idx = obj.find_point(x);
            if idx == 0
                idx = obj.append_point(x);
            end
            if isempty(obj.cache_J{idx})
                started = tic;
                if strcmp(obj.derivative_mode, 'legacy')
                    rawJ = obj.problem.legacy_jacobian(x);
                else
                    rawJ = obj.problem.jacobian(x);
                end
                elapsed = toc(started);
                obj.cache_J{idx} = obj.scale .* rawJ;
                obj.counter_state.vector_J = obj.counter_state.vector_J + 1;
                obj.counter_state.component_J = obj.counter_state.component_J + obj.problem.m;
                obj.counter_state.evaluation_time = obj.counter_state.evaluation_time + elapsed;
            end
            J = obj.cache_J{idx};
        end

        function F = unscaled_value(obj, x)
            idx = obj.find_point(x);
            if idx == 0 || isempty(obj.cache_raw_F{idx})
                obj.value(x);
                idx = obj.find_point(x);
            end
            F = obj.cache_raw_F{idx};
        end

        function begin_iteration(obj, current, previous)
            keep = false(1, numel(obj.cache_x));
            for k = 1:numel(obj.cache_x)
                keep(k) = isequal(obj.cache_x{k}, current) || isequal(obj.cache_x{k}, previous);
            end
            obj.cache_x = obj.cache_x(keep);
            obj.cache_raw_F = obj.cache_raw_F(keep);
            obj.cache_F = obj.cache_F(keep);
            obj.cache_J = obj.cache_J(keep);
        end

        function result = counts(obj)
            result = obj.counter_state;
        end
    end

    methods (Access = private)
        function idx = find_point(obj, x)
            idx = 0;
            for k = 1:numel(obj.cache_x)
                if isequal(obj.cache_x{k}, x)
                    idx = k;
                    return
                end
            end
        end

        function idx = append_point(obj, x)
            obj.cache_x{end+1} = x;
            obj.cache_raw_F{end+1} = [];
            obj.cache_F{end+1} = [];
            obj.cache_J{end+1} = [];
            idx = numel(obj.cache_x);
        end
    end
end
