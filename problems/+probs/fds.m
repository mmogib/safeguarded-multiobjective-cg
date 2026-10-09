function out = fds(x, request, ~)
n = numel(x);
b = (1:n)';
if strcmp(request, 'value')
    F1 = 0;
    F2 = 0;
    F3 = 0;
    for i = 1:n
        F1 = i*(x(i)-i)^4+F1;
        F2 = x(i)/n+F2;
        F3 = i*(n-i+1)*exp(-x(i))+F3;
    end
    out = [F1/n^2; exp(F2)+norm(x,2)^2; F3/(n*(n+1))];
else
    F2 = 0;
    for i = 1:n
        F2 = x(i)/n+F2;
    end
    c = sort(b, 'descend');
    g1 = (4/n^2)*b.*(x-b).^3;
    g2 = exp(F2)/n+2*x;
    g3 = -(1/(n*(n+1)))*(b.*c).*exp(-x);
    out = [g1'; g2'; g3'];
end
end
