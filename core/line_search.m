function result = line_search(evaluator, x, direction, alpha0, opts)
%LINE_SEARCH Dispatch to the requested line-search policy.

if strcmp(opts.mode, 'legacy')
    result = ls.legacy(evaluator, x, direction, alpha0, opts);
elseif strcmp(opts.mode, 'validated_strong')
    result = ls.validated_strong(evaluator, x, direction, alpha0, opts);
else
    error('mcode:InvalidLineSearchMode', 'Unknown line-search mode: %s', opts.mode);
end
end
