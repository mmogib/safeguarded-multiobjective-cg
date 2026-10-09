function out = ff1(x, request, ~)
e1 = exp(-(x(1)-1)^2-(x(2)+1)^2);
e2 = exp(-(x(1)+1)^2-(x(2)-1)^2);
if strcmp(request, 'value')
    out = [1-e1; 1-e2];
else
    out = [2*(x(1)-1)*e1, 2*(x(2)+1)*e1; ...
           2*(x(1)+1)*e2, 2*(x(2)-1)*e2];
end
end
