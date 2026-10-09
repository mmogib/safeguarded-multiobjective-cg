function snapshot = prepare_legacy_oracle(mcodeRoot, archiveRoot)
%PREPARE_LEGACY_ORACLE Create a hashed, disposable copy of archival code.

sourceHash = tree_hash(archiveRoot);
snapshotPath = fullfile(mcodeRoot, '.work', 'legacy_oracle', sourceHash);
if ~isfolder(snapshotPath)
    parent = fileparts(snapshotPath);
    if ~isfolder(parent)
        mkdir(parent);
    end
    [ok, message] = copyfile(archiveRoot, snapshotPath);
    if ~ok
        error('mcode:OracleCopyFailed', '%s', message);
    end
end

drivers = { ...
    'oracle_TTCGP.m','oracle_TTCGH.m','oracle_TTCGL.m', ...
    'oracle_PRP.m','oracle_AVHZ.m'};
betaTypes = {'PRP+','HS+','LS+'};
methodNames = {'TTCGP','TTCGH','TTCGL'};
source = fileread(fullfile(archiveRoot, 'TTCG_Relaex_Lipschitz.m'));
for k = 1:3
    text = set_problem_count(source);
    text = regexprep(text, "beta_type\s*=\s*'HS\+';", ...
        sprintf("beta_type = '%s';", betaTypes{k}), 'once');
    saveCommand = sprintf(['save(''oracle_%s_output.mat'',''Rloopk'',''Rloopnf'',', ...
        '''Rloopng'',''Rloopnv'',''Rloopt'',''RloopchuSGTTCGAllHS_2obj'',', ...
        '''RloopchuSGTTCGAllHS_3obj'');\n'], methodNames{k});
    text = inject_before_aggregation(text, saveCommand);
    write_text(fullfile(snapshotPath, drivers{k}), text);
end

text = set_problem_count(fileread(fullfile(archiveRoot, 'PRP.m')));
saveCommand = sprintf(['save(''oracle_PRP_output.mat'',''Rloopk'',''Rloopnf'',', ...
    '''Rloopng'',''Rloopnv'',''Rloopt'',''RloopchuPRP_2obj'',', ...
    '''RloopchuPRP_3obj'');\n']);
text = inject_before_aggregation(text, saveCommand);
write_text(fullfile(snapshotPath, 'oracle_PRP.m'), text);

text = set_problem_count(fileread(fullfile(archiveRoot, 'AVHZ.m')));
saveCommand = sprintf(['save(''oracle_AVHZ_output.mat'',''Rloopk'',''Rloopnf'',', ...
    '''Rloopng'',''Rloopnv'',''Rloopt'',''RloopchuAVHZ_2obj'',', ...
    '''RloopchuAVHZ_3obj'');\n']);
text = inject_before_aggregation(text, saveCommand);
write_text(fullfile(snapshotPath, 'oracle_AVHZ.m'), text);

snapshot = struct('path', snapshotPath, 'source_hash', sourceHash, ...
    'generated_drivers', {drivers}, ...
    'patches', {{'h3: 12 -> 11 (AP11.mat absent)', ...
    'TTCG beta_type selected per generated driver', ...
    'method-specific oracle output saved before legacy aggregation'}});
save(fullfile(snapshotPath, 'oracle_snapshot_manifest.mat'), 'snapshot');
end

function text = set_problem_count(text)
text = regexprep(text, 'h3\s*=\s*12;[^\r\n]*', 'h3 = 11;', 'once');
end

function text = inject_before_aggregation(text, saveCommand)
marker = 'MedianIter = median';
position = strfind(text, marker);
if numel(position) ~= 1
    error('mcode:OraclePatchFailed', ...
        'Expected exactly one legacy aggregation marker.');
end
text = [text(1:position-1), saveCommand, 'return;', newline, newline, ...
    text(position:end)];
end

function write_text(path, text)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error('mcode:OracleWriteFailed', 'Cannot write %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, char(text), 'char');
delete(cleanup);
end

function digest = tree_hash(root)
files = [dir(fullfile(root, '*.m')); dir(fullfile(root, '*.mat'))];
names = sort(string({files.name}));
md = java.security.MessageDigest.getInstance('SHA-256');
for k = 1:numel(names)
    name = char(names(k));
    md.update(unicode2native(name, 'UTF-8'));
    fid = fopen(fullfile(root, name), 'rb');
    cleanup = onCleanup(@() fclose(fid));
    md.update(fread(fid, Inf, '*uint8'));
    delete(cleanup);
end
raw = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(raw, 2).', 1, []));
end
