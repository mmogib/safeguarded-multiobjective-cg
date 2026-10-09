function runs = assemble_seven_arm_047_runs(baseRuns,extensionRuns,expectedPerMethod)
%ASSEMBLE_SEVEN_ARM_047_RUNS Filter, pair, and label copied reporting rows.

if nargin < 3, expectedPerMethod = 6600; end
required = {'run_key','method','problem','start_id','x0'};
if ~all(ismember(required,baseRuns.Properties.VariableNames)) || ...
        ~all(ismember(required,extensionRuns.Properties.VariableNames))
    error('mcode:InvalidSevenArm047Runs', ...
        'Both stores must supply run keys, methods, tasks, and starts.');
end

manifest = seven_arm_047_methods();
parts = cell(height(manifest),1);
for k = 1:height(manifest)
    if manifest.store(k)=="base"
        source = baseRuns;
    else
        source = extensionRuns;
    end
    part = source(source.method==manifest.code_id(k),:);
    taskKey = part.problem+"__"+compose('%06d',part.start_id);
    if height(part)~=expectedPerMethod || numel(unique(taskKey))~=expectedPerMethod
        error('mcode:InvalidSevenArm047Runs', ...
            '%s does not contain the expected unique task set.', ...
            manifest.code_id(k));
    end
    part = sortrows(part,{'problem','start_id'});
    part.code_id = part.method;
    part.method(:) = manifest.display_name(k);
    part.method_order = repmat(manifest.order(k),height(part),1);
    parts{k} = part;
end

reference = parts{1};
for k = 2:numel(parts)
    current = parts{k};
    sameTasks = height(current)==height(reference) && ...
        all(current.problem==reference.problem) && ...
        all(current.start_id==reference.start_id);
    sameStarts = sameTasks && ...
        all(cellfun(@isequaln,current.x0,reference.x0));
    if ~sameStarts
        error('mcode:UnpairedSevenArm047', ...
            'The seven reported methods do not use identical task starts.');
    end
end

runs = vertcat(parts{:});
if numel(unique(runs.run_key))~=height(runs)
    error('mcode:InvalidSevenArm047Runs','Run keys are not unique.');
end
runs = sortrows(runs,{'method_order','problem','start_id'});
end
