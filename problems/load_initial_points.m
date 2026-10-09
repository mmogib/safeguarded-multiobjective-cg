function starts = load_initial_points(prob, mcodeRoot)
%LOAD_INITIAL_POINTS Read the exact 100 starts used by an archived row.

if nargin < 2
    mcodeRoot = fileparts(fileparts(mfilename('fullpath')));
end
path = fullfile(mcodeRoot, 'data', 'initpoints', prob.source_file);
if ~isfile(path)
    error('mcode:MissingInitialPoints', ...
        'Initial-point file is missing for %s: %s', prob.paper_label, path);
end
loaded = load(path);
raw = cell2mat(struct2cell(loaded));
if size(raw, 1) < prob.n || size(raw, 2) < 100
    error('mcode:InvalidInitialPoints', ...
        '%s has size %dx%d; %s requires at least %dx100.', ...
        prob.source_file, size(raw,1), size(raw,2), prob.paper_label, prob.n);
end
starts = raw(1:prob.n, 1:100);
end
