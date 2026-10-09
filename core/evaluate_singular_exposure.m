function observation = evaluate_singular_exposure(arguments,x)
%EVALUATE_SINGULAR_EXPOSURE Evaluate frozen singular-set diagnostics at x.

entryTemplate = struct('argument_id','','r',NaN,'d',NaN,'chi',NaN, ...
    'status','regular','distance_kind','','log10_r',NaN, ...
    'log10_d',NaN,'log10_chi',NaN);
entries = repmat(entryTemplate,1,numel(arguments));
for j = 1:numel(arguments)
    arg = arguments(j);
    t = arg.value(x);
    gradient = arg.gradient(x);
    gradientNorm = norm(gradient);
    entry = entryTemplate;
    entry.argument_id = arg.argument_id;
    entry.r = abs(t);
    entry.distance_kind = arg.distance_kind;
    if t == 0 && gradientNorm > 0
        entry.status = 'regular_exact_hit';
        entry.d = 0;
        entry.chi = Inf;
    elseif t == 0 && gradientNorm == 0
        entry.status = 'degenerate_zero';
    elseif gradientNorm == 0
        entry.status = 'inner_stationary';
        if strcmp(arg.distance_kind,'exact')
            entry.d = arg.distance(x);
        end
        entry.chi = 0;
    else
        entry.d = arg.distance(x);
        entry.chi = gradientNorm^2/sqrt(abs(t));
    end
    entry.log10_r = exact_log10(entry.r);
    entry.log10_d = exact_log10(entry.d);
    entry.log10_chi = exact_log10(entry.chi);
    entries(j) = entry;
end

rValues = [entries.r];
[s,sIndex] = min(rValues);
dValues = [entries.d];
validD = find(~isnan(dValues));
if isempty(validD)
    d = NaN; dIndex = NaN; dId = ''; dKind = '';
else
    [d,local] = min(dValues(validD));
    dIndex = validD(local);
    dId = entries(dIndex).argument_id;
    dKind = entries(dIndex).distance_kind;
end
chiValues = [entries.chi];
validChi = find(~isnan(chiValues));
if isempty(validChi)
    chi = NaN; chiIndex = NaN; chiId = '';
else
    [chi,local] = max(chiValues(validChi));
    chiIndex = validChi(local);
    chiId = entries(chiIndex).argument_id;
end
observation = struct('x',x,'entries',entries,'s',s,'d',d,'chi',chi, ...
    's_argument_id',entries(sIndex).argument_id,'d_argument_id',dId, ...
    'chi_argument_id',chiId,'d_distance_kind',dKind, ...
    'log10_s',exact_log10(s),'log10_d',exact_log10(d), ...
    'log10_chi',exact_log10(chi));
end

function y = exact_log10(x)
if isnan(x)
    y = NaN;
elseif x == 0
    y = -Inf;
elseif isinf(x)
    y = Inf;
else
    y = log10(x);
end
end
