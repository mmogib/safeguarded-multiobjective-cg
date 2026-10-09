function tests = test_lindu_direction
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot,'core'));
end

function testEquation33UsesAbsoluteCorrectionWithoutScaling(testCase)
previous = [1;2];
currentSteepest = [-1;0.5];
beta = 2;
fCurrentPrevious = -3;
fCurrentSteepest = -2;

[direction,info] = lindu_direction(previous,currentSteepest,beta, ...
    fCurrentPrevious,fCurrentSteepest);

verifyEqual(testCase,info.correction,1.5,'AbsTol',0);
verifyEqual(testCase,info.bracket,[-0.5;2.75],'AbsTol',0);
verifyEqual(testCase,direction,[-2;6],'AbsTol',0);
end

function testCorrectionUsesAbsoluteDirectionalValue(testCase)
[negative,~] = lindu_direction([1;2],[-1;0.5],2,-3,-2);
[positive,~] = lindu_direction([1;2],[-1;0.5],2,3,-2);
verifyEqual(testCase,negative,positive,'AbsTol',0);
end

function testNonnegativeSteepestDirectionalValueIsRejected(testCase)
verifyError(testCase,@() lindu_direction(1,-1,2,3,0), ...
    'mcode:InvalidLinDuDenominator');
end

