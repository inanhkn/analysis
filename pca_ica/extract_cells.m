function inv_quality_filters = extract_cells(movie_source,pca_source,varargin)

%   Cell extraction method that is based on an algorithm that essentially
%   solves the sparse source separation problem to find cell filters.
%   Traces are then found by using least squares.
%
%   Inputs:
%
%       movie_source: path to the movie matrix (height x width x frames)
%
%       pca_sources: path to the pca .mat file. It is assumed that there is
%       a variable named pca_filters that has size [# of PCs x # of pixels]
%       in the .mat file.
%       
%
%   Outputs:
%
%       Script saves the traces and filters in a .mat file.
%
%       inv_quality: Inverse quality metric that indicates how good each
%       found potential is as far as the extraction algorithm is concerned.
%       It is a [1 x # of extracted cells] array whose entries are
%       normalized to [(1/# of pixels),1] range. This array is also plotted
%       on the screen at the end of execution.
%
%   Hakan Inan (Aug 2015)
%

% Some parameters
mem_occup_scale_CPU = 0.5; % Occupy this fraction of available memory on RAM
mem_occup_scale_GPU = 0.7; % Occupy this fraction of available memory on GPU
corr_thresh = 0.1;
filter_thresh = 0.25;
max_num = 1000;
do_baseline_fix = 1;
good_cell_limit = 0.3; % threshold to call cell (wrt a custom metric, see code)
bad_cell_limit = 0.2; % threshold to call non-cell

if ~isempty(varargin)
    for k = 1:length(varargin)
        switch varargin{k}
            case 'fix_baseline'
                do_baseline_fix = varargin{k+1};
                if do_baseline_fix~=0 || do_baseline_fix~=1
                    error('fix_baseline must be 0 or 1');
                end
        end
    end
end

fprintf('%s: Loading movie singular vectors...\n',datestr(now));

pca = load(pca_source);
is_trimmed = pca.info.trim.enabled;
h = pca.info.movie_height;
w = pca.info.movie_width;
t = pca.info.movie_frames;
idx_kept = pca.info.trim.idx_kept;

fprintf('%s: Extracting filters...\n',datestr(now));

U = (pca.filters');
[N,num_pcs] = size(U);
norms_U = sqrt(sum(U.^2,2));
U_norm = bsxfun(@times,U,1./norms_U);

% Brute-force approach for 1-norm computation, use GPU if available
use_gpu = 0;
gpu_exists = gpuDeviceCount>0;
if gpu_exists
    avail_mem = compute_gpu_memory();    
    f = max(avail_mem/4 - N*(num_pcs+2),0); % maximum available element size 
    f = f*mem_occup_scale_GPU;
    chunk_size = floor(f/ (2*N+num_pcs)); %# of pixels at once
    use_gpu = chunk_size>=1;
end    
    
if use_gpu %GPU    
    fprintf('\t \t \t Using GPU to accelarate processing\n');
    U = gpuArray(U);
    one_norms = gpuArray(zeros(1,N,'single'));
    norms_U = gpuArray(norms_U);
    
    for i = 1:chunk_size:N
        fin = min(chunk_size-1,N-i);
        Q = bsxfun(@times,U(i:i+fin,:),1./norms_U(i:i+fin))';
        one_norms(i:i+fin) = sum(abs(U*Q),1);
        clear Q;
    end

    % Transfer variables back to CPU
    U = gather(U);
    one_norms = gather(one_norms);
    norms_U = gather(norms_U);
    
else % CPU
    avail_mem = compute_cpu_memory();
    f = avail_mem/4 ; % maximum available element size
    f = f*mem_occup_scale_CPU;
    chunk_size = floor(f/ (2*N+num_pcs)); %# of pixels at once
    
    one_norms = zeros(1,N);
    for i = 1:chunk_size:N
        fin = min(chunk_size-1,N-i);
        Q = U_norm(i:i+fin,:)';
        one_norms(i:i+fin) = sum(abs(U*Q),1);
        clear Q;
    end

end

% Extract filters recursively using the 1-norm criterion
idx_possible = 1:N;
F = zeros(N,max_num);
inv_quality_filters = zeros(1,max_num);
acc=0;

while true
    acc = acc+1;
    [val,idx_this] = min(one_norms(idx_possible));
    idx_this = idx_possible(idx_this);
    sig_this = U*U_norm(idx_this,:)';    
    correl = sig_this.*(1./norms_U);
    idx_possible = intersect(find(abs(correl)<corr_thresh),idx_possible);
    F(:,acc) = sig_this;
    inv_quality_filters(:,acc) = val;
    % Termination condition
    if isempty(idx_possible) || acc==max_num
        break;
    end
    
end

% Truncate F in case there are less components than max_num
F = F(:,1:acc);
inv_quality_filters = inv_quality_filters(1:acc)/sqrt(N);

if is_trimmed % Untrim the pixels
    F_temp = zeros(h*w,acc);
    F_temp(idx_kept,:) = F;
    F = F_temp;
end

fprintf('\t \t \t Extracted %d potential cells \n',acc);
fprintf('%s: Cleaning filters and removing duplicates...\n',datestr(now));
[F,idx] = modify_filters(F,filter_thresh);
inv_quality_filters = inv_quality_filters(idx);

% figure,
% plot(inv_quality_filters,'LineWidth',1.5);
% title('Inverse quality metric for the extracted potential cells','Fontsize',16);
% xlabel('Cell index','Fontsize',16)
% ylabel('Inverse quality(normalized to 1)','Fontsize',16)

fprintf('%s: Loading movie for trace extraction...\n',datestr(now));
M = load_movie(movie_source);

% Extract time traces
fprintf('%s: Extracting traces...\n',datestr(now));
M = reshape(M,h*w,t);
idx_nonzero = find(sum(F,2)>0);
M_small = M(idx_nonzero,:);
F_small = F(idx_nonzero,:);
T = (F_small'*F_small+0*eye(size(F,2))) \  (F_small'*M_small);
clear M;

% Reconstruction settings
info.type = 'PCA+SSS';
info.num_pairs = size(F,2);
info.movie_source = movie_source;
info.pca_source = pca_source; %#ok<*STRNU>

filters = reshape(F,h,w,size(F,2)); %#ok<*NASGU>
traces = T';

% Remove baseline from the traces
if do_baseline_fix
    for k = 1:size(F,2);
        traces(:,k) = fix_baseline(traces(:,k));
    end
end

% Sort cells wrt a metric that determines how good a trace looks
inv_quality_traces = badness_trace(traces);
[ss,idx] = sort(inv_quality_traces);
idx_stationary = sort(idx(ss>good_cell_limit));
idx_move = idx(ss<=good_cell_limit);
filters = filters(:,:,[idx_stationary,idx_move]);
traces = traces(:,[idx_stationary,idx_move]);
s1 = sprintf('First %d extracted cells are likely to be cells',sum(ss>good_cell_limit));
s2 = sprintf('Last %d extracted cells are likely to be non-cell',sum(ss<bad_cell_limit));
fprintf('%s: Cell Statistics:\n \t\t\t %s\n \t\t\t %s...\n',datestr(now),s1,s2);

% Save the result to mat file
%------------------------------------------------------------
timestamp = datestr(now, 'yymmdd-HHMMSS');
rec_savename = sprintf('rec_%s.mat', timestamp);

fprintf('%s: Writing the output to file... \n',datestr(now));
fprintf('%s: Output will be saved in %s \n',datestr(now),rec_savename);

save(rec_savename, 'info', 'filters', 'traces','-v7.3');

fprintf('%s: All done! \n',datestr(now));



%-------------------
% Internal functions
%-------------------

function avail_mem = compute_gpu_memory()
% Available memory on GPU in bytes

    D = gpuDevice;
    % Handle 2 different versions of gpuDevice
    if isprop(D,'AvailableMemory')
        avail_mem = D.AvailableMemory;
    elseif isprop(D,'FreeMemory')
        avail_mem = D.FreeMemory;
    else 
        avail_mem = 0;
    end
end

function avail_mem = compute_cpu_memory()
% Available memory on CPU in bytes

    if ispc % Windows
        [~,sys] = memory;
        avail_mem = (sys.PhysicalMemory.Available);
    elseif ismac %Mac
        % TODO
    else % Linux
         [~,meminfo] = system('cat /proc/meminfo');
         tokens = regexpi(meminfo,'^*MemAvailable:\s*(\d+)\s','tokens');
         avail_mem = str2double(tokens{1}{1})*1024;
    end
end

function [filters_out,idx_keep] = modify_filters(filters_in,filter_thresh)

    % Clean up the filters
    [masks,filters_int,cent_int,idx_keep] = cleanup_filters(filters_in,filter_thresh);

    % Identify duplicate cells
    new_assignments = compute_reassignments(masks,cent_int);

    % Write to output variable (merging the duplicates)
    filters_out = zeros(h*w,length(unique(new_assignments)));
    acc = 0;
    idx_merged = [];
    for idx_filt = 1:size(filters_int,2)
        cells_this = find(new_assignments==idx_filt);
        len = length(cells_this);
        if len==1 % not an overlapping cell
            acc = acc+1;
            filters_out(:,acc) = filters_int(:,idx_filt);
        elseif len>1 % overlapping cells, merge
            idx_merged = [idx_merged,setdiff(cells_this,idx_filt)];
            merged_filter = sum(filters_int(:,cells_this),2);
            merged_filter = merged_filter/norm(merged_filter);
            [~,merged_filter,~,~] = cleanup_filters(merged_filter,filter_thresh);
            if sum(merged_filter)>0
                acc = acc+1;
                filters_out(:,acc) = merged_filter;
            else
                idx_merged(end+1) = idx_filt;
            end
        end
    end
    fprintf('\t \t \t %d cells were merged into others \n',length(idx_merged))
    filters_out(:,acc+1:end) = []; % Remove the 0's in the end (if any)
    idx_keep(idx_merged) = [];

end

function [masks,filters_out,cent_out,idx_out] = cleanup_filters(filters_in,filter_thresh)
    
    num_filters = size(filters_in,2);
    cent_out = zeros(2,num_filters);
    
    % Remove the filter baselines
    meds = median(filters_in,1);
    filters_out = bsxfun(@minus,filters_in,meds);

    % Reshape filters_out into 2D
    filters_out = reshape(filters_out,h,w,num_filters);

    % Threshold filters - Deal with multiple boundaries
    masks = zeros(h,w,num_filters);
    elim = []; % filters to eliminate due to size requirement
    for idx_filt = 1:num_filters
        this_filter = filters_out(:,:,idx_filt);
        [boundaries, ~] = compute_ic_boundary(this_filter, filter_thresh);
        this_mask = poly2mask(boundaries{1}(:,1), boundaries{1}(:,2), h, w); 
        s = regionprops(this_mask,'centroid');
        if isempty(s)
            cent_out(:,idx_filt) = [0;0];
            elim(end+1) = idx_filt;
        else
            cent_out(:,idx_filt) = s(1).Centroid;
        end
        masks(:,:,idx_filt) = this_mask;
        filters_out(:,:,idx_filt) = this_filter .* this_mask;
        if nnz(this_mask) <= 10
            elim(end+1) = idx_filt; %#ok<AGROW>
        end
    end

    % Reshape filters_out back into 1D
    filters_out = reshape(filters_out,h*w,num_filters);
    
    % Eliminate tiny blobs
    elim = unique(elim);
    if ~isempty(elim)
        fprintf('\t \t \t %d cells were eliminated due to minimum size requirement(<10 pixels)\n',length(elim));
    end
    filters_out(:,elim) = [];
    masks(:,:,elim) = [];
    cent_out(:,elim) = [];
    idx_out = setdiff(1:num_filters,elim);
end

function new_assignments = compute_reassignments(masks,cent)
    
    num_filters = size(masks,3);
    
    % Calculate the matrix of centroid distances
    NN = repmat(sum(cent.^2,1),num_filters,1);
    Dist = sqrt(max(NN+NN'-2*cent'*cent,0)); %#ok<MHERM>
    Dist(Dist<1e-3) = inf; % Set diagonals to infinity
    Dist = Dist < 15; % Retain only the closeby cells
    
    % Calculate overlap between closeby cells
    J_sim = cell(num_filters,1);
    for idx_filt = 1:num_filters
        closeby_cells = find(Dist(idx_filt,:)==1);
        if ~isempty(closeby_cells)
            sim = zeros(length(closeby_cells),2);
            for j = 1:length(closeby_cells)
                sim(j,:) = [closeby_cells(j),compute_overlap(masks(:,:,idx_filt),masks(:,:,closeby_cells(j)))];
            end
            J_sim{idx_filt} = sim;
        end
    end
    
    % Merge cells that have similarity above a threshold;
    sim_thresh = 0.8;
    new_assignments = (1:num_filters)';
    for idx_filt = 1:num_filters
        if ~isempty(J_sim{idx_filt}) 
            for j = 1:size(J_sim{idx_filt},1) % for all cells that overlap with this
                this_sim = J_sim{idx_filt}(j,2);
                if this_sim > sim_thresh % similarity is above threshold
                    that_cell = J_sim{idx_filt}(j,1);
                    new_assignments(new_assignments==new_assignments(that_cell)) = idx_filt;
                    J_sim{that_cell} = [];
                end
            end
        end
    end
    
end

function overlap = compute_overlap(mask1, mask2)
    intrsct = nnz(mask1 & mask2);
    siz1 = nnz(mask1); siz2 = nnz(mask2);
    overlap = intrsct / min(siz1,siz2);
end

function val = badness_trace(traces)
%Determine the "spiky-ness" by comparing distribution to gaussian  

    num_cells = size(traces,2);
    val = zeros(1,num_cells);
    for idx_cell =1:num_cells
        tr = traces(:,idx_cell);
        tr(tr<0) = [];
        tr = [tr;-tr]; %make distribution symmetric
        tr = tr/std(tr); % standardize
        [c,x] = hist(tr,100);
        f_g = 1/sqrt(2*pi)*exp(-x.^2/2); % gaussian pdf
        f_r = c/length(tr)/(x(2)-x(1)); % empirical pdf
        val(idx_cell) = norm(f_g-f_r,2);
    end
end

end
