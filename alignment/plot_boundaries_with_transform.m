function plot_boundaries_with_transform(ds, linespec, linewidth, filled_cells, tform)
    % Plot boundaries as a single color, with an optional transform. Can
    % subselect cells to be filled in
    for k = 1:ds.num_cells
        boundary = ds.cells(k).boundary;
        if ~isempty(tform) % Optional spatial transform
            boundary = transformPointsForward(tform, boundary);
        end
        if ismember(k, filled_cells)
            fill(boundary(:,1), boundary(:,2), linespec, 'LineWidth', linewidth);
        elseif ds.is_cell(k)
            plot(boundary(:,1), boundary(:,2), linespec, 'LineWidth', linewidth);
        end
        hold on;
    end
end