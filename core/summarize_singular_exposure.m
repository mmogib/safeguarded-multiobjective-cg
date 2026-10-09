function summary = summarize_singular_exposure(arguments,acceptedPoints,trialRecords)
%SUMMARIZE_SINGULAR_EXPOSURE Frozen per-run E1 statistics.

if nargin < 3
    trialRecords = struct([]);
end
nAccepted = size(acceptedPoints,2);
observations = cell(1,nAccepted);
for k = 1:nAccepted
    observations{k} = evaluate_singular_exposure(arguments,acceptedPoints(:,k));
end
s = cellfun(@(o) o.s,observations);
d = cellfun(@(o) o.d,observations);
chi = cellfun(@(o) o.chi,observations);
post = 2:nAccepted;

summary = struct();
summary.s_0 = s(1); summary.d_0 = d(1); summary.chi_0 = chi(1);
summary.s_min_post0 = safe_min(s(post));
summary.d_min_post0 = safe_min(d(post));
summary.chi_max_post0 = safe_max(chi(post));
summary.s_end = s(end); summary.d_end = d(end); summary.chi_end = chi(end);
summary.s_contraction = safe_ratio(summary.s_min_post0,summary.s_0);
summary.d_contraction = safe_ratio(summary.d_min_post0,summary.d_0);
summary.accepted_post0_count = numel(post);
summary.distance_bands = 10.^(-(1:8));
summary.chi_bands = 10.^((1:8)/2);
summary.s_band_counts = band_counts(s(post),summary.distance_bands,'below');
summary.d_band_counts = band_counts(d(post),summary.distance_bands,'below');
summary.chi_band_counts = band_counts(chi(post),summary.chi_bands,'above');
summary.s_band_fractions = safe_fractions(summary.s_band_counts,numel(post));
summary.d_band_fractions = safe_fractions(summary.d_band_counts,numel(post));
summary.chi_band_fractions = safe_fractions(summary.chi_band_counts,numel(post));
summary.regular_exact_hits = 0;
summary.degenerate_zeros = 0;
summary.inner_stationary = 0;
summary.unavailable_proxies = 0;
for k = post
    statuses = {observations{k}.entries.status};
    summary.regular_exact_hits = summary.regular_exact_hits+sum(strcmp(statuses,'regular_exact_hit'));
    summary.degenerate_zeros = summary.degenerate_zeros+sum(strcmp(statuses,'degenerate_zero'));
    summary.inner_stationary = summary.inner_stationary+sum(strcmp(statuses,'inner_stationary'));
    summary.unavailable_proxies = summary.unavailable_proxies+sum(isnan([observations{k}.entries.d]));
end
summary.observations = observations;
summary.line_trials = attach_trial_exposure(arguments,trialRecords);
end

function records = attach_trial_exposure(arguments,records)
for k = 1:numel(records)
    records(k).exposure = evaluate_singular_exposure(arguments,records(k).point);
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

function value = safe_ratio(numerator,denominator)
if isnan(numerator) || isnan(denominator) || denominator == 0
    value = NaN;
else
    value = numerator/denominator;
end
end

function counts = band_counts(values,bands,direction)
counts = zeros(1,numel(bands));
for j = 1:numel(bands)
    if strcmp(direction,'below')
        counts(j) = sum(values <= bands(j));
    else
        counts(j) = sum(values >= bands(j));
    end
end
end

function fractions = safe_fractions(counts,denominator)
if denominator == 0
    fractions = NaN(size(counts));
else
    fractions = counts/denominator;
end
end
