function radius = oscillatory_sublevel_radius(upperBound)
%OSCILLATORY_SUBLEVEL_RADIUS Explicit radius for a scalar kernel sublevel.
% If phi(t)<=c with c>=0, then |t|<=max(1,sqrt(c)). Indeed, when
% |t|>=1, 0<1/t^2<=1 and sin(1/t^2)>=0, so phi(t)>=t^2.

if any(~isfinite(upperBound),'all') || any(upperBound < 0,'all')
    error('mcode:InvalidSublevelUpperBound', ...
        'The kernel sublevel upper bound must be finite and nonnegative.');
end
radius = max(1,sqrt(upperBound));
end

