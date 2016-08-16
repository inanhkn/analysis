function neuron_factor_plots(cpd,md,trial_map,varargin)

% parse optional inputs
params = inputParser;
params.addParameter('trialcolor', 'start', ...
                    @(x) any(validatestring(x,['start','error','none'])));
params.addParameter('trialax', 'order', ...
                    @(x) any(validatestring(x,['order','number'])));
params.addParameter('factor_order', 'lambda', ...
                    @(x) any(validatestring(x,['lambda','trialvar'])));
params.addParameter('neuron_plot', 'bars', ...
                    @(x) any(validatestring(x,['bars','plotmatrix'])));
params.parse(varargin{:});
res = params.Results;

% tensor dimensions (neurons x time x trial)
factors = cpd.factors;
nn = size(factors.neuron,1);
nr = size(factors.neuron,2);
nk = size(trial_map,1);

% plot factors in order of decreasing variability across trials
switch res.factor_order
    case 'lambda'
        [~,fo] = sort(cpd.lambda,'descend');
    case 'trialvar'
        factvar = zeros(nr,1);
        for r = 1:nr
            factvar(r) = std(factors.trial(:,r));
        end
        [~,fo] = sort(factvar,'descend');
    otherwise
        error('wtf')
end

% trial coloring labels
red = [1.0 0.0 0.0];
blue = [0.0 0.7 1.0];
switch res.trialcolor
    case 'start'
        tc = {'east', 'E', blue;
              'west', 'W', red};
    case 'end'
        tc = {'north', 'N', blue;
              'south', 'S', red};
    case 'correct'
        tc = {'1', '1', blue;
              '0', '0', red};
    otherwise
        tc = {};
end

% set trial colors
trial_colors = zeros(nk,3);
if ~isempty(tc)
    for k = 1:nk
        trial = md.day(trial_map(k,1)).trials(trial_map(k,2));
        trialdata = num2str(trial.(res.trialcolor));
        idx = strcmp(tc(:,1), trialdata);
        trial_colors(k,:) = tc{idx,3};
    end
end

% plot trials by order or by true number
switch res.trialax
    case 'order'
        trial_ax = 1:nk;
    case 'number'
        trial_ax = trial_map(:,2);
        for d = sort(md.valid_days,'ascend')
            n = length(md.day(d).trials);
            idx = trial_map(:,1) > d;
            trial_ax(idx) = trial_ax(idx) + n;
        end
end

% make the figure
figure()

subplot(1,3,1)
switch res.neuron_plot
    case 'bars'
        [~,no] = sort(cpd.factors.neuron(:,fo(1)),'descend');
        set(gca,'Visible','off')
        pos = get(gca,'Position');
        width = pos(3);
        height = pos(4)/10;
        space = .02; % 2 percent space between axes
        pos(1:2) = pos(1:2) + space*[width height];

        ax = gobjects(10);
        yl = 1.01*max(abs(factors.trial(:)));
        for r = 1:nr
            axPos = [pos(1) pos(2)+(10-r)*height ...
                        width*(1-space) height*(1-space)];
            ax(r) = axes('Position',axPos);
            hold on
            bar(1:nn,factors.neuron(no,r))
            set(gca,'xtick',[],'xlim',([0,nn+1]),...
                    'ytick',[-0.3,0.3],'ylim',[-0.5,0.5])
        end
    case 'plotmatrix'
        plotmatrix(factors.neuron(:,fo))
        title('neuron factors')
end

subplot(1,3,2)
set(gca,'Visible','off')
pos = get(gca,'Position');
width = pos(3);
height = pos(4)/10;
space = .02; % 2 percent space between axes
pos(1:2) = pos(1:2) + space*[width height];

ax = gobjects(10);
yl = 1.01*max(abs(factors.trial(:)));
for r = 1:nr
    axPos = [pos(1) pos(2)+(10-r)*height ...
                width*(1-space) height*(1-space)];
    ax(r) = axes('Position',axPos);
    hold on
    plot(trial_ax,factors.trial(:,fo(r)),'-k')
    scatter(trial_ax,factors.trial(:,fo(r)),20,trial_colors,'filled')
    set(gca,'xtick',[])
    ylim([-yl yl])
end

subplot(1,3,3)
set(gca,'Visible','off')
pos = get(gca,'Position');
width = pos(3);
height = pos(4)/10;
space = .02; % 2 percent space between axes
pos(1:2) = pos(1:2) + space*[width height];

ax = gobjects(10);
for r = 1:nr
    axPos = [pos(1) pos(2)+(10-r)*height ...
                width*(1-space) height*(1-space)];
    ax(r) = axes('Position',axPos);
    hold on
    plot(factors.time(:,fo(r)),'-k','linewidth',2)
    set(gca,'xtick',[])
end
title(ax(1),'time factors')