function registry = problem_registry(mcodeRoot)
%PROBLEM_REGISTRY Metadata and evaluators for the 41 archived test rows.

if nargin == 0
    mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
end

labels = { ...
    'BK1','DGO1','DGO2','FF1','JOS1-10','JOS1-100','JOS1-1000', ...
    'MLF1','MLF2','TE1','TE2','TE4','TE6','TE7','SP1','SSFYY2', ...
    'SK1','SK2','VU1','MOP1','MOP2','MOP3','DD1','Toi4','Hill', ...
    'PNR','MMR1','AP3','Lov5','IKK1','TE8-15','TE8-30','TE8-50', ...
    'MOP5','MOP7','FDS-1','FDS-2','FDS-3','SLCDT2','Toi8','AP1'};

families = { ...
    'bk1','dgo1','dgo2','ff1','jos1','jos1','jos1','mlf1','mlf2', ...
    'te1','te2','te4','te6','te7','sp1','ssfyy2','sk1','sk2','vu1', ...
    'mop1','mop2','mop3','dd1','toi4','hill','pnr','mmr1','ap3','lov5', ...
    'ikk1','te8','te8','te8','mop5','mop7','fds','fds','fds','slcdt2', ...
    'toi8','ap1'};

sourceFiles = { ...
    'BK1.mat','DGO1.mat','DGO2.mat','FF12.mat','JOS1.mat','JOS1.mat', ...
    'JOS1.mat','DGO1.mat','MLF2.mat','T1.mat','T27.mat','T4.mat','T6.mat', ...
    'T7.mat','SP1.mat','SSFYY2.mat','SK1.mat','SK2.mat','VU1.mat','MOP1.mat', ...
    'MOP2.mat','MOP37.mat','DD1.mat','TOI4.mat','Hil1.mat','PNR.mat','MMR1.mat', ...
    'AP3.mat','LOV5.mat','IKK1.mat','T8157.mat','T830.mat','T850.mat','MOP5.mat', ...
    'MOP77.mat','FDS.mat','FDS2000.mat','FDS100.mat','SLCDT27.mat','TRI.mat','AP11.mat'};

n = [2 1 1 2 10 100 1000 1 2 2 2 10 2 3 2 1 1 4 2 1 2 2 5 4 2 2 2 2 3 ...
     2 15 30 50 2 2 10 200 100 10 3 2];
m = [2 * ones(1, 29), 3 * ones(1, 12)];
sourceN = n;
sourceN(37) = 2000;
manuscriptN = n;
manuscriptN(37:38) = [100 200];
manuscriptM = m;
manuscriptM(14) = 3;

template = struct( ...
    'legacy_index', [], 'paper_label', '', 'family', '', ...
    'm', [], 'n', [], 'manuscript_m', [], 'manuscript_n', [], ...
    'source_n', [], 'source_file', '', 'initpoints_available', false, ...
    'domain', '', 'known_discrepancy', '', 'safe_point', [], ...
    'value', [], 'jacobian', [], 'legacy_jacobian', []);
registry = repmat(template, 1, 41);
initDir = fullfile(mcodeRoot, 'data', 'initpoints');

for k = 1:41
    fun = str2func(['probs.' families{k}]);
    xSafe = 0.1 + (1:n(k))' / (10 * n(k));
    domain = 'R^n';
    if k == 13
        xSafe = ones(n(k), 1);
        domain = 'x_i > 0';
    elseif k >= 31 && k <= 33
        xSafe(1) = 1.2;
        domain = 'x_1 > 0';
    elseif k == 3
        domain = '|x_1| < 9';
    end

    discrepancy = '';
    if k == 8
        discrepancy = 'Legacy row labelled MLF1 loads DGO1.mat.';
    elseif k == 14
        discrepancy = 'Manuscript says m=3; archived driver executes m=2.';
    elseif k == 28
        discrepancy = 'Archived AP3 objective-1 gradient uses x_1-1 instead of x_1-4.';
    elseif k == 29
        discrepancy = 'Archived Lov5 gradients do not exactly differentiate the values.';
    elseif k == 34
        discrepancy = 'Archived MOP5 objective-3 gradient uses x_1 in its second component exponential term.';
    elseif k == 37 || k == 38
        discrepancy = 'Manuscript FDS-2/FDS-3 dimensions are reversed relative to execution.';
    elseif k == 41
        discrepancy = 'AP11.mat is absent; archived AP1 objective-1 gradient also mismatches its value.';
    end

    registry(k).legacy_index = k;
    registry(k).paper_label = labels{k};
    registry(k).family = families{k};
    registry(k).m = m(k);
    registry(k).n = n(k);
    registry(k).manuscript_m = manuscriptM(k);
    registry(k).manuscript_n = manuscriptN(k);
    registry(k).source_n = sourceN(k);
    registry(k).source_file = sourceFiles{k};
    registry(k).initpoints_available = isfile(fullfile(initDir, sourceFiles{k}));
    registry(k).domain = domain;
    registry(k).known_discrepancy = discrepancy;
    registry(k).safe_point = xSafe;
    registry(k).value = @(x) fun(x, 'value', 'corrected');
    registry(k).jacobian = @(x) fun(x, 'jacobian', 'corrected');
    registry(k).legacy_jacobian = @(x) fun(x, 'jacobian', 'legacy');
end
end
