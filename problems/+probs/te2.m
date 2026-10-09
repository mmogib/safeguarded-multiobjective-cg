function out = te2(x, request, ~)
a = 1/sqrt(2);
e = exp(-(x(1)-a)^2-(x(2)-a)^2);
if strcmp(request, 'value')
    out = [sin(x(2)); 1-e];
else
    out = [0, cos(x(2)); 2*(x(1)-a)*e, 2*(x(2)-a)*e];
end
end
