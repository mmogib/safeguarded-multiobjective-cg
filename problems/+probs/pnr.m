function out = pnr(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^4+x(2)^4+x(1)^2+x(2)^2+10*x(1)*x(2)+0.25*x(1)+20; ...
           (x(1)-1)^2+x(2)^2];
else
    out = [4*x(1)^3+2*x(1)+10*x(2)+0.25, 4*x(2)^3+2*x(2)+10*x(1); ...
           2*(x(1)-1), 2*x(2)];
end
end
