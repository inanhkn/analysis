function view_movie(M)

num_frames = size(M,3);

h = imagesc(M(:,:,1));
axis image;
colormap gray;
xlabel('x [px]');
ylabel('y [px]');

for k = 1:num_frames
    title(sprintf('Frame %d of %d', k, num_frames));
    set(h, 'CData', M(:,:,k));
    drawnow;
end