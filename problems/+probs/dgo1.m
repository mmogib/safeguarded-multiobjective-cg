function out = dgo1(x, request, ~)
if strcmp(request, 'value')
    out = [sin(x(1)); sin(x(1)+0.7)];
else
    out = [cos(x(1)); cos(x(1)+0.7)];
end
end
