function result = load_table(root,name)
%LOAD_TABLE Concatenate one payload table in deterministic shard order.

name = char(string(name));
if isempty(regexp(name,'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('campaignstore:InvalidTableName','Invalid payload table name.');
end
inventory = campaignstore.inspect(root);
result = table();
for k = 1:height(inventory.blocks)
    path = inventory.blocks.path(k);
    if ismember(name,{'runs','iterations'})
        loaded = load(path,name);
        if ~isfield(loaded,name)
            error('campaignstore:MissingPayloadTable', ...
                'Shard %s has no table %s.',path,name);
        end
        value = loaded.(name);
    else
        loaded = load(path,'extras');
        if ~isfield(loaded,'extras') || ~isfield(loaded.extras,name)
            error('campaignstore:MissingPayloadTable', ...
                'Shard %s has no table %s.',path,name);
        end
        value = loaded.extras.(name);
    end
    if ~istable(value)
        error('campaignstore:InvalidPayloadTable', ...
            'Payload %s in shard %s is not a table.',name,path);
    end
    if k == 1, result = value; else, result = [result;value]; end %#ok<AGROW>
end
end
