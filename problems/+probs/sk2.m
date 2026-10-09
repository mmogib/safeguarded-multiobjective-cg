function out = sk2(x, request, ~)
b = sum(x.^2);
c = sum(sin(x));
if strcmp(request, 'value')
    out = [(x(1)-2)^2+(x(2)+3)^2+(x(3)-5)^2+(x(4)-4)^2-5; ...
           -c/(1+b/100)];
else
    g2 = -(cos(x)*(1+b/100)-c*x/50)/(1+b/100)^2;
    out = [2*(x-[2;-3;5;4])'; g2'];
end
end
