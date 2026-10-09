function out = te4(x, request, ~)
if strcmp(request, 'value')
    out = [sum(x(1:end-1).^2)+2; sum(x)-2];
else
    out = [[2*x(1:end-1); 0]'; ones(1, numel(x))];
end
end
