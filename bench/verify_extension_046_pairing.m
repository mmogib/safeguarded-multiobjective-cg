function report = verify_extension_046_pairing(referenceRuns,catalog,trials)
%VERIFY_EXTENSION_046_PAIRING Match generated starts to sealed TTCGP starts.

required = {'problem','start_id','x0'};
if ~istable(referenceRuns) || ...
        ~all(ismember(required,referenceRuns.Properties.VariableNames))
    error('mcode:InvalidExtension046Reference', ...
        'Reference runs must contain problem, start_id, and x0.');
end
if ismember('method',referenceRuns.Properties.VariableNames)
    referenceRuns = referenceRuns(string(referenceRuns.method)=="TTCGP",:);
end

problems = strings(numel(catalog),1);
startsChecked = zeros(numel(catalog),1);
exact = false(numel(catalog),1);
for k = 1:numel(catalog)
    problems(k) = string(catalog(k).problem);
    starts = catalog(k).starts();
    problemRows = referenceRuns(string(referenceRuns.problem)==problems(k),:);
    problemExact = true;
    for trial = trials
        row = problemRows(problemRows.start_id==trial,:);
        if height(row) ~= 1 || ~iscell(row.x0) || ...
                ~isequaln(row.x0{1},starts(:,trial))
            problemExact = false;
            break
        end
        startsChecked(k) = startsChecked(k)+1;
    end
    exact(k) = problemExact && startsChecked(k)==numel(trials);
end
report = table(problems,startsChecked,exact, ...
    'VariableNames',{'problem','starts_checked','exact'});
if ~all(exact)
    failed = strjoin(cellstr(problems(~exact)),', ');
    error('mcode:UnpairedExtension046', ...
        'Extension starts differ from the sealed TTCGP starts: %s.',failed);
end
end
