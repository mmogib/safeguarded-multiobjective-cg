function out = mlf1(x, request, ~)
if strcmp(request, 'value')
    out = [(1+x(1)/20)*sin(x(1)); (1+x(1)/20)*cos(x(1))];
else
    out = [sin(x(1))/20+(1+x(1)/20)*cos(x(1)); ...
           cos(x(1))/20-(1+x(1)/20)*sin(x(1))];
end
end
