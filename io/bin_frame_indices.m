function binned_frame_indices = bin_frame_indices(frame_indices, bin_factor)
% Bin the frame indices temporally by `bin_factor`. See also
%   `bin_movie_in_time`.
% 
% Inputs:
%   frame_indices: [num_trials x k] matrix where the i-th row indicates the
%       frame indices of trial i, where k could be:
%           k = 4: [start open-gate close-gate end]
%           k = 2: [start end]
%
%   bin_factor: Integer indicating the binning factor
%
% Output:
%   binned_frame_indices: Same dimensions as frame_indices, but where the
%       indices have been converted to account for temporal binning

% Number of frames in the pre-binned movie
num_frames = frame_indices(end,end);

% Number of frames after binning. See `bin_movie_in_time`. Note that some
%   trailing frames can be dropped.
num_downsampled_frames = floor(num_frames/bin_factor);

% Clamp the maximum frame index at `num_downsmapled_frames`
binned_frame_indices = min(ceil(frame_indices/bin_factor),...
                           num_downsampled_frames*ones(size(frame_indices)));