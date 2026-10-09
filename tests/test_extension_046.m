function tests = test_extension_046
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
testCase.TestData.root = root;
end

function testNewMethodsAreExistingTwoTermFormulas(testCase)
hs = experiment('HS+','paper_r2');
ls = experiment('LS+','paper_r2');

verifyEqual(testCase,hs.direction,'twoterm');
verifyEqual(testCase,hs.beta_formula,'HS');
verifyEqual(testCase,hs.beta_safeguard,'nonneg');
verifyEqual(testCase,ls.direction,'twoterm');
verifyEqual(testCase,ls.beta_formula,'LS');
verifyEqual(testCase,ls.beta_safeguard,'nonneg');
verifyEqual(testCase,hs.qp_mode,'corrected');
verifyEqual(testCase,ls.line_search_mode,'validated_strong');
end

function testExtensionConfigurationIsExactlyThirteenThousandTwoHundredRuns(testCase)
cfg = extension_046_config(testCase.TestData.root,tempname);

verifyEqual(testCase,cfg.campaign_id,'unsafeguarded-hs-ls-046');
verifyEqual(testCase,string(cfg.methods),["HS+" "LS+"]);
verifyEqual(testCase,cfg.mode,'paper_r2');
verifyEqual(testCase,cfg.trials,1:100);
verifyEqual(testCase,cfg.max_iter,5000);
verifyEqual(testCase,cfg.chunk_size,100);
verifyEqual(testCase,cfg.parallel_workers,8);
verifyTrue(testCase,endsWith(string(cfg.reference_store_root), ...
    fullfile('full_campaign','preflight','chunk_100')));

catalog = full_campaign_catalog(testCase.TestData.root);
manifest = full_campaign_manifest(cfg,cfg.chunk_size,catalog);
verifyEqual(testCase,numel(manifest.expected_run_keys),13200);
verifyEqual(testCase,numel(unique(string(manifest.expected_run_keys))),13200);
keys = string(manifest.expected_run_keys);
verifyTrue(testCase,all(startsWith(keys,"paper_r2__HS+__") | ...
    startsWith(keys,"paper_r2__LS+__")));
end

function testCorrectedFallbackPoliciesAreMeasured(testCase)
qZero = struct('p',5,'f_x_v',-2,'f_xnext_d',1+eps/4, ...
    'f_x_d',1,'gamma',4);
[hsRaw,hs] = beta_formula('HS',qZero,'twoterm','corrected',1);
qLsZero = qZero;
qLsZero.f_x_d = eps/4;
[lsRaw,ls] = beta_formula('LS',qLsZero,'twoterm','corrected',1);

verifyEqual(testCase,hsRaw,0);
verifyEqual(testCase,hs.fallback_policy, ...
    'hs_scale_aware_zero_to_steepest');
verifyFalse(testCase,hs.nonfinite_reset);
verifyEqual(testCase,lsRaw,0);
verifyEqual(testCase,ls.fallback_policy,'scale_aware_zero_to_zero');
verifyFalse(testCase,ls.nonfinite_reset);

qOverflow = struct('p',realmax,'f_x_v',-1, ...
    'f_xnext_d',2*realmin,'f_x_d',0,'gamma',1);
[overflowRaw,overflow] = beta_formula('HS',qOverflow, ...
    'twoterm','legacy',1);
verifyEqual(testCase,overflowRaw,0);
verifyTrue(testCase,overflow.nonfinite_reset);
verifyEqual(testCase,overflow.fallback_policy,'nonfinite_to_zero');
verifyTrue(testCase,isinf(overflow.raw_before_reset));
end

function testPayloadRetainsFallbackPolicyEventsWithoutChangingSharedSchema(testCase)
cfg = extension_046_config(testCase.TestData.root,tempname);
cfg.max_iter = 2;
catalog = full_campaign_catalog(testCase.TestData.root);
entry = catalog(strcmp({catalog.problem},'BK1'));
[runs,iterations,extras] = build_full_campaign_payload(entry,'HS+',1,cfg);

contract = full_campaign_retention_contract();
verifyTrue(testCase,all(ismember(contract.runs,runs.Properties.VariableNames)));
verifyTrue(testCase,all(ismember(contract.iterations, ...
    iterations.Properties.VariableNames)));
verifyTrue(testCase,isfield(extras,'beta_fallback_events'));
verifyEqual(testCase,extras.beta_fallback_events.Properties.VariableNames, ...
    {'run_key','k','beta_formula','policy','denominator','numerator', ...
    'zero_tolerance','raw_before_reset','nonfinite_reset'});
end

function testPairingVerifierAcceptsExactStartsAndRejectsOneChangedCoordinate(testCase)
catalog = full_campaign_catalog(testCase.TestData.root);
catalog = catalog(1:2);
trials = 1:3;
reference = table();
for k = 1:numel(catalog)
    starts = catalog(k).starts();
    for trial = trials
        reference = [reference;table(string(catalog(k).problem),trial, ... %#ok<AGROW>
            {starts(:,trial)},'VariableNames',{'problem','start_id','x0'})];
    end
end

report = verify_extension_046_pairing(reference,catalog,trials);
verifyTrue(testCase,all(report.exact));
verifyEqual(testCase,sum(report.starts_checked),6);

reference.x0{end}(1) = reference.x0{end}(1)+1;
verifyError(testCase,@() verify_extension_046_pairing( ...
    reference,catalog,trials),'mcode:UnpairedExtension046');
end

function testFallbackPolicySummaryAllowsAnEmptyD1D10Subset(testCase)
eventRows = table("HS+","tier1","hs_scale_aware_zero_to_steepest",2, ...
    'VariableNames',{'method','set_name','policy','k'});

policies = extension_046_fallback_policies(eventRows);

verifyEqual(testCase,height(policies),1);
verifyEqual(testCase,policies.method,"HS+");
verifyEqual(testCase,policies.scope,"all66");
verifyEqual(testCase,policies.count,1);
end
