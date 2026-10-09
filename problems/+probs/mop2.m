function out = mop2(x, request, ~)
n = numel(x);
a = 1/sqrt(n);
s1 = sum((x-a).^2);
s2 = sum((x+a).^2);
if strcmp(request, 'value')
    out = [1-exp(-s1); 1-exp(-s2)];
else
    out = [2*(x-a)'*exp(-s1); 2*(x+a)'*exp(-s2)];
end
end
