function [value,derivative] = oscillatory_kernel(t)
%OSCILLATORY_KERNEL Differentiable coercive kernel with discontinuous slope.
% phi(t)=t^2(1+sin(1/t^2)) for t~=0, with the true values
% phi(0)=phi'(0)=0. No neighbourhood of zero is numerically masked.

value = zeros(size(t),'like',t);
derivative = zeros(size(t),'like',t);
nonzero = (t ~= 0);
z = t(nonzero);
phase = 1./(z.^2);
value(nonzero) = z.^2.*(1+sin(phase));
derivative(nonzero) = 2*z+2*z.*sin(phase)-(2./z).*cos(phase);
end

