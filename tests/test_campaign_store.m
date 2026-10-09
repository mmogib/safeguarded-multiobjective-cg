function tests = test_campaign_store
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testInitializeFreezesManifest(testCase)
storeRoot = tempname;
cleanup = onCleanup(@() remove_if_present(storeRoot));
manifest = fixture_manifest();

created = campaignstore.initialize(storeRoot,manifest);

verifyTrue(testCase,isfolder(fullfile(storeRoot,'blocks')));
verifyTrue(testCase,isfile(fullfile(storeRoot,'campaign_manifest.json')));
verifyEqual(testCase,string(created.campaign_id),"fixture-campaign");
verifyEqual(testCase,created.chunk_size,25);
verifyEqual(testCase,string(created.retention_profile),"fixture_v1");
verifyNotEmpty(testCase,created.created_utc);

same = campaignstore.initialize(storeRoot,manifest);
verifyEqual(testCase,same,created);

changed = manifest;
changed.chunk_size = 10;
verifyError(testCase,@() campaignstore.initialize(storeRoot,changed), ...
    'campaignstore:ManifestMismatch');
end

function testInitializeRejectsDuplicateExpectedKeys(testCase)
storeRoot = tempname;
cleanup = onCleanup(@() remove_if_present(storeRoot));
manifest = fixture_manifest();
manifest.expected_run_keys = ["run-1" "run-1"];

verifyError(testCase,@() campaignstore.initialize(storeRoot,manifest), ...
    'campaignstore:DuplicateExpectedRunKey');
end

function testBaselineContractIncludesAcceptedPrimitiveSet(testCase)
contract = campaignstore.baseline_retention_contract();

verifyTrue(testCase,all(ismember({'run_key','start_id','x0','x_final', ...
    'F_final','status','iterations','vector_F','vector_J'},contract.runs)));
verifyTrue(testCase,all(ismember({'run_key','k','accepted_step','theta', ...
    'v_norm','raw_beta','raw_lambda','p_norm','alignment', ...
    'correction_ratio','direction_growth','direction_angle'}, ...
    contract.iterations)));

storeRoot = tempname;
cleanup = onCleanup(@() remove_if_present(storeRoot));
manifest = fixture_manifest();
manifest.retention_profile = 'baseline_v1';
manifest.retention_contract = contract;
campaignstore.initialize(storeRoot,manifest);

remove_if_present(storeRoot);
manifest.retention_contract.iterations(strcmp( ...
    manifest.retention_contract.iterations,'raw_beta')) = [];
verifyError(testCase,@() campaignstore.initialize(storeRoot,manifest), ...
    'campaignstore:InvalidBaselineContract');
end

function testWriteInspectAndResumeUseImmutableBlocks(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs,iterations,extras] = fixture_block_rows(["run-1" "run-2"]);

receipt = campaignstore.write_block(storeRoot, ...
    'armA_problemA_trials001-002',runs,iterations,extras);

expectedPath = fullfile(storeRoot,'blocks', ...
    'block_armA_problemA_trials001-002.mat');
verifyEqual(testCase,string(receipt.path),string(expectedPath));
verifyTrue(testCase,isfile(expectedPath));
verifyEqual(testCase,receipt.run_count,2);
verifyEqual(testCase,strlength(string(receipt.sha256)),64);

inventory = campaignstore.inspect(storeRoot);
verifyEqual(testCase,height(inventory.blocks),1);
verifyEqual(testCase,inventory.blocks.block_key,"armA_problemA_trials001-002");
verifyEqual(testCase,sort(inventory.run_keys),["run-1";"run-2"]);
verifyEqual(testCase,campaignstore.missing_keys(storeRoot),"run-3");

loaded = load(expectedPath,'runs','iterations','extras','blockMetadata');
verifyEqual(testCase,loaded.runs,runs);
verifyEqual(testCase,loaded.iterations,iterations);
verifyEqual(testCase,loaded.extras.line_trials,extras.line_trials);
verifyEqual(testCase,string(loaded.blockMetadata.configuration_hash),"abc123");

orphan = fullfile(storeRoot,'blocks','unfinished.tmp.mat');
save(orphan,'runs');
inventoryAfterOrphan = campaignstore.inspect(storeRoot);
verifyEqual(testCase,height(inventoryAfterOrphan.blocks),1);

verifyError(testCase,@() campaignstore.write_block(storeRoot, ...
    'armA_problemA_trials001-002',runs,iterations,extras), ...
    'campaignstore:BlockExists');
end

function testFileSha256UsesStreamingDigest(testCase)
work = tempname;
mkdir(work);
cleanup = onCleanup(@() remove_if_present(work));
path = fullfile(work,'abc.txt');
fid = fopen(path,'wb');
fwrite(fid,uint8('abc'),'uint8');
fclose(fid);

digest = campaignstore.file_sha256(path);

verifyEqual(testCase,digest, ...
    'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD');
end

function testWriteRejectsKeysOutsideManifestAndExistingShards(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs,iterations,extras] = fixture_block_rows("run-1");
campaignstore.write_block(storeRoot,'first',runs,iterations,extras);

[outsideRuns,outsideIterations,outsideExtras] = fixture_block_rows("run-9");
verifyError(testCase,@() campaignstore.write_block(storeRoot,'outside', ...
    outsideRuns,outsideIterations,outsideExtras), ...
    'campaignstore:UnexpectedRunKey');

[overlapRuns,overlapIterations,overlapExtras] = ...
    fixture_block_rows(["run-1" "run-2"]);
verifyError(testCase,@() campaignstore.write_block(storeRoot,'overlap', ...
    overlapRuns,overlapIterations,overlapExtras), ...
    'campaignstore:DuplicateRunKey');

[secondRuns,badIterations,secondExtras] = fixture_block_rows("run-2");
badIterations.run_key(:) = "run-3";
verifyError(testCase,@() campaignstore.write_block(storeRoot,'bad-iteration', ...
    secondRuns,badIterations,secondExtras), ...
    'campaignstore:ForeignIterationRunKey');
end

function testWriteEnforcesDeclaredRetentionContract(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs,iterations,extras] = fixture_block_rows("run-1");
iterations.raw_beta = [];

verifyError(testCase,@() campaignstore.write_block(storeRoot,'missing-raw', ...
    runs,iterations,extras),'campaignstore:RetentionContractViolation');
end

function testInspectRejectsWrongConfigurationAndTruncatedShard(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs,iterations,extras] = fixture_block_rows("run-1");
blocks = fullfile(storeRoot,'blocks');
blockMetadata = struct('block_key','wrong-config', ...
    'configuration_hash','wrong','schema_version',1, ...
    'run_keys',{{'run-1'}},'run_count',1);
save(fullfile(blocks,'block_wrong-config.mat'), ...
    'runs','iterations','extras','blockMetadata','-v7.3');

verifyError(testCase,@() campaignstore.inspect(storeRoot), ...
    'campaignstore:BlockConfigurationMismatch');

delete(fullfile(blocks,'block_wrong-config.mat'));
blockMetadata.configuration_hash = 'abc123';
blockMetadata.schema_version = 99;
blockMetadata.block_key = 'wrong-schema';
save(fullfile(blocks,'block_wrong-schema.mat'), ...
    'runs','iterations','extras','blockMetadata','-v7.3');
verifyError(testCase,@() campaignstore.inspect(storeRoot), ...
    'campaignstore:BlockSchemaMismatch');

delete(fullfile(blocks,'block_wrong-schema.mat'));
truncated = fullfile(blocks,'block_truncated.mat');
fid = fopen(truncated,'wb');
fwrite(fid,uint8('not a MAT file'),'uint8');
fclose(fid);
verifyError(testCase,@() campaignstore.inspect(storeRoot), ...
    'campaignstore:InvalidBlock');
end

function testIndexStreamingReadAndSealUseTheSameShards(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs12,iterations12,extras12] = fixture_block_rows(["run-1" "run-2"]);
[runs3,iterations3,extras3] = fixture_block_rows("run-3");
campaignstore.write_block(storeRoot,'z-second',runs12,iterations12,extras12);
campaignstore.write_block(storeRoot,'a-first',runs3,iterations3,extras3);

index = campaignstore.rebuild_index(storeRoot);

verifyTrue(testCase,isfile(fullfile(storeRoot,'checkpoint_index.csv')));
verifyEqual(testCase,index.block_key,["a-first";"z-second"]);
verifyEqual(testCase,index.run_count,[1;2]);
verifyTrue(testCase,all(strlength(index.sha256)==64));

allRuns = campaignstore.load_table(storeRoot,'runs');
allIterations = campaignstore.load_table(storeRoot,'iterations');
allLineTrials = campaignstore.load_table(storeRoot,'line_trials');
verifyEqual(testCase,allRuns.run_key,["run-3";"run-1";"run-2"]);
verifyEqual(testCase,height(allIterations),6);
verifyEqual(testCase,allLineTrials.run_key,["run-3";"run-1";"run-2"]);

seal = campaignstore.seal(storeRoot);
archivePath = fullfile(storeRoot,'archive_manifest.csv');
verifyTrue(testCase,isfile(archivePath));
archive = readtable(archivePath,'TextType','string');
verifyEqual(testCase,height(archive),2);
verifyEqual(testCase,archive.block_key,index.block_key);
verifyTrue(testCase,all(archive.campaign_digest==string(seal.campaign_digest)));
verifyEqual(testCase,strlength(string(seal.campaign_digest)),64);
verifyEqual(testCase,campaignstore.missing_keys(storeRoot),strings(0,1));

verifyError(testCase,@() campaignstore.write_block(storeRoot,'after-seal', ...
    runs3,iterations3,extras3),'campaignstore:StoreSealed');
end

function testIndexWriterReliablyReplacesAnExistingCache(testCase)
work = tempname;
mkdir(work);
cleanup = onCleanup(@() remove_if_present(work));
path = fullfile(work,'checkpoint_index.csv');

for k = 1:25
    expected = table("block-"+string(k),k, ...
        'VariableNames',{'block_key','run_count'});
    campaignstore.write_index_atomic(path,expected);
    actual = readtable(path,'TextType','string','Delimiter',',', ...
        'VariableNamingRule','preserve');
    verifyEqual(testCase,actual,expected);
end
end

function testSealRejectsAnIncompleteCampaign(testCase)
storeRoot = initialized_store();
cleanup = onCleanup(@() remove_if_present(storeRoot));
[runs,iterations,extras] = fixture_block_rows("run-1");
campaignstore.write_block(storeRoot,'partial',runs,iterations,extras);

verifyError(testCase,@() campaignstore.seal(storeRoot), ...
    'campaignstore:IncompleteCampaign');
end

function manifest = fixture_manifest()
manifest = struct('schema_version',1,'campaign_id','fixture-campaign', ...
    'configuration_hash','abc123','chunk_size',25, ...
    'retention_profile','fixture_v1', ...
    'retention_contract',struct( ...
    'runs',{{'run_key','iterations'}}, ...
    'iterations',{{'run_key','k','raw_beta'}}, ...
    'extras',struct('line_trials',{{'run_key','alpha'}})), ...
    'expected_run_keys',["run-1" "run-2" "run-3"]);
end

function root = initialized_store()
root = tempname;
campaignstore.initialize(root,fixture_manifest());
end

function [runs,iterations,extras] = fixture_block_rows(keys)
keys = string(keys(:));
runs = table(keys,(1:numel(keys))', ...
    'VariableNames',{'run_key','iterations'});
iterationKeys = reshape(repelem(keys,2),[],1);
iterations = table(iterationKeys,repmat((1:2)',numel(keys),1), ...
    (1:numel(iterationKeys))'/10, ...
    'VariableNames',{'run_key','k','raw_beta'});
extras = struct('line_trials', ...
    table(keys,ones(numel(keys),1), ...
    'VariableNames',{'run_key','alpha'}));
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
