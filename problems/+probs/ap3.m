function out = ap3(x, request, mode)
if strcmp(request, 'value')
    out = [0.25*((x(1)-4)^4+2*(x(2)-2)^4); ...
           (x(2)-x(1)^2)^2+(1-x(1))^2];
else
    if strcmp(mode, 'legacy')
        g11 = (x(1)-1)^3;
    else
        g11 = (x(1)-4)^3;
    end
    out = [g11, 2*(x(2)-2)^3; ...
           -4*x(1)*(x(2)-x(1)^2)-2*(1-x(1)), 2*(x(2)-x(1)^2)];
end
end
