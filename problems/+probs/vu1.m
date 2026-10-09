function out = vu1(x, request, ~)
s = x(1)^2+x(2)^2+1;
if strcmp(request, 'value')
    out = [1/s; x(1)^2+3*x(2)^2+1];
else
    out = [-2*x(1)/s^2, -2*x(2)/s^2; 2*x(1), 6*x(2)];
end
end
