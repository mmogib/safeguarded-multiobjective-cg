function tests = test_eta_study
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'problems'),fullfile(root,'core'), ...
    fullfile(root,'config'),fullfile(root,'bench'));
testCase.TestData.root = root;
end

function testConfigurationMatchesAdopted035Design(testCase)
cfg = eta_study_config(testCase.TestData.root,tempname);

verifyEqual(testCase,cfg.grid,[0 0.01 0.03 0.1 0.3 1 3 10]);
verifyEqual(testCase,cfg.primary_problem_indices, ...
    [1 5 6 7 22 17 18 19 23 26 31 32 33 35 40]);
verifyEqual(testCase,cfg.natural_domain_indices,[31 32 33]);
verifyEqual(testCase,cfg.e2_problem_indices,1:5);
verifyEqual(testCase,cfg.trials,1:100);
verifyEqual(testCase,numel(cfg.jobs),22);
verifyEqual(testCase,string(cfg.jobs(1).method),"MOSD");
verifyEqual(testCase,cfg.jobs(1).eta,0);
verifyEqual(testCase,sum(string({cfg.jobs.method})=="MOSD"),1);
positive = cfg.jobs(2:end);
verifyEqual(testCase,unique([positive.eta],'stable'),cfg.grid(2:end));
verifyEqual(testCase,unique(string({positive.method}),'stable'), ...
    ["TTCGP" "TTCGH" "TTCGL"]);
verifyEqual(testCase,unique(string({positive.mode})),"paper_r2");
verifyEqual(testCase,cfg.invariant_abs_tol,1e-12);
verifyEqual(testCase,cfg.invariant_rel_tol,1e-10);
end

function testReducerAggregatesRunsThenProblemsAndAppliesGate(testCase)
outputDir = tempname;
mkdir(outputDir);
cleanup = onCleanup(@() rmdir(outputDir,'s')); %#ok<NASGU>
cfg = eta_study_config(testCase.TestData.root,outputDir);
rows = synthetic_rows();

summary = summarize_eta_study(rows,cfg);

verifyEqual(testCase,height(summary.mechanism_per_run),14);
verifyEqual(testCase,height(summary.mechanism_per_problem),7);
use = summary.work_scores.set_name=="primary15" & ...
    summary.work_scores.eta==1;
verifyEqual(testCase,summary.work_scores.ItN_ratio(use),1.005, ...
    'RelTol',1e-12);
verifyEqual(testCase,summary.work_scores.FeN_ratio(use),1.005, ...
    'RelTol',1e-12);
verifyEqual(testCase,summary.work_scores.GeN_ratio(use),1.005, ...
    'RelTol',1e-12);
verifyFalse(testCase,ismember('score', ...
    summary.work_scores.Properties.VariableNames));
verifyTrue(testCase,summary.gate.pass);
verifyEqual(testCase,summary.gate.successes_eta_one,6);
verifyEqual(testCase,summary.gate.best_positive_successes,6);
verifyTrue(testCase,isfile(fullfile(outputDir,'eta_study_work_scores.csv')));
verifyTrue(testCase,isfile(fullfile(outputDir,'eta_study_gate.csv')));
end

function testGateChecksEveryWorkMeasureSeparately(testCase)
outputDir = tempname;
mkdir(outputDir);
cleanup = onCleanup(@() rmdir(outputDir,'s')); %#ok<NASGU>
cfg = eta_study_config(testCase.TestData.root,outputDir);
rows = synthetic_rows();
isEtaOne = [rows.eta]==1;
for k = find(isEtaOne)
    rows(k).iterations = 102;
end

summary = summarize_eta_study(rows,cfg);

verifyFalse(testCase,summary.gate.criterion2_work);
verifyFalse(testCase,summary.gate.pass);
verifyGreaterThan(testCase,summary.gate.ItN_ratio_eta_one,1.01);
verifyEqual(testCase,summary.gate.FeN_ratio_eta_one,1.005, ...
    'RelTol',1e-12);
verifyEqual(testCase,summary.gate.GeN_ratio_eta_one,1.005, ...
    'RelTol',1e-12);
end

function testRunnerChecksZeroGateThenCheckpointsAndResumes(testCase)
outputDir = tempname;
cleanup = onCleanup(@() remove_if_present(outputDir)); %#ok<NASGU>
cfg = eta_study_config(testCase.TestData.root,outputDir);
cfg.primary_problem_indices = 1;
cfg.e2_problem_indices = [];
cfg.trials = 1;
cfg.parallel_workers = 1;
cfg.max_iter = 2;

first = run_eta_study(cfg);
second = run_eta_study(cfg);

verifyTrue(testCase,first.zero_gate.all_equal);
verifyEqual(testCase,numel(first.zero_gate.rows),4);
verifyEqual(testCase,numel(first.rows),22);
verifyEqual(testCase,numel(second.rows),22);
verifyEqual(testCase,sum(strcmp({second.rows.method},'MOSD')),1);
verifyFalse(testCase,any(startsWith(string({second.rows.method}),'TTCG') & ...
    [second.rows.eta]==0));
verifyEqual(testCase,numel(second.reproducibility.rows),3);
verifyTrue(testCase,second.reproducibility.all_equal);
verifyTrue(testCase,isfile(cfg.zero_gate_file));
verifyTrue(testCase,isfile(cfg.checkpoint_file));
verifyTrue(testCase,isfile(cfg.reproducibility_file));
end

function rows = synthetic_rows()
rows = one_row('primary15','P1','MOSD',0,1,100,[0],[1],[0],[],[]);
for trial = 2
    rows(end+1) = one_row('primary15','P1','MOSD',0,trial,100, ... %#ok<AGROW>
        [0],[1],[0],[],[]);
end
for eta = [0.1 1]
    for method = {'TTCGP','TTCGH','TTCGL'}
        for trial = 1:2
            work = 100*(1+0.005*(eta==1));
            rows(end+1) = one_row('primary15','P1',method{1},eta, ... %#ok<AGROW>
                trial,work,[0 eta],[1 1+eta],[0 5],eta>0.05,false);
        end
    end
end
end

function row = one_row(setName,problem,method,eta,trial,work,q,g,a,I,J)
row = struct('set_name',setName,'problem',problem,'problem_index',1, ...
    'natural_domain',false,'method',method,'eta',eta,'trial',trial, ...
    'status','converged','iterations',work,'theta',-1e-12,'v_norm',1e-6, ...
    'steepest_directional_value',-1e-12,'vector_F',work, ...
    'vector_J',work,'qp_solves',work,'line_search_trials',work, ...
    'wall_time',1,'evaluation_time',0.5,'qp_time',0.25, ...
    'line_search_failure_status','','qp_failures',0,'nonfinite_events',0, ...
    'q_values',q,'g_values',g,'angle_values',a, ...
    'cap_active_values',logical(I),'lower_truncation_values',logical(J), ...
    'q_violation_count',0,'g_violation_count',0,'max_q_excess',0, ...
    'max_g_excess',0,'x',0,'F',[0;0]);
end

function remove_if_present(path)
if isfolder(path), rmdir(path,'s'); end
end
