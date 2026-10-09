function [runs,iterations] = load_seven_arm_047(baseRoot,extensionRoot)
%LOAD_SEVEN_ARM_047 Read the two sealed stores without materializing a merge.

for root = string({baseRoot,extensionRoot})
    if ~isfile(fullfile(root,'archive_manifest.csv'))
        error('campaignstore:UnsealedCampaign', ...
            'Seven-arm reporting requires two sealed stores.');
    end
end
baseRuns = campaignstore.load_table(baseRoot,'runs');
extensionRuns = campaignstore.load_table(extensionRoot,'runs');
runs = assemble_seven_arm_047_runs(baseRuns,extensionRuns,6600);

baseIterations = campaignstore.load_table(baseRoot,'iterations');
extensionIterations = campaignstore.load_table(extensionRoot,'iterations');
selectedKeys = runs.run_key;
baseIterations = baseIterations(ismember(baseIterations.run_key,selectedKeys),:);
extensionIterations = extensionIterations( ...
    ismember(extensionIterations.run_key,selectedKeys),:);
iterations = [baseIterations;extensionIterations];
end
