function factor_plots(session,decomp,trial_idx)
% FACTOR_PLOTS, browse plots for each cpd factor. 
%
%     FACTOR_PLOTS(session,decomp,trial_idx)

% tensor dimensions (neurons x time x trial)
factors = decomp.factors;
nn = size(factors.neuron,1);
nt = size(factors.time,1);
nk = size(factors.trial,1);

% east and west starts
ie = [];
iw = [];
for it = 1:length(trial_idx)
	trial = session.trials(trial_idx(it));
	if strcmp(trial.start,'east')
		ie = [ie;it];
		continue
	end
	if strcmp(trial.start,'west')
		iw = [iw;it];
		continue
	end
	error('assertion error')
end

%figure('Position', [0, 0, 300, 400])
figure()
for n = 1:decomp.rank
    subplot(2,1,1)
    plot(1:nt,factors.time(:,n),'-b')
    xlabel('time')
    xlim([1,nt])
    subplot(2,1,2); cla; hold on
    plot(1:nk,factors.trial(:,n),'-k')
    plot(ie,factors.trial(ie,n),'.r','markersize',20)
    plot(iw,factors.trial(iw,n),'.b','markersize',20)
    xlabel('trials')
    xlim([1,nk])
    pause    
end


