function M = load_movie_from_dcimg(source)
% A simple wrapper to load Hamamatsu DCIMG files.
% TODO: Is pulling one frame at a time truly the only way to access data?

[A, num_frames] = dcimgmatlab(int32(0), source);
[height, width] = size(A);

M = zeros(height, width, num_frames, 'uint16');
for k = 1:num_frames
    if (mod(k,1000)==0)
        fprintf('  %s: Frames %d / %d loaded\n', datestr(now), k, num_frames);
        
        % DCIMG MEX accumulates in memory. Need to clear it out
        clear mex; %#ok<*CLMEX>
    end
    
    % Note:
    %   - 0-based indexing
    %   - Transpose of image
    M(:,:,k) = dcimgmatlab(int32(k-1), source)';
end

clear mex;
fprintf('  %s: Done!\n', datestr(now));