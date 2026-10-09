function tests = test_restricted_profiles_050
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testReducerRenormalizesWithinEachMethodSet(testCase)
report = restricted_profiles_050(seven_arm_ratio_fixture());

limit = report.limits(report.limits.comparison=="pair_PRP" & ...
    report.limits.metric=="iterations",:);
verifyEqual(testCase,limit.instances,3);
verifyEqual(testCase,limit.largest_finite_ratio,2,'AbsTol',1e-14);
verifyEqual(testCase,limit.r_M,8,'AbsTol',1e-14);

rows = report.ratios(report.ratios.comparison=="pair_PRP" & ...
    report.ratios.metric=="iterations",:);
safe = sortrows(rows(rows.method=="SVPRP+",:),'start_id');
plain = sortrows(rows(rows.method=="VPRP+",:),'start_id');
verifyEqual(testCase,safe.ratio,[2;2;1],'AbsTol',1e-14);
verifyEqual(testCase,plain.ratio,[1;1;8],'AbsTol',1e-14);

safeAtOne = report.values(report.values.comparison=="pair_PRP" & ...
    report.values.metric=="iterations" & ...
    report.values.method=="SVPRP+" & report.values.tau==1,:);
plainAtOne = report.values(report.values.comparison=="pair_PRP" & ...
    report.values.metric=="iterations" & ...
    report.values.method=="VPRP+" & report.values.tau==1,:);
verifyEqual(testCase,safeAtOne.count,1);
verifyEqual(testCase,plainAtOne.count,2);

plateau = report.values(report.values.comparison=="pair_PRP" & ...
    report.values.metric=="iterations" & report.values.is_plateau,:);
verifyEqual(testCase,plateau.count,[3;2]);

crossing = report.crossings(report.crossings.comparison=="pair_PRP" & ...
    report.crossings.metric=="iterations",:);
verifyTrue(testCase,crossing.crosses);
verifyEqual(testCase,crossing.tau,2,'AbsTol',1e-14);
end

function testExporterWritesEightPdfFilesAndNoEps(testCase)
report = restricted_profiles_050(seven_arm_ratio_fixture());
outputDir = tempname;
mkdir(outputDir);
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>

export_profile_figures_050(report,outputDir);
stems = ["profile_pair_PRP_all66_iterations"; ...
    "profile_pair_PRP_all66_component_F_J"; ...
    "profile_pair_HS_all66_iterations"; ...
    "profile_pair_HS_all66_component_F_J"; ...
    "profile_pair_LS_all66_iterations"; ...
    "profile_pair_LS_all66_component_F_J"; ...
    "profile_safeguarded_all66_iterations"; ...
    "profile_safeguarded_all66_component_F_J"];
for k = 1:numel(stems)
    pdfPath = fullfile(outputDir,stems(k)+".pdf");
    verifyTrue(testCase,isfile(pdfPath));
    verifyGreaterThan(testCase,dir(pdfPath).bytes,0);
    verifyFalse(testCase,isfile(fullfile(outputDir,stems(k)+".eps")));
end
end

function testGeneratorWritesReductionsAndFigures(testCase)
work = tempname;
reportDir = fullfile(work,'reports');
imageDir = fullfile(work,'imgs');
mkdir(work);
cleanup = onCleanup(@() remove_if_present(work)); %#ok<NASGU>

report = generate_profile_figures_050( ...
    seven_arm_ratio_fixture(),reportDir,imageDir);
verifyEqual(testCase,height(report.limits),8);
verifyEqual(testCase,height(report.crossings),6);
expected = ["profile_050_values.csv";"profile_050_limits.csv"; ...
    "profile_050_crossings.csv";"profile_050_curves.csv"; ...
    "profile_050_report.mat"];
for k = 1:numel(expected)
    verifyTrue(testCase,isfile(fullfile(reportDir,expected(k))));
end
verifyEqual(testCase,numel(dir(fullfile(imageDir,'profile_*.pdf'))),8);
verifyEmpty(testCase,dir(fullfile(imageDir,'profile_*.eps')));
end

function testPairOnlyExportUsesHalfWidthAndNoLegend(testCase)
report = restricted_profiles_050(seven_arm_ratio_fixture());
outputDir = tempname;
mkdir(outputDir);
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>

export_profile_figures_050(report,outputDir,"pair_PRP");
pdfs = dir(fullfile(outputDir,'profile_*.pdf'));
verifyEqual(testCase,numel(pdfs),2);
verifyTrue(testCase,all(startsWith(string({pdfs.name}), ...
    "profile_pair_PRP_all66_")));

pdfPath = fullfile(outputDir,'profile_pair_PRP_all66_iterations.pdf');
[status,info] = system(sprintf('pdfinfo "%s"',pdfPath));
verifyEqual(testCase,status,0);
tokens = regexp(info,'Page size:\s+([0-9.]+) x ([0-9.]+) pts', ...
    'tokens','once');
verifyNotEmpty(testCase,tokens);
widthPoints = str2double(tokens{1});
verifyGreaterThan(testCase,widthPoints,220);
verifyLessThan(testCase,widthPoints,222);

[status,textOutput] = system(sprintf('pdftotext "%s" -',pdfPath));
verifyEqual(testCase,status,0);
verifyFalse(testCase,contains(textOutput,'SVPRP+'));
verifyFalse(testCase,contains(textOutput,'VPRP+'));
end

function ratios = seven_arm_ratio_fixture()
methods = ["SVPRP+";"SVHS+";"SVLS+";"VPRP+";"VHS+";"VLS+";"VSD"];
baseRatios = [4 6 2;3 1 2;3.4 3.4 2.2;2 3 16; ...
    2.4 1.25 1.6;2.2 2.2 1.1;1 1.5 1];
successMask = true(7,3);
successMask(4,3) = false;
metrics = ["iterations";"component_F_J"];
ratios = table();
for q = 1:numel(metrics)
    for m = 1:numel(methods)
        for task = 1:3
            ratios = [ratios;table("all66", ...
                "run_"+m+"_"+task,methods(m),"P",task,metrics(q), ...
                baseRatios(m,task),successMask(m,task), ...
                'VariableNames',{'slice','run_key','method','problem', ...
                'start_id','metric','ratio','success'})]; %#ok<AGROW>
        end
    end
end
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
