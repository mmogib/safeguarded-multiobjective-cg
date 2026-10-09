function summary = summarize_tier3_exposure(arguments,acceptedPoints,trialRecords)
%SUMMARIZE_TIER3_EXPOSURE Summarize accepted NC10 iterates and attach trials.

if nargin < 3
    trialRecords = struct([]);
end
nAccepted = size(acceptedPoints,2);
if nAccepted == 0
    error('mcode:EmptyAcceptedSequence', ...
        'At least the initial accepted point is required.');
end
observations = cell(1,nAccepted);
for k = 1:nAccepted
    observations{k} = evaluate_tier3_exposure(arguments,acceptedPoints(:,k));
end
actual = cellfun(@(o) o.actual_exposure,observations);
envelope = cellfun(@(o) o.inverse_t_envelope,observations);
s = cellfun(@(o) o.s,observations);
d = cellfun(@(o) o.d,observations);
post = 2:nAccepted;

summary = struct('s_0',s(1),'s_min_post0',safe_min(s(post)), ...
    's_end',s(end),'d_0',d(1),'d_min_post0',safe_min(d(post)), ...
    'd_end',d(end),'actual_0',actual(1), ...
    'actual_max_post0',safe_max(actual(post)),'actual_end',actual(end), ...
    'inverse_t_envelope_0',envelope(1), ...
    'inverse_t_envelope_max_post0',safe_max(envelope(post)), ...
    'inverse_t_envelope_end',envelope(end), ...
    'accepted_post0_count',numel(post),'regular_exact_hits',0, ...
    'degenerate_zeros',0,'inner_stationary',0, ...
    'observations',{observations},'line_trials',struct([]));
for k = post
    statuses = {observations{k}.entries.status};
    summary.regular_exact_hits = summary.regular_exact_hits+ ...
        sum(strcmp(statuses,'regular_exact_hit'));
    summary.degenerate_zeros = summary.degenerate_zeros+ ...
        sum(strcmp(statuses,'degenerate_zero'));
    summary.inner_stationary = summary.inner_stationary+ ...
        sum(strcmp(statuses,'inner_stationary'));
end
summary.line_trials = attach_trial_exposure(arguments,trialRecords);
end

function records = attach_trial_exposure(arguments,records)
for k = 1:numel(records)
    records(k).exposure = evaluate_tier3_exposure(arguments,records(k).point);
end
end

function value = safe_min(values)
values = values(~isnan(values));
if isempty(values), value = NaN; else, value = min(values); end
end

function value = safe_max(values)
values = values(~isnan(values));
if isempty(values), value = NaN; else, value = max(values); end
end

