function export_profile_figures_050(report,outputDir,comparisons)
%EXPORT_PROFILE_FIGURES_050 Export the restricted-set profiles as vector PDF.

if nargin < 2 || isempty(outputDir)
    mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
    outputDir = fullfile(fileparts(mcodeRoot),'paper','imgs');
end
if nargin < 3 || isempty(comparisons)
    comparisons = report.sets.comparison;
end
comparisons = string(comparisons(:));
if any(~ismember(comparisons,report.sets.comparison))
    error('mcode:UnknownRestrictedProfileComparison', ...
        'Every requested comparison must occur in report.sets.');
end
if ~isfolder(outputDir), mkdir(outputDir); end
styles = seven_arm_047_styles();
metrics = ["iterations";"component_F_J"];

selectedSets = find(ismember(report.sets.comparison,comparisons));
for setIndex = selectedSets'
    comparison = report.sets.comparison(setIndex);
    methods = report.sets.methods{setIndex};
    for metricIndex = 1:numel(metrics)
        metric = metrics(metricIndex);
        limit = report.limits(report.limits.comparison==comparison & ...
            report.limits.metric==metric,:);
        curveBlock = report.curves( ...
            report.curves.comparison==comparison & ...
            report.curves.metric==metric,:);
        if height(limit)~=1 || isempty(curveBlock)
            error('mcode:IncompleteRestrictedProfiles', ...
                'Missing figure data for %s/%s.',comparison,metric);
        end
        curves = cell(numel(methods),1);
        initialRho = zeros(numel(methods),1);
        for methodIndex = 1:numel(methods)
            curve = curveBlock(curveBlock.method==methods(methodIndex),:);
            if isempty(curve)
                error('mcode:IncompleteRestrictedProfiles', ...
                    'Missing %s curve in %s/%s.',methods(methodIndex), ...
                    comparison,metric);
            end
            curves{methodIndex} = curve(:,{'tau','rho'});
            initialRho(methodIndex) = curve.rho(find(curve.tau==1,1));
        end
        stem = report.sets.file_stem(setIndex)+"_"+metric;
        export_tex_pdf(curves,methods,styles,limit.largest_finite_ratio, ...
            lower_profile_limit(initialRho),fullfile(outputDir,stem), ...
            startsWith(comparison,"pair_"));
    end
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

function export_tex_pdf(curves,methods,styles,xMax,yMin,outputStem,isPair)
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
if isPair
    fprintf(fid,['\\begin{axis}[width=8.23cm,height=5.47cm,xmode=log,' ...
        'log basis x=10,xmin=1,xmax=%.15g,ymin=%.15g,ymax=1,' ...
        'xtick={1,10,100},xlabel={$\\tau$},ylabel={$\\rho_s(\\tau)$},' ...
        'tick label style={font=\\footnotesize},' ...
        'label style={font=\\footnotesize},' ...
        'axis line style={line width=0.6pt},grid=major,' ...
        'grid style={draw=black!14,line width=0.2pt},' ...
        'legend style={at={(0.98,0.02)},anchor=south east,' ...
        'legend columns=1,font=\\footnotesize,draw=black,' ...
        'fill=white,fill opacity=0.9,text opacity=1,' ...
        'cells={anchor=west}}]\n'],xMax,yMin);
    curveWidth = 1.25;
else
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
    curveWidth = 1.5;
end

for methodIndex = 1:numel(methods)
    style = styles(styles.method==methods(methodIndex),:);
    fprintf(fid,'\\addplot+[const plot,no marks,line width=%.2fpt,color=%s,%s] coordinates {', ...
        curveWidth,style.pgfplots_color_name,style.pgfplots_line_style);
    curve = curves{methodIndex};
    fprintf(fid,'(%.15g,%.15g) ',[curve.tau';curve.rho']);
    fprintf(fid,'};\n');
    fprintf(fid,'\\addlegendentry{%s}\n',methods(methodIndex));
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
copyfile('profile.pdf',outputStem+".pdf",'f');
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
