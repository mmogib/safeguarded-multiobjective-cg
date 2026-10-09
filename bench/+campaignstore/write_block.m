function receipt = write_block(root,blockKey,runs,iterations,extras)
%WRITE_BLOCK Atomically add one immutable campaign shard.

if nargin < 5, extras = struct(); end
manifestPath = fullfile(root,'campaign_manifest.json');
if ~isfile(manifestPath)
    error('campaignstore:MissingManifest','Campaign manifest is missing.');
end
if isfile(fullfile(root,'archive_manifest.csv'))
    error('campaignstore:StoreSealed','A sealed campaign cannot accept blocks.');
end
manifest = jsondecode(fileread(manifestPath));
blockKey = char(string(blockKey));
if isempty(regexp(blockKey,'^[A-Za-z0-9][A-Za-z0-9_.-]*$','once'))
    error('campaignstore:InvalidBlockKey','Block key is not filesystem-safe.');
end
blocksDir = fullfile(root,'blocks');
finalPath = fullfile(blocksDir,['block_' blockKey '.mat']);
if isfile(finalPath)
    error('campaignstore:BlockExists','Block already exists: %s',blockKey);
end
if ~istable(runs) || ~ismember('run_key',runs.Properties.VariableNames)
    error('campaignstore:InvalidRuns','Runs must be a table with run_key.');
end
contract = manifest.retention_contract;
require_columns(runs,contract.runs,'runs');
require_columns(iterations,contract.iterations,'iterations');
runKeys = string(runs.run_key(:));
if isempty(runKeys) || any(ismissing(runKeys) | strlength(runKeys)==0) || ...
        numel(unique(runKeys)) ~= numel(runKeys)
    error('campaignstore:InvalidRuns','Block run keys must be nonempty and unique.');
end
expected = string(manifest.expected_run_keys(:));
if any(~ismember(runKeys,expected))
    error('campaignstore:UnexpectedRunKey', ...
        'Block contains a run key outside the campaign manifest.');
end
inventory = campaignstore.inspect(root);
if any(ismember(runKeys,inventory.run_keys))
    error('campaignstore:DuplicateRunKey', ...
        'Block overlaps an existing run key.');
end
validate_child_table(iterations,runKeys,'campaignstore:ForeignIterationRunKey');
if ~isstruct(extras) || ~isscalar(extras)
    error('campaignstore:InvalidExtras','Extras must be a scalar struct.');
end
extraNames = fieldnames(extras);
for k = 1:numel(extraNames)
    value = extras.(extraNames{k});
    if ~istable(value)
        error('campaignstore:InvalidExtras','Every extra payload must be a table.');
    end
    if ismember('run_key',value.Properties.VariableNames)
        validate_child_table(value,runKeys,'campaignstore:ForeignExtraRunKey');
    end
end
requiredExtras = fieldnames(contract.extras);
for k = 1:numel(requiredExtras)
    name = requiredExtras{k};
    if ~isfield(extras,name)
        error('campaignstore:RetentionContractViolation', ...
            'Required extra table %s is missing.',name);
    end
    require_columns(extras.(name),contract.extras.(name),name);
end
blockMetadata = struct('block_key',blockKey, ...
    'configuration_hash',char(string(manifest.configuration_hash)), ...
    'schema_version',double(manifest.schema_version), ...
    'run_keys',{cellstr(runKeys)},'run_count',numel(runKeys), ...
    'created_utc',char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')));
temporary = [tempname(blocksDir) '.tmp.mat'];
cleanup = onCleanup(@() delete_if_present(temporary));
save(temporary,'blockMetadata','runs','iterations','extras','-v7.3');
try
    check = load(temporary,'blockMetadata');
catch cause
    throwAsCaller(MException('campaignstore:BlockWriteFailed', ...
        'Temporary block validation failed: %s',cause.message));
end
if ~isequaln(check.blockMetadata,blockMetadata)
    error('campaignstore:BlockWriteFailed', ...
        'Temporary block metadata changed during serialization.');
end
install_new_block(temporary,finalPath,blockMetadata);
details = dir(finalPath);
receipt = struct('block_key',blockKey,'path',finalPath, ...
    'run_count',numel(runKeys),'file_bytes',details.bytes, ...
    'sha256',campaignstore.file_sha256(finalPath));
campaignstore.update_index(root,receipt,inventory.blocks.block_key);
end

function install_new_block(source,destination,expectedMetadata)
% Immutable destinations are always new.  Avoid forced replacement because
% it is unreliable for Dropbox reparse points and would weaken immutability.
message = '';
for attempt = 1:5
    [ok,message] = movefile(source,destination);
    if ok || installed_block_matches(destination,expectedMetadata)
        return
    end
    if ~isfile(source)
        break
    end
    pause(0.05*2^(attempt-1));
end
error('campaignstore:BlockWriteFailed','%s',message);
end

function tf = installed_block_matches(path,expectedMetadata)
tf = false;
if ~isfile(path), return; end
try
    check = load(path,'blockMetadata');
    tf = isequaln(check.blockMetadata,expectedMetadata);
catch
end
end

function validate_child_table(value,runKeys,errorId)
if ~istable(value)
    error(errorId,'Iteration payload must be a table.');
end
if isempty(value), return; end
if ~ismember('run_key',value.Properties.VariableNames) || ...
        any(~ismember(string(value.run_key(:)),runKeys))
    error(errorId,'Payload contains a run key outside its block.');
end
end

function require_columns(value,required,label)
if ~istable(value)
    error('campaignstore:RetentionContractViolation', ...
        'Required payload %s is not a table.',label);
end
required = cellstr(string(required(:)));
missing = setdiff(required,value.Properties.VariableNames,'stable');
if ~isempty(missing)
    error('campaignstore:RetentionContractViolation', ...
        'Payload %s is missing required columns: %s.', ...
        label,strjoin(missing,', '));
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
