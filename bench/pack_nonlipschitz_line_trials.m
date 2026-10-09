function rows = pack_nonlipschitz_line_trials(prob,runTrial,records)
%PACK_NONLIPSCHITZ_LINE_TRIALS Compact diagnostic trial records into columns.

argumentMetadata = nonlipschitz_arguments(prob);
argumentIds = {argumentMetadata.argument_id};
n = numel(records);
run_trial = repmat(uint16(runTrial),n,1);
iteration = zeros(n,1,'uint16');
line_trial = zeros(n,1,'uint16');
alpha = zeros(n,1);
accepted = false(n,1);
s = NaN(n,1); d = NaN(n,1); chi = NaN(n,1);
s_argument_index = zeros(n,1,'uint8');
d_argument_index = zeros(n,1,'uint8');
chi_argument_index = zeros(n,1,'uint8');
distance_kind = zeros(n,1,'uint8');
regular_exact_hits = zeros(n,1,'uint8');
degenerate_zeros = zeros(n,1,'uint8');
inner_stationary = zeros(n,1,'uint8');
for k = 1:n
    observation = records(k).exposure;
    statuses = {observation.entries.status};
    iteration(k) = uint16(records(k).iteration);
    line_trial(k) = uint16(records(k).trial);
    alpha(k) = records(k).alpha;
    accepted(k) = records(k).accepted;
    s(k) = observation.s; d(k) = observation.d; chi(k) = observation.chi;
    s_argument_index(k) = argument_index(observation.s_argument_id,argumentIds);
    d_argument_index(k) = argument_index(observation.d_argument_id,argumentIds);
    chi_argument_index(k) = argument_index(observation.chi_argument_id,argumentIds);
    distance_kind(k) = distance_kind_code(observation.d_distance_kind);
    regular_exact_hits(k) = uint8(sum(strcmp(statuses,'regular_exact_hit')));
    degenerate_zeros(k) = uint8(sum(strcmp(statuses,'degenerate_zero')));
    inner_stationary(k) = uint8(sum(strcmp(statuses,'inner_stationary')));
end
rows = table(run_trial,iteration,line_trial,alpha,accepted,s,d,chi, ...
    s_argument_index,d_argument_index,chi_argument_index,distance_kind, ...
    regular_exact_hits,degenerate_zeros,inner_stationary);
end

function index = argument_index(argumentId,argumentIds)
index = find(strcmp(argumentIds,argumentId),1);
if isempty(index), index = 0; end
index = uint8(index);
end

function code = distance_kind_code(kind)
if strcmp(kind,'exact')
    code = uint8(1);
elseif strcmp(kind,'first_order_proxy')
    code = uint8(2);
else
    code = uint8(0);
end
end

