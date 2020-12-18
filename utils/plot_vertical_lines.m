function plot_vertical_lines(xs, y_lims, linespec)
    % Built-in 'xline' seems to be extremely slow to render
    xs = xs(:)'; % Force row vector
    y_lims = y_lims(:)';
    
    num_x = length(xs);
    X = kron(xs, [1 1 NaN]);
    Y = repmat([y_lims NaN], 1, num_x);
    
    plot(X,Y,linespec);
end