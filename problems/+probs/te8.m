function out = te8(x, request, ~)
n = numel(x);
if strcmp(request, 'value')
    out = [sum(x.^3); sum((x(1:n-1)-4).^2)+x(n)^2; ...
           -log(x(1))+5*sum(x(2:n).^2)];
else
    out = [(3*x.^2)'; [2*(x(1:n-1)-4); 2*x(n)]'; ...
           [-1/x(1); 10*x(2:n)]'];
end
end
