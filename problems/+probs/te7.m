function out = te7(x, request, ~)
if strcmp(request, 'value')
    out = [sum(x.^4+x.^3); sum(x)];
else
    out = [(4*x.^3+3*x.^2)'; ones(1, numel(x))];
end
end
