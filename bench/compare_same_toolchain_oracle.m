function report = compare_same_toolchain_oracle(rows, snapshotPath)
%COMPARE_SAME_TOOLCHAIN_ORACLE Per-trial A2a comparison with fresh source runs.

methods = {'TTCGP','TTCGH','TTCGL','PRP+','AVHZ+'};
files = {'oracle_TTCGP_output.mat','oracle_TTCGH_output.mat', ...
    'oracle_TTCGL_output.mat','oracle_PRP_output.mat','oracle_AVHZ_output.mat'};
vars2 = {'RloopchuSGTTCGAllHS_2obj','RloopchuSGTTCGAllHS_2obj', ...
    'RloopchuSGTTCGAllHS_2obj','RloopchuPRP_2obj','RloopchuAVHZ_2obj'};
vars3 = {'RloopchuSGTTCGAllHS_3obj','RloopchuSGTTCGAllHS_3obj', ...
    'RloopchuSGTTCGAllHS_3obj','RloopchuPRP_3obj','RloopchuAVHZ_3obj'};
details = empty_details();

for methodIndex = 1:numel(methods)
    selected = find(rows.method == string(methods{methodIndex}));
    if isempty(selected)
        continue
    end
    path = fullfile(snapshotPath, files{methodIndex});
    if ~isfile(path)
        error('mcode:MissingOracleOutput', 'Missing oracle output %s.', path);
    end
    oracle = load(path);
    for rowIndex = selected'
        row = rows(rowIndex,:);
        p = row.legacy_index;
        tr = row.trial;
        expectedSuccess = ~isnan(oracle.Rloopk(tr,p));
        actualSuccess = row.status == "converged";
        iterationMatch = ~expectedSuccess || row.iterations == oracle.Rloopk(tr,p);
        nvMatch = ~expectedSuccess || row.legacy_NV == oracle.Rloopnv(tr,p);
        if p <= 29
            columns = (2*p-1):(2*p);
            expectedF = oracle.(vars2{methodIndex})(tr,columns).';
        else
            local = p-29;
            columns = (3*local-2):(3*local);
            expectedF = oracle.(vars3{methodIndex})(tr,columns).';
        end
        actualF = row.F{1};
        if expectedSuccess
            tolerance = 1e-10+1e-8*max(1,abs(expectedF));
            objectiveMatch = all(abs(actualF-expectedF) <= tolerance);
            objectiveError = max(abs(actualF-expectedF));
        else
            objectiveMatch = true;
            objectiveError = NaN;
        end
        if actualSuccess ~= expectedSuccess || ~iterationMatch || ...
                ~nvMatch || ~objectiveMatch
            details = [details; table(string(methods{methodIndex}), p, tr, ...
                actualSuccess, expectedSuccess, iterationMatch, nvMatch, ...
                objectiveMatch, objectiveError, ...
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
details = table('Size',[0 numel(names)],'VariableTypes',types, ...
    'VariableNames',names);
end
