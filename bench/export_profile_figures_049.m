function recipe = export_profile_figures_049(reportPath,outputDir)
%EXPORT_PROFILE_FIGURES_049 Export the eight seven-arm performance profiles.

mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(mcodeRoot);
if nargin < 1 || isempty(reportPath)
    reportPath = fullfile(mcodeRoot,'data','results', ...
        'full_campaign_047_seven_arms','reports', ...
        'seven_arm_047_report.mat');
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(projectRoot,'paper','imgs');
end
if ~isfile(reportPath)
    error('mcode:MissingSevenArm047Report', ...
        'The full-resolution report does not exist: %s',reportPath);
end
if ~isfolder(outputDir), mkdir(outputDir); end

saved = load(reportPath,'report');
if ~isfield(saved,'report') || ~isfield(saved.report,'profiles') || ...
        ~isfield(saved.report.profiles,'ratios')
    error('mcode:InvalidSevenArm047Report', ...
        'The report must contain report.profiles.ratios.');
end
ratios = saved.report.profiles.ratios;
limits = saved.report.profiles.limits;
styles = seven_arm_047_styles();

slices = ["all66";"archived41";"H1-H15";"D1-D10"];
metrics = ["iterations";"component_F_J"];
legendOrder = ["SVPRP+";"VPRP+";"SVHS+";"VHS+"; ...
    "SVLS+";"VLS+";"VSD"];

for sliceIndex = 1:numel(slices)
    for metricIndex = 1:numel(metrics)
        slice = slices(sliceIndex);
        metric = metrics(metricIndex);
        use = ratios.slice==slice & ratios.metric==metric;
        block = ratios(use,:);
        limit = limits(limits.slice==slice & limits.metric==metric,:);
        if isempty(block) || height(limit)~=1
            error('mcode:IncompleteSevenArm047Profiles', ...
                'Missing profile data for %s/%s.',slice,metric);
        end

        curves = cell(numel(legendOrder),1);
        initialRho = zeros(numel(legendOrder),1);

        for methodIndex = 1:numel(legendOrder)
            method = legendOrder(methodIndex);
            methodBlock = block(block.method==method,:);
            if height(methodBlock)~=limit.instances
                error('mcode:UnpairedSevenArm047', ...
                    '%s has %d rather than %d instances in %s/%s.', ...
                    method,height(methodBlock),limit.instances,slice,metric);
            end
            [tau,rho] = exact_profile_curve(methodBlock.ratio, ...
                methodBlock.success,limit.instances, ...
                limit.largest_finite_ratio);
            initialRho(methodIndex) = rho(1);
            curves{methodIndex} = table(tau,rho);
        end

        stem = "profile_"+slice+"_"+metric;
        export_tex_profile(curves,legendOrder,styles, ...
            limit.largest_finite_ratio,lower_profile_limit(initialRho), ...
            fullfile(outputDir,stem));
    end
end

recipe = "addpath(genpath('mcode')); export_profile_figures_049();";
end

function [tau,rho] = exact_profile_curve(ratio,success,instances,xMax)
tau = unique(ratio(success));
rho = arrayfun(@(value) sum(ratio<=value)/instances,tau);
if isempty(tau) || tau(1)>1
    tau = [1;tau];
    rho = [0;rho];
end
if tau(end)<xMax
    tau(end+1,1) = xMax;
    rho(end+1,1) = mean(success);
end
end

function yMin = lower_profile_limit(initialRho)
lowest = min(initialRho);
if lowest >= 0.6
    yMin = 0.6;
else
    yMin = max(0,0.05*floor((lowest-0.02)/0.05));
end
end

function export_tex_profile(curves,methods,styles,xMax,yMin,outputStem)
workDir = tempname;
mkdir(workDir);
workCleanup = onCleanup(@() remove_work_dir(workDir)); %#ok<NASGU>
texPath = fullfile(workDir,'profile.tex');
fid = fopen(texPath,'w','n','UTF-8');
if fid<0
    error('mcode:ProfileFigureWriteFailed','Cannot write %s.',texPath);
end
fileCleanup = onCleanup(@() fclose(fid));

fprintf(fid,'\\documentclass[tikz,border=0pt]{standalone}\n');
fprintf(fid,'\\usepackage{pgfplots}\n');
fprintf(fid,'\\pgfplotsset{compat=1.18}\n');
[colorNames,first] = unique(styles.pgfplots_color_name,'stable');
for colorIndex = 1:numel(colorNames)
    fprintf(fid,'\\definecolor{%s}{HTML}{%s}\n',colorNames(colorIndex), ...
        erase(styles.color_hex(first(colorIndex)),'#'));
end
fprintf(fid,'\\begin{document}\n\\begin{tikzpicture}\n');
fprintf(fid,['\\begin{axis}[width=16.49cm,height=8.16cm,xmode=log,' ...
    'log basis x=10,xmin=1,xmax=%.15g,ymin=%.15g,ymax=1,' ...
    'xlabel={$\\tau$},ylabel={$\\rho_s(\\tau)$},' ...
    'tick label style={font=\\small},label style={font=\\small},' ...
    'axis line style={line width=0.75pt},grid=major,' ...
    'grid style={draw=black!14,line width=0.25pt},' ...
    'legend style={at={(0.98,0.02)},anchor=south east,' ...
    'legend columns=2,font=\\scriptsize,draw=black,fill=white,' ...
    'cells={anchor=west},/tikz/every even column/.append style={column sep=0.9em}}]\n'], ...
    xMax,yMin);

for methodIndex = 1:numel(methods)
    style = styles(styles.method==methods(methodIndex),:);
    fprintf(fid,'\\addplot+[const plot,no marks,line width=1.5pt,color=%s,%s] coordinates {', ...
        style.pgfplots_color_name,style.pgfplots_line_style);
    curve = curves{methodIndex};
    fprintf(fid,'(%.15g,%.15g) ',[curve.tau';curve.rho']);
    fprintf(fid,'};\n\\addlegendentry{%s}\n',methods(methodIndex));
end
fprintf(fid,'\\end{axis}\n\\end{tikzpicture}\n\\end{document}\n');
clear fileCleanup

oldDir = pwd;
directoryCleanup = onCleanup(@() cd(oldDir)); %#ok<NASGU>
cd(workDir);
[status,compilerOutput] = system( ...
    'pdflatex -interaction=nonstopmode -halt-on-error profile.tex');
if status~=0
    error('mcode:ProfileFigureCompileFailed', ...
        'pdflatex failed for %s:\n%s',outputStem,compilerOutput);
end
[status,converterOutput] = system('pdftops -eps profile.pdf profile.eps');
if status~=0
    error('mcode:ProfileFigureCompileFailed', ...
        'pdftops failed for %s:\n%s',outputStem,converterOutput);
end
copyfile('profile.pdf',outputStem+".pdf",'f');
copyfile('profile.eps',outputStem+".eps",'f');
cd(oldDir);
clear directoryCleanup
clear workCleanup
end

function remove_work_dir(path)
if ~isfolder(path), return; end
contents = dir(path);
for k = 1:numel(contents)
    if ~contents(k).isdir
        delete(fullfile(path,contents(k).name));
    end
end
rmdir(path);
end
