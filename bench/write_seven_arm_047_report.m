function write_seven_arm_047_report(report,outputDir)
%WRITE_SEVEN_ARM_047_REPORT Write exchange-047 reduction artifacts.

if ~isfolder(outputDir), mkdir(outputDir); end
tableNames = fieldnames(report.tables);
for k = 1:numel(tableNames)
    writetable(report.tables.(tableNames{k}), ...
        fullfile(outputDir,[tableNames{k} '.csv']));
end
writetable(report.profiles.values,fullfile(outputDir,'profile_values.csv'));
writetable(report.profiles.limits,fullfile(outputDir,'profile_limits.csv'));
writetable(report.profiles.curves,fullfile(outputDir,'profile_curves.csv'));
writetable(report.profiles.downsampling, ...
    fullfile(outputDir,'profile_downsampling.csv'));
writetable(report.styles,fullfile(outputDir,'profile_styles.csv'));
write_profile_styles(report.styles,fullfile(outputDir,'profile_styles.tex'));
writetable(report.front_metrics,fullfile(outputDir,'front_metrics.csv'));
writetable(report.analytic_front_distance, ...
    fullfile(outputDir,'analytic_front_distance.csv'));
write_full_campaign_front_quality(report.front_quality,outputDir);
write_profile_definitions(fullfile(outputDir,'profile_definitions.txt'));
save(fullfile(outputDir,'results_report.mat'),'report','-v7.3');
save(fullfile(outputDir,'seven_arm_047_report.mat'),'report','-v7.3');
end

function write_profile_definitions(path)
lines = [ ...
    "Instances are problem/start pairs; failures are retained."; ...
    "Iterations and component F/J evaluations are shifted by one."; ...
    "Each ratio uses the best successful arm on the same instance."; ...
    "For each slice and metric, r_M = 2*max(4, largest finite ratio)."; ...
    "The plateau is the success fraction, the left limit at r_M."; ...
    "Curves are right-continuous exact breakpoints, reduced to at most 300 points."; ...
    "profile_downsampling.csv reports the measured maximum vertical deviation."; ...
    "profile_styles.csv uses color and line pattern as redundant encodings." ...
    ];
fid = fopen(path,'w','n','UTF-8');
if fid<0, error('mcode:ReportWriteFailed','Cannot write %s.',path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',lines);
end

function write_profile_styles(styles,path)
fid = fopen(path,'w','n','UTF-8');
if fid<0, error('mcode:ReportWriteFailed','Cannot write %s.',path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%% Color-vision-friendly colors with redundant line patterns.\n');
for k = 1:height(styles)
    fprintf(fid,'\\definecolor{%s}{HTML}{%s}\n', ...
        styles.pgfplots_color_name(k),erase(styles.color_hex(k),'#'));
end
fprintf(fid,'\\pgfplotsset{\n');
for k = 1:height(styles)
    separator = ',';
    if k==height(styles), separator = ''; end
    fprintf(fid,'  %s/.style={%s,thick}%s %% %s\n', ...
        styles.pgfplots_style_name(k),styles.pgfplots_options(k), ...
        separator,styles.method(k));
end
fprintf(fid,'}\n');
end
