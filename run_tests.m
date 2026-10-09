function results = run_tests
%RUN_TESTS Run the Phase A MATLAB unit and integration test suite.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'problems'),fullfile(root,'core'), ...
    fullfile(root,'config'),fullfile(root,'bench'));
results = runtests(fullfile(root,'tests'));
assertSuccess(results);
end
