function [direction,info] = lindu_direction(previousDirection,currentSteepest, ...
    beta,fCurrentPrevious,fCurrentSteepest)
%LINDU_DIRECTION Lin-Du TT-PRP direction from equation (3.3).

if ~(isscalar(fCurrentSteepest) && isfinite(fCurrentSteepest) && ...
        fCurrentSteepest < 0)
    error('mcode:InvalidLinDuDenominator', ...
        'Lin-Du correction requires f(x_k,v_k) < 0.');
end
correction = abs(fCurrentPrevious)/(-fCurrentSteepest);
bracket = previousDirection+correction*currentSteepest;
direction = currentSteepest+beta*bracket;
info = struct('correction',correction,'bracket',bracket, ...
    'bracket_norm',norm(bracket));
end

