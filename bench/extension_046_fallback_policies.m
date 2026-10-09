function policies = extension_046_fallback_policies(eventRows)
%EXTENSION_046_FALLBACK_POLICIES Count fallback policies by report scope.

variableNames = {'method','scope','policy','count'};
policies = table('Size',[0 4], ...
    'VariableTypes',{'string','string','string','double'}, ...
    'VariableNames',variableNames);
if isempty(eventRows)
    return
end

scopes = ["all66";"D1-D10"];
for s = 1:numel(scopes)
    use = true(height(eventRows),1);
    if scopes(s)=="D1-D10"
        use = eventRows.set_name=="NC10";
    end
    block = eventRows(use,:);
    if isempty(block)
        continue
    end
    [group,method,policy] = findgroups(block.method,block.policy);
    count = splitapply(@numel,block.k,group);
    policies = [policies;table(method,repmat(scopes(s),numel(count),1), ...
        policy,count,'VariableNames',variableNames)]; %#ok<AGROW>
end
end
