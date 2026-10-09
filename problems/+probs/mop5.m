function out = mop5(x, request, mode)
r2 = sum(x.^2);
if strcmp(request, 'value')
    out = [0.5*r2+sin(r2); ...
           (3*x(1)-2*x(2)+4)^2/8+(x(1)-x(2)+1)^2/27+15; ...
           1/(r2+1)-1.1*exp(-r2)];
else
    a = 3*x(1)-2*x(2)+4;
    b = x(1)-x(2)+1;
    expTerm = exp(-r2);
    g31 = -2*x(1)/(r2+1)^2+2.2*x(1)*expTerm;
    if strcmp(mode, 'legacy')
        g32 = -2*x(2)/(r2+1)^2+2.2*x(1)*expTerm;
    else
        g32 = -2*x(2)/(r2+1)^2+2.2*x(2)*expTerm;
    end
    out = [x(1)+2*x(1)*cos(r2), x(2)+2*x(2)*cos(r2); ...
           3*a/4+2*b/27, -a/2-2*b/27; g31, g32];
end
end
