function [value,derivative] = holder_kernel(t)
%HOLDER_KERNEL C1 Holder-1/2 kernel phi(t)=|t|^(3/2).

value = abs(t).^(3/2);
derivative = (3/2).*sign(t).*sqrt(abs(t));
end
