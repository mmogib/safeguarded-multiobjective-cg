function result = seal(root)
%SEAL Verify exact completion and write the archive hash manifest.

archivePath = fullfile(root,'archive_manifest.csv');
if isfile(archivePath)
    archive = readtable(archivePath,'TextType','string','Delimiter',',', ...
        'VariableNamingRule','preserve');
    if isempty(archive)
        error('campaignstore:InvalidArchiveManifest', ...
            'Archive manifest is empty.');
    end
    result = struct('campaign_digest',char(archive.campaign_digest(1)), ...
        'blocks',height(archive),'runs',sum(archive.run_count));
    return
end
inventory = campaignstore.inspect(root,true);
expected = sort(string(inventory.manifest.expected_run_keys(:)));
actual = sort(inventory.run_keys);
if ~isequal(actual,expected)
    error('campaignstore:IncompleteCampaign', ...
        'Stored run keys do not exactly match the campaign manifest.');
end
archive = inventory.blocks;
relativePath = strings(height(archive),1);
for k = 1:height(archive)
    [~,name,ext] = fileparts(archive.path(k));
    relativePath(k) = "blocks/"+name+ext;
end
archive.path = relativePath;
archive = sortrows(archive,'block_key');
lines = strings(height(archive),1);
for k = 1:height(archive)
    lines(k) = archive.block_key(k)+"|"+archive.sha256(k)+"|"+ ...
        string(archive.run_count(k))+"|"+string(archive.file_bytes(k));
end
digest = text_sha256(strjoin(lines,newline));
archive.configuration_hash = repmat( ...
    string(inventory.manifest.configuration_hash),height(archive),1);
archive.campaign_digest = repmat(string(digest),height(archive),1);
campaignstore.write_index_atomic(archivePath,archive);
campaignstore.write_index_atomic(fullfile(root,'checkpoint_index.csv'), ...
    inventory.blocks);
result = struct('campaign_digest',digest,'blocks',height(archive), ...
    'runs',numel(actual));
end

function digest = text_sha256(text)
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(unicode2native(char(text),'UTF-8'));
bytes = typecast(md.digest(),'uint8');
digest = upper(reshape(dec2hex(bytes,2).',1,[]));
end
