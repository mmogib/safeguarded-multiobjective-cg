function report = summarize_seven_arm_047(baseRoot,extensionRoot,outputDir)
%SUMMARIZE_SEVEN_ARM_047 Regenerate the requested seven-arm report.

mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(baseRoot)
    baseRoot = fullfile(mcodeRoot,'data','results','full_campaign', ...
        'preflight','chunk_100');
end
if nargin < 2 || isempty(extensionRoot)
    extensionRoot = fullfile(mcodeRoot,'data','results', ...
        'full_campaign_046_hs_ls','store');
end
if nargin < 3 || isempty(outputDir)
    outputDir = fullfile(mcodeRoot,'data','results', ...
        'full_campaign_047_seven_arms','reports');
end
[runs,iterations] = load_seven_arm_047(baseRoot,extensionRoot);
report = build_seven_arm_047_report(runs,iterations,300);
write_seven_arm_047_report(report,outputDir);
end
