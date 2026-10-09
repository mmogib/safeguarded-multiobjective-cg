function catalog = full_campaign_catalog(mcodeRoot)
%FULL_CAMPAIGN_CATALOG Frozen problem and reporting metadata for exchange 041.

if nargin < 1
    mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
end
template = struct('catalog_index',[],'tier',[],'set_name','', ...
    'problem','','problem_index',[],'prob',[],'starts',[], ...
    'unbounded_level_set',false,'natural_domain',false, ...
    'theorem_compatible',false,'exposure_stratum','not_applicable', ...
    'tier3_primary',false,'front_reference_type','pooled_union_relative');
catalog = repmat(template,1,66);
row = 0;

archived = problem_registry(mcodeRoot);
unboundedLabels = {'DGO1','MLF1','TE4','Toi4','Hill','Lov5'};
naturalLabels = {'DGO2','TE6','TE8-15','TE8-30','TE8-50'};
for k = 1:numel(archived)
    row = row+1;
    catalog(row) = make_entry(template,row,1,'tier1', ...
        archived(k).paper_label,k,archived(k), ...
        @() load_initial_points(archived(k),mcodeRoot));
    catalog(row).unbounded_level_set = ...
        ismember(archived(k).paper_label,unboundedLabels);
    catalog(row).natural_domain = ...
        ismember(archived(k).paper_label,naturalLabels);
    catalog(row).theorem_compatible = ...
        ~catalog(row).unbounded_level_set && ~catalog(row).natural_domain;
end

regular = nonlipschitz_problem_registry();
for k = 1:5
    row = row+1;
    catalog(row) = make_entry(template,row,2,'E2', ...
        regular(k).paper_label,k,regular(k), ...
        @() nonlipschitz_starts(regular(k)));
    catalog(row).theorem_compatible = true;
    catalog(row).exposure_stratum = 'primary_e2';
    catalog(row).front_reference_type = 'analytic_exact_front';
end
for k = 6:15
    row = row+1;
    localIndex = regular(k).local_index;
    catalog(row) = make_entry(template,row,2,'NL10', ...
        regular(k).paper_label,localIndex,regular(k), ...
        @() nonlipschitz_starts(regular(k)));
    catalog(row).theorem_compatible = true;
    catalog(row).exposure_stratum = nl10_stratum(localIndex);
end

tier3 = tier3_problem_registry();
primary = [1 5 6 7 9];
for k = 1:numel(tier3)
    row = row+1;
    catalog(row) = make_entry(template,row,3,'NC10', ...
        tier3(k).paper_label,k,tier3(k),@() tier3_starts(tier3(k)));
    catalog(row).tier3_primary = ismember(k,primary);
    if catalog(row).tier3_primary
        catalog(row).exposure_stratum = 'primary_nc10';
    else
        catalog(row).exposure_stratum = 'paired_nc10';
    end
end
end

function entry = make_entry(template,catalogIndex,tier,setName,label,index,prob,starts)
entry = template;
entry.catalog_index = catalogIndex;
entry.tier = tier;
entry.set_name = setName;
entry.problem = label;
entry.problem_index = index;
entry.prob = prob;
entry.starts = starts;
end

function stratum = nl10_stratum(index)
if ismember(index,[6 7])
    stratum = 'strong';
elseif ismember(index,[5 8])
    stratum = 'moderate';
elseif ismember(index,[2 9 10])
    stratum = 'limited';
else
    stratum = 'smooth_control';
end
end

