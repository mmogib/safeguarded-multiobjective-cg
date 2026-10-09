function slices = full_campaign_slices(runs)
%FULL_CAMPAIGN_SLICES Predeclared applicability and regularity partitions.

names = strings(0,1); masks = cell(0,1);
add("all_reported",true(height(runs),1));
add("theorem_compatible",runs.theorem_compatible);
add("tier1_all",runs.tier==1);
add("tier1_theorem_compatible",runs.tier==1 & runs.theorem_compatible);
add("tier1_unbounded_level_set",runs.tier==1 & runs.unbounded_level_set);
add("tier1_natural_domain",runs.tier==1 & runs.natural_domain);
add("tier2_E2",runs.set_name=="E2");
add("tier2_NL10",runs.set_name=="NL10");
add("tier3_all",runs.tier==3);
add("tier3_primary",runs.tier==3 & runs.tier3_primary);
add("tier3_paired",runs.tier==3 & ~runs.tier3_primary);
for stratum = ["strong" "moderate" "limited" "smooth_control"]
    add("nl10_"+stratum,runs.set_name=="NL10" & ...
        runs.exposure_stratum==stratum);
end
for problem = unique(runs.problem,'stable')'
    add("problem_"+problem,runs.problem==problem);
end
slices = table(names,masks,'VariableNames',{'name','mask'});

    function add(name,mask)
        if any(mask)
            names(end+1,1) = name;
            masks{end+1,1} = logical(mask);
        end
    end
end
