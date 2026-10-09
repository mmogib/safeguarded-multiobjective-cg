function out = mmr1(x, request, ~)
e1 = exp(-((x(2)-0.6)/0.4)^2);
e2 = exp(-((x(2)-0.2)/0.04)^2);
num = 2-0.8*e1-e2;
den = 1+x(1)^2;
if strcmp(request, 'value')
    out = [1+x(1)^2; num/den];
else
    dnum = 1.6*(x(2)-0.6)*e1/0.16 + 2*(x(2)-0.2)*e2/0.0016;
    out = [2*x(1), 0; -2*x(1)*num/den^2, dnum/den];
end
end
