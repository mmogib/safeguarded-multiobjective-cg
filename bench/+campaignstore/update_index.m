function update_index(root,receipt,oldBlockKeys)
%UPDATE_INDEX Append one receipt to a valid cache or rebuild the cache.

path = fullfile(root,'checkpoint_index.csv');
valid = false;
if isfile(path)
    try
        index = readtable(path,'TextType','string','Delimiter',',', ...
            'VariableNamingRule','preserve');
        valid = isequal(sort(index.block_key),sort(string(oldBlockKeys(:)))) && ...
            all(strlength(index.sha256)==64);
    catch
        valid = false;
    end
end
if ~valid
    campaignstore.rebuild_index(root);
    return
end
newRow = table(string(receipt.block_key),string(receipt.path), ...
    receipt.run_count,receipt.file_bytes,string(receipt.sha256), ...
    'VariableNames',index.Properties.VariableNames);
index = [index;newRow];
index = sortrows(index,'block_key');
campaignstore.write_index_atomic(path,index);
end
