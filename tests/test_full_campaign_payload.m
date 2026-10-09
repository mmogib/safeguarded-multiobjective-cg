function tests = test_full_campaign_payload
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
cfg = full_campaign_config(root,tempname);
cfg.max_iter = 4;
testCase.TestData.cfg = cfg;
testCase.TestData.catalog = full_campaign_catalog(root);
end

function testTierOnePayloadSatisfiesContractWithTypedEmptyExposure(testCase)
entry = find_entry(testCase.TestData.catalog,'BK1');
[runs,iterations,extras,result] = build_full_campaign_payload( ...
    entry,'TTCGP',1,testCase.TestData.cfg);
contract = full_campaign_retention_contract();

verifyTrue(testCase,all(ismember(contract.runs,runs.Properties.VariableNames)));
verifyTrue(testCase,all(ismember(contract.iterations, ...
    iterations.Properties.VariableNames)));
verifyEqual(testCase,string(runs.status),string(result.status));
verifyEqual(testCase,runs.line_search_failure,{result.diagnostics.line_search_failure});
verifyNotEmpty(testCase,extras.line_trials);
verifyEmpty(testCase,result.trace.accepted_points);
verifyTrue(testCase,all(arrayfun(@(row) isempty(row.point), ...
    result.trace.line_trials)));
verifyEmpty(testCase,extras.tier2_accepted_exposure);
verifyEmpty(testCase,extras.tier2_line_trial_exposure);
verifyEmpty(testCase,extras.tier3_accepted_exposure);
verifyEmpty(testCase,extras.tier3_line_trial_exposure);
end

function testScalarIterationTraceBecomesOneTableRow(testCase)
entry = find_entry(testCase.TestData.catalog,'DGO1');
[~,iterations,~,result] = build_full_campaign_payload( ...
    entry,'TTCGP',3,testCase.TestData.cfg);

verifyEqual(testCase,numel(result.trace.iterations),1);
verifyEqual(testCase,height(iterations),1);
verifyEqual(testCase,iterations.k,result.trace.iterations.k);
verifyEqual(testCase,string(iterations.line_search_status), ...
    string(result.trace.iterations.line_search_status));
end

function testTierTwoExposureUsesChiAndKeepsTrialsSeparate(testCase)
entry = find_entry(testCase.TestData.catalog,'E2-1');
[~,iterations,extras,result] = build_full_campaign_payload( ...
    entry,'TTCGP',1,testCase.TestData.cfg);

verifyNotEmpty(testCase,extras.tier2_accepted_exposure);
verifyNotEmpty(testCase,result.trace.accepted_points);
verifyTrue(testCase,ismember('chi', ...
    extras.tier2_accepted_exposure.Properties.VariableNames));
verifyFalse(testCase,ismember('actual_exposure', ...
    extras.tier2_accepted_exposure.Properties.VariableNames));
verifyEmpty(testCase,extras.tier3_accepted_exposure);
verifyEqual(testCase,numel(unique(extras.tier2_accepted_exposure.k)), ...
    height(iterations));
verifyTrue(testCase,all(ismember(unique( ...
    extras.tier2_line_trial_exposure.k),iterations.k)));
end

function testTierThreePayloadRecordsPointwiseBoundAndOwnExposure(testCase)
entry = find_entry(testCase.TestData.catalog,'NC10-1');
[runs,iterations,extras] = build_full_campaign_payload( ...
    entry,'TTCGP',1,testCase.TestData.cfg);

verifyEmpty(testCase,extras.tier2_accepted_exposure);
verifyNotEmpty(testCase,extras.tier3_accepted_exposure);
verifyTrue(testCase,all(ismember({'actual_exposure','inverse_t_envelope'}, ...
    extras.tier3_accepted_exposure.Properties.VariableNames)));
verifyFalse(testCase,ismember('chi', ...
    extras.tier3_accepted_exposure.Properties.VariableNames));
verifyTrue(testCase,all(iterations.descent_bound_holds));
verifyEqual(testCase,runs.status,string(runs.status));
end

function entry = find_entry(catalog,label)
entry = catalog(strcmp({catalog.problem},label));
assert(isscalar(entry));
end
