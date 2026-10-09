function out = sk1(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^4+3*x(1)^3-10*x(1)^2-10*x(1)-10; ...
           0.5*x(1)^4-2*x(1)^3-10*x(1)^2+10*x(1)-5];
else
    out = [4*x(1)^3+9*x(1)^2-20*x(1)-10; ...
           2*x(1)^3-6*x(1)^2-20*x(1)+10];
end
end
