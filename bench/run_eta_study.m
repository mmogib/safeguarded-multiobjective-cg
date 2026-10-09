function output = run_eta_study(cfg)
%RUN_ETA_STUDY Run the exchange-035 mechanism-and-robustness study.

validate_config(cfg);
ensure_folder(cfg.output_dir);
manifest = make_manifest(cfg);
start_pool(cfg.parallel_workers);

zeroGate = run_zero_gate(cfg,manifest);
if ~zeroGate.all_equal
    error('mcode:EtaZeroMOSDMismatch', ...
        'eta_bar=0 failed the bit-for-bit MOSD preflight gate.');
end

rows = load_rows(cfg.checkpoint_file,manifest, ...
    'mcode:EtaStudyCheckpointMismatch');
if isempty(rows)
    rows = zeroGate.rows(strcmp({zeroGate.rows.method},'MOSD'));
    save_rows(cfg.checkpoint_file,rows,manifest);
end
rows = run_jobs(cfg,manifest,rows,cfg.jobs(2:end), ...
    cfg.primary_problem_indices,cfg.e2_problem_indices,cfg.checkpoint_file);

reproducibility = run_reproducibility(cfg,manifest,rows);
summary = summarize_eta_study(rows,cfg);
report = struct('manifest',manifest,'zero_gate',zeroGate.summary, ...
    'reproducibility',reproducibility.summary,'summary',summary);
save(fullfile(cfg.output_dir,'eta_study_report.mat'),'report','-v7.3');
output = struct('rows',rows,'zero_gate',zeroGate, ...
    'reproducibility',reproducibility,'summary',summary, ...
    'manifest',manifest);
end

function gate = run_zero_gate(cfg,manifest)
jobs = [struct('method','MOSD','mode','paper_r2','eta',0), ...
    struct('method','TTCGP','mode','paper_r2','eta',0), ...
    struct('method','TTCGH','mode','paper_r2','eta',0), ...
    struct('method','TTCGL','mode','paper_r2','eta',0)];
rows = load_rows(cfg.zero_gate_file,manifest, ...
    'mcode:EtaZeroGateCheckpointMismatch');
rows = run_jobs(cfg,manifest,rows,jobs,cfg.primary_problem_indices, ...
    cfg.e2_problem_indices,cfg.zero_gate_file);

summary = table();
allEqual = true;
for setName = unique(string({rows.set_name}),'stable')
    problems = unique(string({rows(string({rows.set_name})==setName).problem}), ...
        'stable');
    for problem = problems
        trials = unique([rows(string({rows.set_name})==setName & ...
            string({rows.problem})==problem).trial]);
        for method = ["TTCGP" "TTCGH" "TTCGL"]
            equalCount = 0;
            for trial = trials
                base = rows(string({rows.set_name})==setName & ...
                    string({rows.problem})==problem & ...
                    string({rows.method})=="MOSD" & [rows.trial]==trial);
                candidate = rows(string({rows.set_name})==setName & ...
                    string({rows.problem})==problem & ...
                    string({rows.method})==method & [rows.trial]==trial);
                equalCount = equalCount+trajectory_equal(base,candidate);
            end
            blockEqual = equalCount==numel(trials);
            allEqual = allEqual && blockEqual;
            summary = [summary;table(setName,problem,method,numel(trials), ...
                equalCount,blockEqual,'VariableNames',{'set_name','problem', ...
                'zero_arm','tasks','bit_exact','all_equal'})]; %#ok<AGROW>
        end
    end
end
writetable(summary,fullfile(cfg.output_dir,'eta_zero_gate_summary.csv'));
gate = struct('rows',rows,'summary',summary,'all_equal',allEqual);
end

function reproducibility = run_reproducibility(cfg,manifest,studyRows)
jobs = cfg.jobs([cfg.jobs.eta]==1);
rows = load_rows(cfg.reproducibility_file,manifest, ...
    'mcode:EtaReproducibilityCheckpointMismatch');
rows = run_jobs(cfg,manifest,rows,jobs,cfg.primary_problem_indices,[], ...
    cfg.reproducibility_file);
summary = table();
allEqual = true;
for method = unique(string({rows.method}),'stable')
    candidate = rows(string({rows.method})==method);
    equalCount = 0;
    for k = 1:numel(candidate)
        original = studyRows(string({studyRows.set_name})=="primary15" & ...
            string({studyRows.method})==method & [studyRows.eta]==1 & ...
            string({studyRows.problem})==string(candidate(k).problem) & ...
            [studyRows.trial]==candidate(k).trial);
        equalCount = equalCount+trajectory_equal(original,candidate(k));
    end
    blockEqual = equalCount==numel(candidate);
    allEqual = allEqual && blockEqual;
    summary = [summary;table(method,numel(candidate),equalCount,blockEqual, ...
        'VariableNames',{'method','tasks','bit_exact','all_equal'})]; %#ok<AGROW>
end
writetable(summary, ...
    fullfile(cfg.output_dir,'eta_one_reproducibility.csv'));
reproducibility = struct('rows',rows,'summary',summary,'all_equal',allEqual);
end

function rows = run_jobs(cfg,manifest,rows,jobs,primaryIndices,e2Indices,path)
archivedRegistry = problem_registry(cfg.mcode_root);
e2Registry = nonlipschitz_problem_registry();
for jobIndex = 1:numel(jobs)
    job = jobs(jobIndex);
    for problemIndex = primaryIndices
        prob = archivedRegistry(problemIndex);
        starts = load_initial_points(prob,cfg.mcode_root);
        rows = run_block(cfg,manifest,rows,job,prob,starts,'primary15', ...
            problemIndex,ismember(problemIndex,cfg.natural_domain_indices),path);
    end
    for problemIndex = e2Indices
        prob = e2Registry(problemIndex);
        starts = nonlipschitz_starts(prob);
        rows = run_block(cfg,manifest,rows,job,prob,starts,'E2', ...
            problemIndex,false,path);
    end
end
end

function rows = run_block(cfg,manifest,rows,job,prob,starts,setName, ...
    problemIndex,naturalDomain,path)
pending = cfg.trials(~arrayfun(@(trial) row_exists(rows,setName, ...
    job.method,job.eta,prob.paper_label,trial),cfg.trials));
if isempty(pending), return; end
cells = cell(1,numel(pending));
if cfg.parallel_workers > 1
    parfor k = 1:numel(pending)
        cells{k} = run_one(cfg,job,prob,starts(:,pending(k)),setName, ...
            problemIndex,naturalDomain,pending(k));
    end
else
    for k = 1:numel(pending)
        cells{k} = run_one(cfg,job,prob,starts(:,pending(k)),setName, ...
            problemIndex,naturalDomain,pending(k));
    end
end
block = horzcat(cells{:});
if isempty(rows), rows = block; else, rows = [rows,block]; end %#ok<AGROW>
save_rows(path,rows,manifest);
fprintf('eta study complete: %s eta=%g %s/%s (%d rows)\n', ...
    job.method,job.eta,setName,prob.paper_label,numel(rows));
end

function row = run_one(cfg,job,prob,x0,setName,problemIndex,naturalDomain,trial)
opts = experiment(job.method,job.mode);
if startsWith(job.method,'TTCG'), opts.eta_bar = job.eta; end
opts.max_iter = cfg.max_iter;
started = tic;
result = solve_mocg(prob,x0,opts);
wallTime = toc(started);
diag = result.diagnostics;
q = diag.correction_ratio_values;
g = diag.direction_growth_values;
if startsWith(job.method,'TTCG')
    cap = diag.raw_beta>job.eta;
    lower = diag.raw_beta<=0;
    qBound = job.eta;
    gBound = 1+job.eta;
else
    cap = [];
    lower = [];
    qBound = 0;
    gBound = 1;
end
qTol = cfg.invariant_abs_tol+cfg.invariant_rel_tol*max(1,qBound);
gTol = cfg.invariant_abs_tol+cfg.invariant_rel_tol*max(1,gBound);
qExcess = q-qBound;
gExcess = g-gBound;
failureStatus = '';
if ~isempty(diag.line_search_failure)
    failureStatus = diag.line_search_failure.status;
end
row = struct('set_name',setName,'problem',prob.paper_label, ...
    'problem_index',problemIndex,'natural_domain',naturalDomain, ...
    'method',job.method,'eta',job.eta,'trial',trial, ...
    'status',result.status,'iterations',result.iterations, ...
    'theta',result.theta,'v_norm',result.v_norm, ...
    'steepest_directional_value',result.steepest_directional_value, ...
    'vector_F',result.counts.vector_F,'vector_J',result.counts.vector_J, ...
    'qp_solves',diag.qp_solves,'line_search_trials',diag.line_search_trials, ...
    'wall_time',wallTime,'evaluation_time',result.counts.evaluation_time, ...
    'qp_time',diag.qp_time,'line_search_failure_status',failureStatus, ...
    'line_search_statuses',{diag.line_search_statuses}, ...
    'qp_failures',diag.qp_failures,'nonfinite_events',diag.nonfinite_events, ...
    'q_values',q,'g_values',g,'angle_values',diag.direction_angle_values, ...
    'cap_active_values',cap,'lower_truncation_values',lower, ...
    'q_violation_count',sum(qExcess>qTol,'omitnan'), ...
    'g_violation_count',sum(gExcess>gTol,'omitnan'), ...
    'max_q_excess',finite_max(qExcess),'max_g_excess',finite_max(gExcess), ...
    'x',result.x,'F',result.F);
end

function yes = trajectory_equal(left,right)
if numel(left)~=1 || numel(right)~=1
    yes = false;
    return
end
fields = {'set_name','problem','problem_index','trial','status','iterations', ...
    'theta','v_norm','steepest_directional_value','vector_F','vector_J', ...
    'qp_solves','line_search_trials','line_search_failure_status', ...
    'line_search_statuses','qp_failures','nonfinite_events','q_values', ...
    'g_values','angle_values','q_violation_count','g_violation_count','x','F'};
yes = true;
for k = 1:numel(fields)
    if ~isequaln(left.(fields{k}),right.(fields{k}))
        yes = false;
        return
    end
end
end

function yes = row_exists(rows,setName,method,eta,problem,trial)
if isempty(rows)
    yes = false;
else
    yes = any(string({rows.set_name})==string(setName) & ...
        string({rows.method})==string(method) & [rows.eta]==eta & ...
        string({rows.problem})==string(problem) & [rows.trial]==trial);
end
end

function rows = load_rows(path,manifest,errorId)
if ~isfile(path)
    rows = struct([]);
    return
end
loaded = load(path,'rows','manifestSaved');
if ~strcmp(loaded.manifestSaved.hash,manifest.hash)
    error(errorId,'Checkpoint source/configuration hash does not match.');
end
rows = loaded.rows;
end

function save_rows(path,rows,manifest)
manifestSaved = manifest;
temporary = [tempname(fileparts(path)) '.mat'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
save(temporary,'rows','manifestSaved','-v7.3');
replace_file(temporary,path);
end

function manifest = make_manifest(cfg)
hashCfg = struct('mcode_root',cfg.mcode_root,'output_file','', ...
    'eta_study_design',strip_paths(cfg));
manifest = struct('study_version',cfg.study_version, ...
    'hash',campaign_hash(hashCfg), ...
    'created_utc',char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')),'configuration',strip_paths(cfg));
end

function cfg = strip_paths(cfg)
cfg.output_dir = '';
cfg.checkpoint_file = '';
cfg.zero_gate_file = '';
cfg.reproducibility_file = '';
end

function validate_config(cfg)
expected = eta_study_config(cfg.mcode_root,cfg.output_dir);
if ~isequal(cfg.grid,expected.grid) || ~isequal(cfg.jobs,expected.jobs)
    error('mcode:UnauthorizedEtaStudy','The eta grid or arm set is not exchange 035.');
end
if ~all(ismember(cfg.primary_problem_indices,expected.primary_problem_indices)) || ...
        ~all(ismember(cfg.e2_problem_indices,expected.e2_problem_indices)) || ...
        ~all(ismember(cfg.trials,1:100)) || isempty(cfg.trials)
    error('mcode:InvalidEtaStudy','Invalid problem or trial subset.');
end
if cfg.invariant_abs_tol~=expected.invariant_abs_tol || ...
        cfg.invariant_rel_tol~=expected.invariant_rel_tol
    error('mcode:UnauthorizedEtaStudy','Invariant tolerances changed.');
end
end

function value = finite_max(values)
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = max(values); end
end

function start_pool(workers)
if workers>1 && isempty(gcp('nocreate')), parpool('Processes',workers); end
end

function ensure_folder(path)
if ~isfolder(path), mkdir(path); end
end

function replace_file(source,target)
[ok,message] = movefile(source,target,'f');
if ~ok, error('mcode:CheckpointWriteFailed','%s',message); end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end
