function out = te6(x, request, ~)
if strcmp(request, 'value')
    out = [-log(x(1))-log(x(2)); x(1)^2+x(2)];
else
    out = [-1/x(1), -1/x(2); 2*x(1), 1];
end
end
