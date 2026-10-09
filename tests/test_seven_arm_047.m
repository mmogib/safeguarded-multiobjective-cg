function tests = test_seven_arm_047
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
end

function testMethodManifestUsesRequestedOrderAndDisplayNames(testCase)
methods = seven_arm_047_methods();
verifyEqual(testCase,methods.display_name, ...
    ["SVPRP+";"SVHS+";"SVLS+";"VPRP+";"VHS+";"VLS+";"VSD"]);
verifyEqual(testCase,methods.code_id, ...
    ["TTCGP";"TTCGH";"TTCGL";"PRP+";"HS+";"LS+";"MOSD"]);
verifyEqual(testCase,sum(methods.store=="base"),5);
verifyEqual(testCase,sum(methods.store=="extension"),2);
end

function testAssemblerMapsCopiesAndRequiresExactStarts(testCase)
[base,extension] = paired_fixture();
runs = assemble_seven_arm_047_runs(base,extension,2);

verifyEqual(testCase,height(runs),14);
verifyEqual(testCase,unique(runs.method,'stable'), ...
    ["SVPRP+";"SVHS+";"SVLS+";"VPRP+";"VHS+";"VLS+";"VSD"]);
verifyEqual(testCase,unique(runs.code_id,'stable'), ...
    ["TTCGP";"TTCGH";"TTCGL";"PRP+";"HS+";"LS+";"MOSD"]);
verifyEqual(testCase,base.method(1),"TTCGP");

extension.x0{end}(1) = extension.x0{end}(1)+1;
verifyError(testCase,@() assemble_seven_arm_047_runs( ...
    base,extension,2),'mcode:UnpairedSevenArm047');
end

function testReportingTablesUseRequestedDefinitions(testCase)
[runs,iterations] = reporting_fixture();
report = seven_arm_047_tables(runs,iterations);

vhs = report.outcomes(report.outcomes.method=="VHS+",:);
verifyEqual(testCase,vhs.converged,5);
verifyEqual(testCase,vhs.line_search,1);
verifyEqual(testCase,vhs.success_rate,5/6,'AbsTol',1e-14);

accuracy = report.stopping_accuracy( ...
    report.stopping_accuracy.method=="SVPRP+",:);
verifyEqual(testCase,accuracy.problems_defined,3);
verifyEqual(testCase,accuracy.median_problem_median_v_norm,2e-8, ...
    'AbsTol',1e-20);

descent = report.descent(report.descent.method=="SVPRP+",:);
verifyEqual(testCase,descent.directions_formed,2);
verifyEqual(testCase,descent.violations,2);
verifyEqual(testCase,descent.non_descent_violations,1);

paired = report.paired_work(report.paired_work.method=="VPRP+",:);
verifyEqual(testCase,paired.paired_successes,6);
verifyEqual(testCase,paired.iterations_over_SVPRP,0.5,'AbsTol',1e-14);

family = report.family_work(report.family_work.unsafeguarded=="VLS+" & ...
    report.family_work.slice=="D1-D10",:);
verifyEqual(testCase,family.paired_successes,2);
verifyEqual(testCase,family.iterations_ratio,0.7,'AbsTol',1e-14);

same = report.identical_iterations;
verifyEqual(testCase,same.identical_iterations, [6;5]);
verifyEqual(testCase,same.paired_successes,[6;6]);
end

function testProfilesRetainFailuresAndDownsampleExactBreakpoints(testCase)
runs = profile_fixture(350);
profiles = seven_arm_047_profiles(runs,300);

limit = profiles.limits(profiles.limits.slice=="all66" & ...
    profiles.limits.metric=="iterations",:);
verifyEqual(testCase,limit.largest_finite_ratio,350,'AbsTol',1e-14);
verifyEqual(testCase,limit.r_M,700,'AbsTol',1e-14);

vprp = profiles.values(profiles.values.slice=="all66" & ...
    profiles.values.metric=="iterations" & ...
    profiles.values.method=="VPRP+" & profiles.values.tau==1,:);
verifyEqual(testCase,vprp.count,315);
verifyEqual(testCase,vprp.instances,350);
verifyEqual(testCase,vprp.rho,0.9,'AbsTol',1e-14);
plateau = profiles.values(profiles.values.slice=="all66" & ...
    profiles.values.metric=="iterations" & ...
    profiles.values.method=="VPRP+" & profiles.values.is_plateau,:);
verifyEqual(testCase,plateau.rho,0.9,'AbsTol',1e-14);

failed = profiles.ratios(profiles.ratios.slice=="all66" & ...
    profiles.ratios.metric=="iterations" & ...
    profiles.ratios.method=="VPRP+" & ~profiles.ratios.success,:);
verifyTrue(testCase,all(failed.ratio==700));
verifyLessThanOrEqual(testCase,max(groupcounts(categorical( ...
    profiles.curves.slice+"__"+profiles.curves.metric+"__"+ ...
    profiles.curves.method))),300);
svprpError = profiles.downsampling( ...
    profiles.downsampling.slice=="all66" & ...
    profiles.downsampling.metric=="iterations" & ...
    profiles.downsampling.method=="SVPRP+",:);
verifyLessThanOrEqual(testCase,svprpError.max_vertical_deviation,2/350);
end

function testProfilesAssignRMWhenEveryArmFailsAnInstance(testCase)
runs = profile_fixture(10);
runs.status(runs.start_id==10) = "no_descent";
profiles = seven_arm_047_profiles(runs,300);
limit = profiles.limits(profiles.limits.slice=="all66" & ...
    profiles.limits.metric=="iterations",:);
failed = profiles.ratios(profiles.ratios.slice=="all66" & ...
    profiles.ratios.metric=="iterations" & ...
    profiles.ratios.start_id==10,:);
verifyEqual(testCase,height(failed),7);
verifyTrue(testCase,all(~failed.success));
verifyTrue(testCase,all(failed.ratio==limit.r_M));
end

function testProfileStylesUseColorAndLinePatternRedundantly(testCase)
styles = seven_arm_047_styles();
verifyEqual(testCase,styles.method,seven_arm_047_methods().display_name);
verifyEqual(testCase,height(styles),7);
verifyEqual(testCase,styles.color_hex, ...
    ["#0072B2";"#D55E00";"#009E73";"#0072B2"; ...
     "#D55E00";"#009E73";"#000000"]);
verifyEqual(testCase,styles.pgfplots_line_style, ...
    ["solid";"solid";"solid";"dashed";"dashed";"dashed";"dash dot"]);
verifyTrue(testCase,all(~cellfun(@isempty,regexp( ...
    cellstr(styles.color_hex),'^#[0-9A-F]{6}$','once'))));
end

function testProfileFigureExporterWritesEveryVectorPair(testCase)
mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
reportPath = fullfile(mcodeRoot,'data','results', ...
    'full_campaign_047_seven_arms','reports','seven_arm_047_report.mat');
assumeTrue(testCase,isfile(reportPath), ...
    'The optional full-resolution plotting fixture is unavailable.');
outputDir = tempname;
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>

recipe = export_profile_figures_049(reportPath,outputDir);
verifyEqual(testCase,recipe,"addpath(genpath('mcode')); export_profile_figures_049();");

slices = ["all66";"archived41";"H1-H15";"D1-D10"];
metrics = ["iterations";"component_F_J"];
for s = 1:numel(slices)
    for m = 1:numel(metrics)
        stem = "profile_"+slices(s)+"_"+metrics(m);
        for extension = [".pdf",".eps"]
            artifact = fullfile(outputDir,stem+extension);
            verifyTrue(testCase,isfile(artifact));
            info = dir(artifact);
            verifyGreaterThan(testCase,info.bytes,0);
        end
    end
end
end

function testBuilderRecomputesFrontPoolAndWritesManifest(testCase)
[runs,iterations] = reporting_fixture();
report = build_seven_arm_047_report(runs,iterations,50);
verifyEqual(testCase,height(report.front_quality.aggregate),7);
verifyEqual(testCase,height(report.front_quality.coverage_aggregate),49);
verifyEqual(testCase,unique(report.front_quality.per_problem.method,'stable'), ...
    seven_arm_047_methods().display_name);

outputDir = tempname;
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>
write_seven_arm_047_report(report,outputDir);
expected = ["outcomes.csv";"stopping_accuracy.csv";"descent.csv"; ...
    "paired_work.csv";"family_work.csv";"identical_iterations.csv"; ...
    "profile_values.csv";"profile_limits.csv";"profile_curves.csv"; ...
    "profile_downsampling.csv";"profile_styles.csv"; ...
    "profile_styles.tex"; ...
    "front_coverage_mean_matrix.csv";"front_quality_aggregate.csv"; ...
    "analytic_front_distance.csv";"results_report.mat"; ...
    "seven_arm_047_report.mat"];
for k = 1:numel(expected)
    verifyTrue(testCase,isfile(fullfile(outputDir,expected(k))));
end
end

function [base,extension] = paired_fixture()
baseMethods = ["TTCGP";"TTCGH";"TTCGL";"PRP+";"MOSD"];
extensionMethods = ["HS+";"LS+"];
base = fixture_rows(baseMethods);
extension = fixture_rows(extensionMethods);
end

function rows = fixture_rows(methods)
rows = table();
for m = 1:numel(methods)
    for start = 1:2
        method = methods(m);
        problem = "P1";
        start_id = start;
        x0 = {[start;-start]};
        run_key = method+"__P1__"+string(start);
        rows = [rows;table(method,problem,start_id,x0,run_key)]; %#ok<AGROW>
    end
end
end


function [runs,iterations] = reporting_fixture()
methods = ["SVPRP+";"SVHS+";"SVLS+";"VPRP+";"VHS+";"VLS+";"VSD"];
codes = ["TTCGP";"TTCGH";"TTCGL";"PRP+";"HS+";"LS+";"MOSD"];
problems = ["A";"E2-1";"NC10-1"];
tiers = [1;2;3];
sets = ["tier1";"E2";"NC10"];
runs = table();
for m = 1:numel(methods)
    for p = 1:numel(problems)
        for start = 1:2
            method = methods(m); code_id = codes(m);
            problem = problems(p); start_id = start;
            run_key = method+"__"+problem+"__"+string(start);
            tier = tiers(p); set_name = sets(p);
            theorem_compatible = p==1;
            status = "converged";
            if method=="VHS+" && p==3 && start==2
                status = "line_search_failed";
            end
            baseIterations = 9;
            if method=="VPRP+", baseIterations = 4; end
            if method=="VHS+", baseIterations = 5; end
            if method=="VLS+", baseIterations = 6; end
            if method=="VSD" && p==3 && start==2, baseIterations = 10; end
            iterationCount = baseIterations;
            component_F = baseIterations+2;
            component_J = component_F;
            v_norm = p*1e-8;
            F_final = {[m+p/10;8-m+start/10]};
            runs = [runs;table(run_key,method,code_id,problem,start_id, ...
                tier,set_name,theorem_compatible,status,iterationCount, ...
                component_F,component_J,v_norm,F_final,'VariableNames', ...
                {'run_key','method','code_id','problem','start_id','tier', ...
                'set_name','theorem_compatible','status','iterations', ...
                'component_F','component_J','v_norm','F_final'})]; %#ok<AGROW>
        end
    end
end

iterations = table();
nc = runs(runs.set_name=="NC10",:);
for k = 1:height(nc)
    run_key = nc.run_key(k); iteration = 1;
    descent_bound_holds = true; directional_value = -1;
    if nc.method(k)=="SVPRP+"
        descent_bound_holds = false;
        if nc.start_id(k)==2, directional_value = 0.1; end
    end
    iterations = [iterations;table(run_key,iteration, ...
        descent_bound_holds,directional_value,'VariableNames', ...
        {'run_key','k','descent_bound_holds','directional_value'})]; %#ok<AGROW>
end
end

function runs = profile_fixture(tasks)
methods = seven_arm_047_methods().display_name;
runs = table();
for m = 1:numel(methods)
    for start = 1:tasks
        method = methods(m); problem = "P"; start_id = start;
        run_key = method+"__P__"+string(start);
        tier = 1; set_name = "tier1"; status = "converged";
        iterationCount = 1;
        if method=="SVPRP+", iterationCount = start-1; end
        if method=="VSD", iterationCount = 0; end
        if method=="VPRP+", iterationCount = 0; end
        if method=="VPRP+" && start>0.9*tasks
            status = "no_descent";
        end
        component_F = iterationCount;
        component_J = component_F;
        runs = [runs;table(run_key,method,problem,start_id,tier,set_name, ...
            status,iterationCount,component_F,component_J, ...
            'VariableNames',{'run_key','method','problem','start_id', ...
            'tier','set_name','status','iterations','component_F', ...
            'component_J'})]; %#ok<AGROW>
    end
end
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
