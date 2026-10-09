function out = toi4(x, request, ~)
if strcmp(request, 'value')
    out = [x(1)^2+x(2)^2+1; 0.5*((x(1)-x(2))^2+(x(3)-x(4))^2)+1];
else
    out = [2*x(1), 2*x(2), 0, 0; ...
           x(1)-x(2), -(x(1)-x(2)), x(3)-x(4), -(x(3)-x(4))];
end
end
