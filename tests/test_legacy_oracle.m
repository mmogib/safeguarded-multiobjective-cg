function tests = test_legacy_oracle
tests = functiontests(localfunctions);
end

function setupOnce(~)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(mcodeRoot, 'bench'));
end

function testSnapshotIsIsolatedAndGeneratedDriversAreRecorded(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(mcodeRoot);
archiveRoot = fullfile(projectRoot, 'yahya_code', 'Objective_functions-2');
assumeTrue(testCase,isfolder(archiveRoot), ...
    'The optional unpublished legacy archive is unavailable.');

snapshot = prepare_legacy_oracle(mcodeRoot, archiveRoot);

verifyTrue(testCase, isfolder(snapshot.path));
verifyNotEqual(testCase, snapshot.path, archiveRoot);
verifyTrue(testCase, isfile(fullfile(snapshot.path, 'oracle_TTCGP.m')));
verifyTrue(testCase, isfile(fullfile(snapshot.path, 'oracle_PRP.m')));
verifyEqual(testCase, numel(snapshot.generated_drivers), 5);
text = fileread(fullfile(snapshot.path, 'oracle_TTCGP.m'));
verifyTrue(testCase, contains(text, 'h3 = 11;'));
verifyTrue(testCase, contains(text, "beta_type = 'PRP+';"));
verifyTrue(testCase, contains(text, "oracle_TTCGP_output.mat"));
savePosition = strfind(text, "save('oracle_TTCGP_output.mat'");
aggregatePosition = strfind(text, 'MedianIter = median');
verifyNumElements(testCase, savePosition, 1);
verifyLessThan(testCase, savePosition, aggregatePosition(1));
between = text(savePosition:aggregatePosition(1)-1);
verifyTrue(testCase, contains(between, 'return;'));
end
