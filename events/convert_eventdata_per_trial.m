function events_per_trial = convert_eventdata_per_trial(eventdata, trial_indices)
% Reorganize event data by trials -- as required by DaySummary event
% storage. Namely,
%
% Given:
%   eventdata: {num_cells x 1} cell where,
%       eventdata{k}: [num_events x 3] is the event data for cell k
%
% Return:
%   events_per_trial: {num_trials x 1} cell where,
%       events_per_trial{t}: {num_cells x 1} contains the event data for
%       all cells for trial t. Frame numbers are referenced to each trial.
%

num_trials = size(trial_indices, 1);

% A lookup table from frames to trial index
frames2trial = zeros(trial_indices(end,end), 1);
for k = 1:num_trials
    frames2trial(trial_indices(k,1):trial_indices(k,end)) = k;
end

num_cells = length(eventdata);
events = cell(num_cells, num_trials);

for c = 1:num_cells
    eventdata_c = eventdata{c};    
    if ~isempty(eventdata_c)
        num_events = size(eventdata_c,1);
        events2trial = frames2trial(eventdata_c(:,2));

        new_trial_inds = [1; find(diff(events2trial))+1];
        
        % Note: A trial "chunk" is the set of events that belong to the
        % same trial
        num_trial_chunks = length(new_trial_inds);
        for k = 1:num_trial_chunks
            % Pull out a single trial chunk from eventdata
            start_idx = new_trial_inds(k);
            if k ~= num_trial_chunks
                end_idx = new_trial_inds(k+1)-1;
            else
                end_idx = num_events;
            end
            trial_eventdata = eventdata_c(start_idx:end_idx, :);

            % Reindex the frame indices on a per-trial basis
            trial_idx = events2trial(start_idx);
            trial_init_frame = trial_indices(trial_idx, 1);
            trial_eventdata(:,1:2) = trial_eventdata(:,1:2) - trial_init_frame + 1;

            events{c, trial_idx} = trial_eventdata;
        end
    end
end

events_per_trial = cell(num_trials, 1);
for k = 1:num_trials
    events_per_trial{k} = events(:,k);
end

end % compute_eventdata_per_trial