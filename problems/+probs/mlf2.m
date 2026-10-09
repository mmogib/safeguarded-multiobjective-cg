function out = mlf2(x, request, ~)
a = x(1)^2+x(2)-11;
b = x(1)+x(2)^2-7;
c = 4*x(1)^2+2*x(2)-11;
d = 2*x(1)+4*x(2)^2-7;
if strcmp(request, 'value')
    out = [-5+(a^2+b^2)/200; -5+(c^2+d^2)/200];
else
    out = [(2*x(1)*a+b)/100, (a+2*x(2)*b)/100; ...
           (4*x(1)*c+d)/50, (c+4*x(2)*d)/50];
end
end
