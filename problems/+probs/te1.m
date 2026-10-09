function out = te1(x, request, ~)
if strcmp(request, 'value')
    out = [0.5*x(1)^2+x(2)^2-10*x(1)-100; ...
           x(1)^2+0.5*x(2)^2-10*x(2)-100];
else
    out = [x(1)-10, 2*x(2); 2*x(1), x(2)-10];
end
end
