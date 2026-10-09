function tests = test_initial_points
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'problems'));
testCase.TestData.mcodeRoot = mcodeRoot;
testCase.TestData.registry = problem_registry(mcodeRoot);
end

function testLoadsExactlyOneHundredExecutedStarts(testCase)
prob = testCase.TestData.registry(5);
starts = load_initial_points(prob, testCase.TestData.mcodeRoot);

verifySize(testCase, starts, [10, 100]);
source = load(fullfile(testCase.TestData.mcodeRoot, 'data', ...
    'initpoints', 'JOS1.mat'));
cells = struct2cell(source);
raw = cell2mat(cells);
verifyEqual(testCase, starts, raw(1:10, 1:100));
end

function testLegacyMLF1MappingUsesDGO1Starts(testCase)
prob = testCase.TestData.registry(8);
starts = load_initial_points(prob, testCase.TestData.mcodeRoot);
source = load(fullfile(testCase.TestData.mcodeRoot, 'data', ...
    'initpoints', 'DGO1.mat'));
raw = cell2mat(struct2cell(source));

verifyEqual(testCase, starts, raw(1, 1:100));
end

function testAP1StartsArePortedFromArchive(testCase)
prob = testCase.TestData.registry(41);
starts = load_initial_points(prob,testCase.TestData.mcodeRoot);
source = load(fullfile(testCase.TestData.mcodeRoot,'data','initpoints','AP11.mat'));
raw = cell2mat(struct2cell(source));

verifySize(testCase,starts,[2 100]);
verifyEqual(testCase,starts,raw(1:2,1:100),'AbsTol',0);
end
