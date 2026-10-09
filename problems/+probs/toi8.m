function out = toi8(x, request, ~)
a = 2*x(1)-x(2);
b = 2*x(2)-x(3);
if strcmp(request, 'value')
    out = [(2*x(1)-1)^2; 2*a^2; 3*b^2];
else
    out = [4*(2*x(1)-1), 0, 0; 8*a, -4*a, 0; 0, 12*b, -6*b];
end
end
