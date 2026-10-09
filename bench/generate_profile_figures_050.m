function report = generate_profile_figures_050(source,reportDir,imageDir)
%GENERATE_PROFILE_FIGURES_050 Reduce and export exchange-050 profiles.

mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(mcodeRoot);
if nargin < 1 || isempty(source)
    source = fullfile(mcodeRoot,'data','results', ...
        'full_campaign_047_seven_arms','reports', ...
        'seven_arm_047_report.mat');
end
if nargin < 2 || isempty(reportDir)
    reportDir = fullfile(mcodeRoot,'data','results', ...
        'profile_figures_050','reports');
end
if nargin < 3 || isempty(imageDir)
    imageDir = fullfile(projectRoot,'paper','imgs');
end

if istable(source)
    sevenArmRatios = source;
else
    if ~isfile(source)
        error('mcode:MissingSevenArm047Report', ...
            'The seven-arm report does not exist: %s',source);
    end
    saved = load(source,'report');
    if ~isfield(saved,'report') || ~isfield(saved.report,'profiles') || ...
            ~isfield(saved.report.profiles,'ratios')
        error('mcode:InvalidSevenArm047Report', ...
            'The source must contain report.profiles.ratios.');
    end
    sevenArmRatios = saved.report.profiles.ratios;
end

report = restricted_profiles_050(sevenArmRatios);
if ~isfolder(reportDir), mkdir(reportDir); end
writetable(report.values,fullfile(reportDir,'profile_050_values.csv'));
writetable(report.limits,fullfile(reportDir,'profile_050_limits.csv'));
writetable(report.crossings,fullfile(reportDir,'profile_050_crossings.csv'));
writetable(report.curves,fullfile(reportDir,'profile_050_curves.csv'));
save(fullfile(reportDir,'profile_050_report.mat'),'report','-v7.3');
export_profile_figures_050(report,imageDir);
end
