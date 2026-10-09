function out = hill(x, request, ~)
a = (2*pi/360)*(45+40*sin(2*pi*x(1))+25*sin(2*pi*x(2)));
b = 1+0.5*cos(2*pi*x(1));
if strcmp(request, 'value')
    out = [b*cos(a); b*sin(a)];
else
    a1 = (2*pi/360)*80*pi*cos(2*pi*x(1));
    a2 = (2*pi/360)*50*pi*cos(2*pi*x(2));
    b1 = -pi*sin(2*pi*x(1));
    out = [-sin(a)*a1*b+cos(a)*b1, -sin(a)*a2*b; ...
            cos(a)*a1*b+sin(a)*b1,  cos(a)*a2*b];
end
end
