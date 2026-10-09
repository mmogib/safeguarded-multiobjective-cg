function tests = test_beta
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'core'));
end

function testPRPHSAndLSFormulasAreUnsafeguarded(testCase)
q = struct('p', -2, 'f_x_v', -4, 'f_xnext_d', -1, ...
    'f_x_d', -3, 'gamma', 0.5);

[prp, prpInfo] = beta_formula('PRP', q, 'threeterm', 'corrected', 1);
[hs, hsInfo] = beta_formula('HS', q, 'threeterm', 'corrected', 1);
[ls, lsInfo] = beta_formula('LS', q, 'threeterm', 'corrected', 1);

verifyEqual(testCase, prp, -0.5, 'AbsTol', 1e-15);
verifyEqual(testCase, hs, -1, 'AbsTol', 1e-15);
verifyEqual(testCase, ls, -2/3, 'AbsTol', 1e-15);
verifyEqual(testCase, prpInfo.denominator, 4);
verifyEqual(testCase, hsInfo.denominator, 2);
verifyEqual(testCase, lsInfo.denominator, 3);
verifyFalse(testCase, prpInfo.used_fallback);
end

function testAVHZFormulaUsesMuAndGamma(testCase)
q = struct('p', 5, 'f_x_v', -2, 'f_xnext_d', 3, ...
    'f_x_d', 1, 'gamma', 4);

[raw, info] = beta_formula('AVHZ', q, 'twoterm', 'corrected', 0.5);

verifyEqual(testCase, raw, 1, 'AbsTol', 1e-15);
verifyEqual(testCase, info.denominator, 2);
end

function testZeroDenominatorFallsBackAndIsReported(testCase)
q = struct('p', 5, 'f_x_v', -2, 'f_xnext_d', 1, ...
    'f_x_d', 1, 'gamma', 4);

[raw, info] = beta_formula('HS', q, 'threeterm', 'legacy', 1);

verifyEqual(testCase, raw, 0);
verifyTrue(testCase, info.used_fallback);
end

function testCorrectedHSUsesNamedScaleAwareZeroToSteepestFallback(testCase)
q = struct('p', 5, 'f_x_v', -2, 'f_xnext_d', 1+eps/4, ...
    'f_x_d', 1, 'gamma', 4);

[raw, info] = beta_formula('HS', q, 'threeterm', 'corrected', 1);

verifyEqual(testCase, raw, 0);
verifyTrue(testCase, info.used_fallback);
verifyEqual(testCase, info.fallback_policy, 'hs_scale_aware_zero_to_steepest');
verifyGreaterThan(testCase, info.zero_tolerance, 0);
end

function testSafeguardsAreSeparatePolicies(testCase)
[nonnegative, info1] = beta_safeguard(-0.4, 'nonneg', []);
[uncapped, info2] = beta_safeguard(2.5, 'nonneg', []);
[capped, info3] = beta_safeguard(2.5, 'nonneg_capped', 1.25);

verifyEqual(testCase, nonnegative, 0);
verifyEqual(testCase, uncapped, 2.5);
verifyEqual(testCase, capped, 1.25);
verifyTrue(testCase, info1.truncated);
verifyFalse(testCase, info2.truncated);
verifyTrue(testCase, info3.clipped);
end
