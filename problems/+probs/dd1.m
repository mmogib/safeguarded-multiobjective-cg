function out = dd1(x, request, ~)
if strcmp(request, 'value')
    out = [sum(x.^2); 3*x(1)+2*x(2)-x(3)/3+0.01*(x(4)-x(5))^3];
else
    d = 0.03*(x(4)-x(5))^2;
    out = [2*x'; 3, 2, -1/3, d, -d];
end
end
