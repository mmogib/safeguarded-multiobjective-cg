function out = bk1(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^2 + x(2)^2; (x(1)-5)^2 + (x(2)-5)^2];
else
    out = [2*x(1), 2*x(2); 2*x(1)-10, 2*x(2)-10];
end
end
