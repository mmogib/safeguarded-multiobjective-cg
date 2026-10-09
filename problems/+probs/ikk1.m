function out = ikk1(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^2; (x(1)-20)^2; x(2)^2];
else
    out = [2*x(1), 0; 2*(x(1)-20), 0; 0, 2*x(2)];
end
end
