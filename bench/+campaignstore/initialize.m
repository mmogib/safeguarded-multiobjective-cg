function stored = initialize(root,manifest)
%INITIALIZE Create or validate an immutable campaign-store manifest.

requested = normalize_manifest(manifest);
manifestPath = fullfile(root,'campaign_manifest.json');
if isfile(manifestPath)
    stored = jsondecode(fileread(manifestPath));
    existing = normalize_manifest(stored);
    if ~strcmp(canonical_json(existing),canonical_json(requested))
        error('campaignstore:ManifestMismatch', ...
            'Existing campaign manifest differs from the requested manifest.');
    end
    return
end

if ~isfolder(root), mkdir(root); end
blocks = fullfile(root,'blocks');
if ~isfolder(blocks), mkdir(blocks); end
stored = requested;
stored.created_utc = char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
write_text_atomic(manifestPath,jsonencode(stored));
end

function manifest = normalize_manifest(manifest)
required = {'schema_version','campaign_id','configuration_hash', ...
    'chunk_size','retention_profile','retention_contract', ...
    'expected_run_keys'};
if ~isstruct(manifest) || ~isscalar(manifest)
    error('campaignstore:InvalidManifest','Manifest must be a scalar struct.');
end
for k = 1:numel(required)
    if ~isfield(manifest,required{k})
        error('campaignstore:InvalidManifest', ...
            'Manifest is missing required field %s.',required{k});
    end
end
if isfield(manifest,'created_utc')
    manifest = rmfield(manifest,'created_utc');
end
manifest.schema_version = double(manifest.schema_version);
manifest.campaign_id = char(string(manifest.campaign_id));
manifest.configuration_hash = char(string(manifest.configuration_hash));
manifest.chunk_size = double(manifest.chunk_size);
manifest.retention_profile = char(string(manifest.retention_profile));
manifest.retention_contract = normalize_contract(manifest.retention_contract);
if strcmp(manifest.retention_profile,'baseline_v1')
    validate_baseline_contract(manifest.retention_contract);
end
keys = string(manifest.expected_run_keys(:));
if any(ismissing(keys) | strlength(keys)==0)
    error('campaignstore:InvalidManifest','Expected run keys must be nonempty.');
end
if numel(unique(keys)) ~= numel(keys)
    error('campaignstore:DuplicateExpectedRunKey', ...
        'Expected run keys must be unique.');
end
if ~isscalar(manifest.schema_version) || manifest.schema_version < 1 || ...
        fix(manifest.schema_version) ~= manifest.schema_version || ...
        isempty(manifest.campaign_id) || isempty(manifest.configuration_hash) || ...
        ~isscalar(manifest.chunk_size) || manifest.chunk_size < 1 || ...
        fix(manifest.chunk_size) ~= manifest.chunk_size || ...
        isempty(manifest.retention_profile)
    error('campaignstore:InvalidManifest','Manifest fields are invalid.');
end
manifest.expected_run_keys = cellstr(keys);
manifest = orderfields(manifest);
end

function contract = normalize_contract(contract)
if ~isstruct(contract) || ~isscalar(contract) || ...
        ~all(isfield(contract,{'runs','iterations','extras'})) || ...
        ~isstruct(contract.extras) || ~isscalar(contract.extras)
    error('campaignstore:InvalidManifest', ...
        'Retention contract must declare runs, iterations, and extras.');
end
contract.runs = normalize_columns(contract.runs);
contract.iterations = normalize_columns(contract.iterations);
names = fieldnames(contract.extras);
for k = 1:numel(names)
    contract.extras.(names{k}) = ...
        normalize_columns(contract.extras.(names{k}));
end
contract.extras = orderfields(contract.extras);
contract = orderfields(contract);
end

function columns = normalize_columns(columns)
columns = string(columns(:));
if isempty(columns) || any(ismissing(columns) | strlength(columns)==0) || ...
        numel(unique(columns)) ~= numel(columns)
    error('campaignstore:InvalidManifest', ...
        'Retention-contract columns must be nonempty and unique.');
end
columns = cellstr(columns);
end

function validate_baseline_contract(contract)
baseline = campaignstore.baseline_retention_contract();
if ~all(ismember(baseline.runs,contract.runs)) || ...
        ~all(ismember(baseline.iterations,contract.iterations))
    error('campaignstore:InvalidBaselineContract', ...
        'baseline_v1 must include every shared run and iteration primitive.');
end
end

function value = canonical_json(value)
value = orderfields(value);
value.expected_run_keys = cellstr(string(value.expected_run_keys(:)));
value = jsonencode(value);
end

function write_text_atomic(path,text)
folder = fileparts(path);
temporary = [tempname(folder) '.tmp'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary,'wt');
if fid < 0
    error('campaignstore:ManifestWriteFailed', ...
        'Could not create temporary manifest file.');
end
fileCleanup = onCleanup(@() fclose_if_open(fid));
fprintf(fid,'%s',text);
fclose(fid);
fid = -1; %#ok<NASGU>
clear fileCleanup
[ok,message] = movefile(temporary,path);
if ~ok
    error('campaignstore:ManifestWriteFailed','%s',message);
end
end

function fclose_if_open(fid)
if fid >= 0
    try
        fclose(fid);
    catch
    end
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
