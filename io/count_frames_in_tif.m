function total_frames = count_frames_in_tif(path_to_tif)
% Computes the number of frames contained in all TIF files of
%   the specified directory
%
% Example use: "count_frames_in_tif(pwd)"
%   in a directory that contains TIF files
%
% 2015-01-02 Tony Hyun Kim

tif_files = dir(fullfile(path_to_tif,'*.tif'));
num_files = length(tif_files);
fprintf('Found %d TIF files in "%s"\n', num_files, path_to_tif);

total_frames = 0;
for i = 1:num_files
    tif_filename = tif_files(i).name;
    tif_info = imfinfo(tif_filename);
    
    num_frames = length(tif_info);
    total_frames = total_frames + num_frames;
    
    fprintf('  %d: "%s" has %d frames\n',...
        i, tif_filename, num_frames);
end

fprintf('  Total frame count is %d\n', total_frames);