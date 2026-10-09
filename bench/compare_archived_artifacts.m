function report = compare_archived_artifacts(rows, archiveRoot)
%COMPARE_ARCHIVED_ARTIFACTS Per-trial A2b comparison against saved arrays.

methods = {'TTCGP','TTCGH','TTCGL','PRP+','AVHZ+'};
resultFiles = {'TTCGAllPRP.mat','TTCGAllHS.mat','TTCGAllLS.mat', ...
    'PRP_All41_Results.mat','AVHZ_All41_Results.mat'};
terminalFiles = {'RloopchuTTCGAllPRP.mat','RloopchuTTCGAllHS.mat', ...
    'RloopchuTTCGAllLS.mat','RloopchuPRPAll.mat','RloopchuAVHZAll.mat'};
variables2 = {'RloopchuSGTTCGAllPRP_2obj','RloopchuSGTTCGAllHS_2obj', ...
    'RloopchuSGTTCGAllLS_2obj','RloopchuPRP_2obj','RloopchuAVHZ_2obj'};
variables3 = {'RloopchuSGTTCGAllPRP_3obj','RloopchuSGTTCGAllHS_3obj', ...
    'RloopchuSGTTCGAllLS_3obj','RloopchuPRP_3obj','RloopchuAVHZ_3obj'};

details = empty_details();
for methodIndex = 1:numel(methods)
    selected = find(rows.method == string(methods{methodIndex}));
    if isempty(selected)
        continue
    end
    counts = load(fullfile(archiveRoot, resultFiles{methodIndex}), ...
        'Rloopk', 'Rloopnv');
    terminal = load(fullfile(archiveRoot, terminalFiles{methodIndex}));
    for rowIndex = selected'
        row = rows(rowIndex,:);
        problem = row.legacy_index;
        trial = row.trial;
        expectedSuccess = ~isnan(counts.Rloopk(trial, problem));
        actualSuccess = row.status == "converged";
        iterationMatch = ~expectedSuccess || ...
            row.iterations == counts.Rloopk(trial, problem);
        nvMatch = ~expectedSuccess || ...
            row.legacy_NV == counts.Rloopnv(trial, problem);
        actualF = row.F{1};
        if problem <= 29
            columns = (2*problem-1):(2*problem);
            expectedF = terminal.(variables2{methodIndex})(trial, columns).';
        else
            local = problem-29;
            columns = (3*local-2):(3*local);
            expectedF = terminal.(variables3{methodIndex})(trial, columns).';
        end
        if expectedSuccess
            tolerance = 1e-10+1e-8*max(1, abs(expectedF));
            objectiveMatch = all(abs(actualF-expectedF) <= tolerance);
            objectiveError = max(abs(actualF-expectedF));
        else
            objectiveMatch = true;
            objectiveError = NaN;
        end
        if actualSuccess ~= expectedSuccess || ~iterationMatch || ...
                ~nvMatch || ~objectiveMatch
            details = [details; table(string(methods{methodIndex}), problem, ...
                trial, actualSuccess, expectedSuccess, iterationMatch, ...
                nvMatch, objectiveMatch, objectiveError, ...
                'VariableNames', details.Properties.VariableNames)]; %#ok<AGROW>
        end
    end
end
report = struct('total', height(rows), 'mismatches', height(details), ...
    'details', details);
end

function details = empty_details()
names = {'method','legacy_index','trial','actual_success','expected_success', ...
    'iteration_match','nv_match','objective_match','objective_error'};
types = {'string','double','double','logical','logical','logical','logical', ...
    'logical','double'};
details = table('Size', [0 numel(names)], 'VariableTypes', types, ...
    'VariableNames', names);
end
