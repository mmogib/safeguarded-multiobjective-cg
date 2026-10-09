function out = mop7(x, request, ~)
a = x(1)+x(2)-3;
b = -x(1)+x(2)+2;
c = x(1)+2*x(2)-1;
d = -x(1)+2*x(2);
if strcmp(request, 'value')
    out = [(x(1)-2)^2/2+(x(2)+1)^2/13+3; ...
           a^2/36+b^2/8-17; c^2/175+d^2/17-13];
else
    out = [x(1)-2, 2*(x(2)+1)/13; ...
           a/18-b/4, a/18+b/4; ...
           2*c/175-2*d/17, 4*c/175+4*d/17];
end
end
