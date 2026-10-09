function inventory = inspect(root,verifyDigests)
%INSPECT Validate shard metadata and return the store inventory.

if nargin < 2, verifyDigests = false; end
manifestPath = fullfile(root,'campaign_manifest.json');
if ~isfile(manifestPath)
    error('campaignstore:MissingManifest','Campaign manifest is missing.');
end
manifest = jsondecode(fileread(manifestPath));
expected = string(manifest.expected_run_keys(:));
files = dir(fullfile(root,'blocks','block_*.mat'));
[~,order] = sort(string({files.name}));
files = files(order);
n = numel(files);
blockKey = strings(n,1);
path = strings(n,1);
runCount = zeros(n,1);
fileBytes = zeros(n,1);
sha256 = strings(n,1);
allKeys = strings(0,1);
for k = 1:n
    blockPath = fullfile(files(k).folder,files(k).name);
    try
        loaded = load(blockPath,'blockMetadata');
    catch cause
        throwAsCaller(MException('campaignstore:InvalidBlock', ...
            'Cannot read block %s: %s',blockPath,cause.message));
    end
    if ~isfield(loaded,'blockMetadata')
        error('campaignstore:InvalidBlock', ...
            'Block %s has no blockMetadata.',blockPath);
    end
    metadata = loaded.blockMetadata;
    required = {'block_key','configuration_hash','schema_version', ...
        'run_keys','run_count'};
    if ~isstruct(metadata) || ~all(isfield(metadata,required))
        error('campaignstore:InvalidBlock', ...
            'Block %s has invalid metadata.',blockPath);
    end
    key = string(metadata.block_key);
    expectedName = "block_"+key+".mat";
    if string(files(k).name) ~= expectedName
        error('campaignstore:InvalidBlock', ...
            'Block filename does not match its key: %s.',blockPath);
    end
    if string(metadata.configuration_hash) ~= ...
            string(manifest.configuration_hash)
        error('campaignstore:BlockConfigurationMismatch', ...
            'Block %s has the wrong configuration hash.',blockPath);
    end
    if double(metadata.schema_version) ~= double(manifest.schema_version)
        error('campaignstore:BlockSchemaMismatch', ...
            'Block %s has the wrong schema version.',blockPath);
    end
    keys = string(metadata.run_keys(:));
    if numel(keys) ~= metadata.run_count || ...
            numel(unique(keys)) ~= numel(keys) || ...
            any(~ismember(keys,expected))
        error('campaignstore:InvalidBlock', ...
            'Block %s has invalid run keys.',blockPath);
    end
    if any(ismember(keys,allKeys))
        error('campaignstore:DuplicateRunKey', ...
            'A run key occurs in more than one shard.');
    end
    allKeys = [allKeys;keys]; %#ok<AGROW>
    blockKey(k) = key;
    path(k) = string(blockPath);
    runCount(k) = numel(keys);
    fileBytes(k) = files(k).bytes;
    if verifyDigests
        sha256(k) = string(campaignstore.file_sha256(blockPath));
    end
end
blocks = table(blockKey,path,runCount,fileBytes,sha256, ...
    'VariableNames',{'block_key','path','run_count','file_bytes','sha256'});
inventory = struct('manifest',manifest,'blocks',blocks, ...
    'run_keys',allKeys);
end
