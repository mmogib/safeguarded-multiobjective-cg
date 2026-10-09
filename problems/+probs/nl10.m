function out = nl10(x,request,d)
%NL10 Corrected inherited ten with phi(t)=|t|^(3/2).

if strcmp(request,'value')
    out = values(x,d);
else
    out = jacobian(x,d);
end
end

function out = values(x,d)
switch d
    case 1
        out = [phi(x(1))+phi(x(2)-1);phi(x(1)-2)+phi(x(2)+1)];
    case 2
        out = [phi(x(1)+x(2))+phi(x(1)-1); ...
               phi(x(1)-x(2))+phi(x(2)+2)];
    case 3
        out = [phi(2*x(1)-x(2))+phi(x(1)+1); ...
               phi(x(1)+3*x(2)-1)+phi(x(2)-2)];
    case 4
        out = [phi(x(1)-2)+phi(x(2)+1); ...
               phi(x(1)-4)+phi(x(2)-3)];
    case 5
        out = [phi(x(1)*x(2))+phi(x(1)-1); ...
               phi((x(1)-1)*(x(2)+2))+phi(x(2)-2)];
    case 6
        out = [phi(x(1)^2+x(2)^2-1); ...
               phi((x(1)-3)^2+(x(2)-4)^2-4)];
    case 7
        out = [phi(x(1)-2*x(2)+1);phi(3*x(1)+x(2)-4)];
    case 8
        out = [phi(x(1)+x(2)-2)+phi(x(1)-1); ...
               phi(2*x(1)-x(2)+3)+phi(x(2)-4)];
    case 9
        out = [phi(x(1)^2-x(2))+phi(x(1)+1); ...
               phi(x(2)^2-x(1)+2)+phi(x(2)-3)];
    case 10
        out = [phi(x(1))+phi(x(1)+x(2)); ...
               phi(x(2)-5)+phi(x(1)-x(2)+1)];
    otherwise
        error('mcode:InvalidNL10Problem','NL10 problem index must lie in 1:10.');
end
end

function out = jacobian(x,d)
switch d
    case 1
        out = [dphi(x(1)),dphi(x(2)-1);dphi(x(1)-2),dphi(x(2)+1)];
    case 2
        a = dphi(x(1)+x(2)); b = dphi(x(1)-1);
        c = dphi(x(1)-x(2)); e = dphi(x(2)+2);
        out = [a+b,a;c,-c+e];
    case 3
        a = dphi(2*x(1)-x(2)); b = dphi(x(1)+1);
        c = dphi(x(1)+3*x(2)-1); e = dphi(x(2)-2);
        out = [2*a+b,-a;c,3*c+e];
    case 4
        out = [dphi(x(1)-2),dphi(x(2)+1); ...
               dphi(x(1)-4),dphi(x(2)-3)];
    case 5
        a = dphi(x(1)*x(2));
        b = dphi((x(1)-1)*(x(2)+2));
        out = [x(2)*a+dphi(x(1)-1),x(1)*a; ...
               (x(2)+2)*b,(x(1)-1)*b+dphi(x(2)-2)];
    case 6
        a = dphi(x(1)^2+x(2)^2-1);
        b = dphi((x(1)-3)^2+(x(2)-4)^2-4);
        out = [2*x(1)*a,2*x(2)*a; ...
               2*(x(1)-3)*b,2*(x(2)-4)*b];
    case 7
        a = dphi(x(1)-2*x(2)+1); b = dphi(3*x(1)+x(2)-4);
        out = [a,-2*a;3*b,b];
    case 8
        a = dphi(x(1)+x(2)-2); b = dphi(x(1)-1);
        c = dphi(2*x(1)-x(2)+3); e = dphi(x(2)-4);
        out = [a+b,a;2*c,-c+e];
    case 9
        a = dphi(x(1)^2-x(2)); b = dphi(x(2)^2-x(1)+2);
        out = [2*x(1)*a+dphi(x(1)+1),-a; ...
               -b,2*x(2)*b+dphi(x(2)-3)];
    case 10
        a = dphi(x(1)+x(2)); b = dphi(x(1)-x(2)+1);
        out = [dphi(x(1))+a,a;b,dphi(x(2)-5)-b];
end
end

function y = phi(t)
y = abs(t)^(3/2);
end

function y = dphi(t)
y = (3/2)*sign(t)*sqrt(abs(t));
end
