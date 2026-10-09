function tests = test_public_interface
%TEST_PUBLIC_INTERFACE End-user commands do not expose exchange numbers.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.root = root;
addpath(genpath(root));
end

function testPublicCommandsExist(testCase)
names = ["reproduce_results";"reproduce_figures"; ...
    "rerun_all_experiments"];
for k = 1:numel(names)
    verifyEqual(testCase,exist(names(k),'file'),2);
end
end

function testReadmeUsesOnlyPublicCommands(testCase)
text = fileread(fullfile(testCase.TestData.root,'README.md'));
verifySubstring(testCase,text,'reproduce_results');
verifySubstring(testCase,text,'reproduce_figures');
verifySubstring(testCase,text,'rerun_all_experiments');
verifyEmpty(testCase,regexp(text,'_0[0-9][0-9]','once'));
verifySubstring(testCase,text,'No completed result data are included');
verifyEmpty(testCase,strfind(text,'supplied result stores')); %#ok<STRIFCND>
rerunPosition = strfind(text,'rerun_all_experiments');
resultsPosition = strfind(text,'reproduce_results');
verifyLessThan(testCase,rerunPosition(1),resultsPosition(1));
end

function testReportWrapperRequiresLocalRunManifest(testCase)
source = fileread(fullfile(testCase.TestData.root,'reproduce_results.m'));
verifySubstring(testCase,source,'reproduction_manifest.mat');
verifySubstring(testCase,source,'reproduction:MissingManifest');
end
