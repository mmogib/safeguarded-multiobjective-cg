function out = jos1(x, request, ~)
n = numel(x);
if strcmp(request, 'value')
    out = [sum(x.^2)/n; sum((x-2).^2)/n];
else
    out = [(2/n)*x'; (2/n)*(x-2)'];
end
end
