function out = ssfyy2(x, request, ~)
if strcmp(request, 'value')
    out = [10+x(1)^2-10*cos(pi*x(1)/2); (x(1)-4)^2];
else
    out = [2*x(1)+5*pi*sin(pi*x(1)/2); 2*(x(1)-4)];
end
end
