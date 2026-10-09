function comparison = compare_calibration_control(rows, controlEta, selectedEta)
%COMPARE_CALIBRATION_CONTROL Compare selected and control median work counts.

metrics = ["iterations" "component_F" "component_J"];
keys = unique(rows(:,{'method','problem'}),'rows','stable');
rowCount = height(keys)*numel(metrics);
comparison = table('Size',[rowCount 6], ...
    'VariableTypes',{'string','string','string','double','double','double'}, ...
    'VariableNames',{'method','problem','metric','control_median', ...
    'selected_median','selected_over_control'});

outputIndex = 0;
for keyIndex = 1:height(keys)
    keyRows = rows.method == keys.method(keyIndex) & ...
        rows.problem == keys.problem(keyIndex) & rows.status == "converged";
    for metric = metrics
        outputIndex = outputIndex+1;
        control = rows.(metric)(keyRows & rows.eta == controlEta);
        selected = rows.(metric)(keyRows & rows.eta == selectedEta);
        comparison.method(outputIndex) = keys.method(keyIndex);
        comparison.problem(outputIndex) = keys.problem(keyIndex);
        comparison.metric(outputIndex) = metric;
        comparison.control_median(outputIndex) = median_or_nan(control);
        comparison.selected_median(outputIndex) = median_or_nan(selected);
        comparison.selected_over_control(outputIndex) = safe_ratio( ...
            comparison.selected_median(outputIndex), ...
            comparison.control_median(outputIndex));
    end
end
end

function value = median_or_nan(values)
if isempty(values)
    value = NaN;
else
    value = median(values);
end
end

function value = safe_ratio(numerator,denominator)
if denominator == 0
    value = NaN;
else
    value = numerator/denominator;
end
end
