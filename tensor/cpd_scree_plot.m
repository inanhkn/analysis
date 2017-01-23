function cpd_scree_plot(models)
% CPD_SCREE_PLOT, plots a scree plot given struct array of model fits
%
%     models = fit_cpd(data, ...)
%     CPD_SCREE_PLOT(MODELS)
%

% collect rank and rsq of each model
n_replicates = size(models, 1);
max_rank = size(models, 2);

% scree plot
figure();
hold on
ln = plot(1:max_rank, [models(1,:).error], '-', 'linewidth', 2, 'color', [1.0 0.4 0.4]);
for r = 1:max_rank
    err = [models(:,r).error];
    plot(r*ones(n_replicates,1), err, '.k', 'markersize', 20);
end
xlabel('rank of model')
ylabel('normalized error')
ylim([0,1])

figure();
hold on
for r = 1:max_rank
	similarity = [models(:,r).similarity];
    plot(r*ones(n_replicates,1), similarity, '.k', 'markersize', 20);
end
xlabel('rank of model')
ylabel('similarity to best fit')
ylim([0,1])

figure();
colors = [linspace(0,1,max_rank)', zeros(max_rank,1), zeros(max_rank,1)];
for r = 1:max_rank
	hold on
	x = (1:n_replicates-1)';
	y = [models(2:end,r).similarity]';
    scatter(x, y, [], colors(r,:), 'filled');
    yy = smooth(x, y, 10);%,'loess');
    ln = plot(x, yy, 'linewidth', 2);
    ln.Color=[colors(r,:), 0.5];
end
xlabel('rank of model')
ylabel('similarity to best fit')
ylim([0,1])
