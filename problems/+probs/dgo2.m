function out = dgo2(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^2; 9-sqrt(81-x(1)^2)];
else
    out = [2*x(1); x(1)/sqrt(81-x(1)^2)];
end
end
