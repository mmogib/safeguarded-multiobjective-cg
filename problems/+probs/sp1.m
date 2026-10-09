function out = sp1(x, request, ~)
if strcmp(request, 'value')
    out = [(x(1)-1)^2+(x(1)-x(2))^2; ...
           (x(2)-3)^2+(x(1)-x(2))^2];
else
    out = [2*(x(1)-1)+2*(x(1)-x(2)), -2*(x(1)-x(2)); ...
           2*(x(1)-x(2)), 2*(x(2)-3)-2*(x(1)-x(2))];
end
end
