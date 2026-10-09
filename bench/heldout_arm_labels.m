function labels = heldout_arm_labels(rows)
%HELDOUT_ARM_LABELS Stable labels for method/eta campaign arms.

labels = rows.method;
for rowIndex = 1:height(rows)
    if ~isnan(rows.eta(rowIndex))
        etaText = replace(string(sprintf('%.15g',rows.eta(rowIndex))),'.','p');
        labels(rowIndex) = rows.method(rowIndex)+"_eta"+etaText;
    end
end
end
