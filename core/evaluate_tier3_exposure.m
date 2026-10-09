function observation = evaluate_tier3_exposure(arguments,x)
%EVALUATE_TIER3_EXPOSURE Evaluate NC10 diagnostics without objective calls.

entryTemplate = struct('argument_id','','r',NaN,'d',NaN, ...
    'actual_exposure',NaN,'inverse_t_envelope',NaN, ...
    'status','regular','distance_kind','','log10_r',NaN, ...
    'log10_d',NaN,'log10_actual_exposure',NaN, ...
    'log10_inverse_t_envelope',NaN);
entries = repmat(entryTemplate,1,numel(arguments));

for j = 1:numel(arguments)
    arg = arguments(j);
    t = arg.value(x);
    gradientNorm = norm(arg.gradient(x));
    entry = entryTemplate;
    entry.argument_id = arg.argument_id;
    entry.r = abs(t);
    entry.distance_kind = arg.distance_kind;

    if t == 0 && gradientNorm > 0
        entry.status = 'regular_exact_hit';
        entry.d = 0;
        entry.actual_exposure = 0;
        entry.inverse_t_envelope = Inf;
    elseif t == 0 && gradientNorm == 0
        entry.status = 'degenerate_zero';
    elseif gradientNorm == 0
        entry.status = 'inner_stationary';
        if strcmp(arg.distance_kind,'exact')
            entry.d = arg.distance(x);
        end
        entry.actual_exposure = 0;
        entry.inverse_t_envelope = 0;
    else
        entry.d = arg.distance(x);
        [~,derivative] = oscillatory_kernel(t);
        entry.actual_exposure = abs(derivative)*gradientNorm;
        entry.inverse_t_envelope = gradientNorm/abs(t);
    end
    entry.log10_r = exact_log10(entry.r);
    entry.log10_d = exact_log10(entry.d);
    entry.log10_actual_exposure = exact_log10(entry.actual_exposure);
    entry.log10_inverse_t_envelope = exact_log10(entry.inverse_t_envelope);
    entries(j) = entry;
end

[s,sId] = min_with_id(entries,'r');
[d,dId] = min_with_id(entries,'d');
[actual,actualId] = max_with_id(entries,'actual_exposure');
[envelope,envelopeId] = max_with_id(entries,'inverse_t_envelope');
dKind = '';
if ~isempty(dId)
    dKind = entries(strcmp({entries.argument_id},dId)).distance_kind;
end
observation = struct('x',x,'entries',entries,'s',s,'d',d, ...
    'actual_exposure',actual,'inverse_t_envelope',envelope, ...
    's_argument_id',sId,'d_argument_id',dId, ...
    'actual_exposure_argument_id',actualId, ...
    'inverse_t_envelope_argument_id',envelopeId, ...
    'd_distance_kind',dKind,'log10_s',exact_log10(s), ...
    'log10_d',exact_log10(d), ...
    'log10_actual_exposure',exact_log10(actual), ...
    'log10_inverse_t_envelope',exact_log10(envelope));
end

function [value,id] = min_with_id(entries,field)
values = [entries.(field)];
valid = find(~isnan(values));
if isempty(valid)
    value = NaN; id = '';
else
    [value,local] = min(values(valid));
    id = entries(valid(local)).argument_id;
end
end

function [value,id] = max_with_id(entries,field)
values = [entries.(field)];
valid = find(~isnan(values));
if isempty(valid)
    value = NaN; id = '';
else
    [value,local] = max(values(valid));
    id = entries(valid(local)).argument_id;
end
end

function y = exact_log10(value)
if isnan(value)
    y = NaN;
elseif value == 0
    y = -Inf;
elseif isinf(value)
    y = Inf;
else
    y = log10(value);
end
end

