function out = e2(x,request,problemIndex)
%E2 Five constructed non-Lipschitz diagnostic problems.

switch problemIndex
    case 1
        s = x(1); h = x(2);
        [penalty,dpenalty] = holder_kernel(h);
        if strcmp(request,'value')
            out = [(s+1)^2+penalty;(s-1)^2+penalty];
        else
            out = [2*(s+1),dpenalty;2*(s-1),dpenalty];
        end
    case 2
        s = x(1); h = x(2)-x(1)^2;
        [penalty,dpenalty] = holder_kernel(h);
        if strcmp(request,'value')
            out = [(s+1)^2+penalty;(s-1)^2+penalty];
        else
            out = [2*(s+1)-2*x(1)*dpenalty,dpenalty; ...
                   2*(s-1)-2*x(1)*dpenalty,dpenalty];
        end
    case 3
        s = x(1)+x(2); h = x(2)-0.5*sin(x(1));
        [penalty,dpenalty] = holder_kernel(h);
        gradS = [1,1];
        gradH = [-0.5*cos(x(1)),1];
        if strcmp(request,'value')
            out = [(s+1)^2+penalty;(s-1)^2+penalty];
        else
            out = [2*(s+1)*gradS+dpenalty*gradH; ...
                   2*(s-1)*gradS+dpenalty*gradH];
        end
    case 4
        s = x(1); h = x(2);
        [penalty,dpenalty] = holder_kernel(h);
        a1 = 1+s^2;
        a2 = 1+(s-1)^2;
        if strcmp(request,'value')
            out = [(s+1)^2+a1*penalty;(s-1)^2+a2*penalty];
        else
            out = [2*(s+1)+2*s*penalty,a1*dpenalty; ...
                   2*(s-1)+2*(s-1)*penalty,a2*dpenalty];
        end
    case 5
        z = x(3:10);
        h = x(2)-0.25*(z'*z);
        [penalty,dpenalty] = holder_kernel(h);
        centers = [-1;0;1];
        if strcmp(request,'value')
            out = (x(1)-centers).^2+penalty+(z'*z);
        else
            out = zeros(3,10);
            out(:,1) = 2*(x(1)-centers);
            out(:,2) = dpenalty;
            out(:,3:10) = repmat(((2-0.5*dpenalty)*z)',3,1);
        end
    otherwise
        error('mcode:InvalidE2Problem','E2 problem index must lie in 1:5.');
end
end
