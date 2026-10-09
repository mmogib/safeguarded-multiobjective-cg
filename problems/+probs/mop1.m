function out = mop1(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^2; (x(1)-2)^2];
else
    out = [2*x(1); 2*(x(1)-2)];
end
end
