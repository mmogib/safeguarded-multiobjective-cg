function digest = campaign_hash(cfg)
%CAMPAIGN_HASH SHA-256 over configuration, implementation and initial data.

root = cfg.mcode_root;
hashCfg = cfg;
hashCfg = rmfield(hashCfg, intersect(fieldnames(hashCfg), {'output_file'}));
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(unicode2native(jsonencode(orderfields(hashCfg)), 'UTF-8'));

sourceFiles = dir(fullfile(root, '**', '*.m'));
dataFiles = dir(fullfile(root, 'data', 'initpoints', '*.mat'));
files = [sourceFiles; dataFiles];
fullPaths = strings(numel(files),1);
for k = 1:numel(files)
    fullPaths(k) = string(fullfile(files(k).folder, files(k).name));
end
disposable = contains(fullPaths, string([filesep '.work' filesep])) | ...
    contains(fullPaths, string([filesep 'data' filesep 'results' filesep]));
fullPaths = fullPaths(~disposable);
fullPaths = sort(fullPaths);
for k = 1:numel(fullPaths)
    path = char(fullPaths(k));
    relative = erase(path, [root filesep]);
    md.update(unicode2native(relative, 'UTF-8'));
    fid = fopen(path, 'rb');
    if fid < 0
        error('mcode:HashReadFailed', 'Cannot read %s.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    bytes = fread(fid, Inf, '*uint8');
    md.update(bytes);
    delete(cleanup);
end
raw = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(raw, 2).', 1, []));
end
