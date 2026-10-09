function out = ap1(x, request, mode)
if strcmp(request, 'value')
    out = [0.25*((x(1)-1)^4+2*(x(2)-4)^4); ...
           exp((x(1)+x(2))/2)+x(1)^2+x(2)^2; ...
           (exp(-x(1))+2*exp(-x(2)))/6];
else
    if strcmp(mode, 'legacy')
        g12 = 2*(x(2)-2)^3;
    else
        g12 = 2*(x(2)-4)^3;
    end
    e = 0.5*exp((x(1)+x(2))/2);
    out = [(x(1)-1)^3, g12; e+2*x(1), e+2*x(2); ...
           -exp(-x(1))/6, -exp(-x(2))/3];
end
end
