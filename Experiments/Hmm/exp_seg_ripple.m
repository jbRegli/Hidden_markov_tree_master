%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%         OK
% This script realizes a segmentation test of the STHMT on genereted      %
% cropped sonar images from MUSSEL AREA C dataset.                        %
% The SCHMT is trained to model squares.                                  %
%                                                                         %
% BEST PARAMETER SO FAR: CS=0.8                                           %
% n_image = 0; n_state = 2; n_step = 100; eps_uni= false; cv_sens = 1e-5; %
% filt_opt.J = 5; filt_opt.L = 3; filt_opt.filter_type = 'morlet';        %
% scat_opt.oversampling = 2; scat_opt.M = 2;                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all

% Initialization:
n_image = 0; % 0 for all the images

% Number of states:
n_state = 2;

% Number of optimization step:
n_step = 100;

% Model distribution:
distribution = 'MixtGauss';
% Epsilon uniform over the pixels of a father/son transition
eps_uni= false;
% Display error messages:
verbose = false;
% Sensibility f the convergence test:
cv_sens = 1e-5;

% Data path:
dir_training = '/home/jeanbaptiste/Datasets/Sonar/Area_C_crops/Training/';

% ST Parameters:
filt_opt.J = 5; % scales
filt_opt.L = 3; % orientations
filt_opt.filter_type = 'morlet';
scat_opt.oversampling = 2;
scat_opt.M = 2;

% CLASS 1 - RIPPLE - TRAINING: 
label_ripple = 'Ripple/'; 
path_to_training_ripple = fullfile(dir_training, label_ripple);

fprintf('------ TRAINING RIPPLE ------ \n')

% ST:
set_S_ripple = ST_class(path_to_training_ripple, filt_opt, scat_opt, n_image);

% Prepare the scattering structure for HMM:
for im=1:length(set_S_ripple)
    set_S_ripple{im} = hmm_prepare_S(set_S_ripple{im}, n_state);
end

% Hmm model:
[theta_est_ripple, ~, ~] = ...
    conditional_EM(set_S_ripple, n_step, n_state, distribution, ...
        eps_uni, verbose, 10, cv_sens);

clear set_S_ripple

% CLASS 2 - Mix - TRAINING: 
label_seabed = 'Mix'; 
path_to_training_seabed = fullfile(dir_training, label_seabed);

fprintf('------ TRAINING SEABED ------ \n')

% ST:
set_S_seabed = ST_class(path_to_training_seabed, filt_opt, scat_opt, n_image);

% Prepare the scattering structure for HMM:
for im=1:length(set_S_seabed)
    set_S_seabed{im} = hmm_prepare_S(set_S_seabed{im}, n_state);
end
%
% Hmm model:
[theta_est_seabed, ~, ~] = ...
    conditional_EM(set_S_seabed, n_step, n_state, distribution, ...
        eps_uni, verbose, 10, cv_sens);                          

clear set_S_seabed
    

%% MAP - SEGMENTATION SCORE:
fprintf('------ TESTING ------ \n')
dname = '/home/jeanbaptiste//Datasets/Sonar/UDRC_datacentre_MCM_sonar_data/Area_C/';
fname = 'mod_MUSCLE_COL2_080424_1_13_s_3506_3669_40_150.mat';
dfname = strcat(dname, fname);
load(dfname, 'sas_tile_raw');
X = 20*log10(abs(sas_tile_raw)+1);
clear sas_tile_raw
X = rot90(X,-1);
X = X(1:end - mod(size(X,1),2), 1:end - mod(size(X,2),2));

s_X = size(X);

x_range = 1:99:s_X(1);
y_range = 1:99:s_X(2);

segmentation = zeros(s_X(1),s_X(2));

reverseStr = '';
counter= 1;
n_patch = (length(y_range)-1)*(length(x_range)-1);

for i=1:(length(x_range)-1)
    for j=1:(length(y_range)-1)
        
        % Print time remaining:
        if counter == 1
            tic
            msg = sprintf('--- Patch %i/%i', counter, ...
                (length(y_range)-1)*(length(x_range)-1));
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));   
        elseif counter == 2
           time = toc;
           
           msg = sprintf(['--- Patch %i/%i --- Expected remaining ' ...
                'time: %.4f s. \r '], ...
                counter, n_patch,...
                (n_patch-counter) * time);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
        else
           msg = sprintf(['--- Patch %i/%i --- Expected remaining ' ...
                'time: %.4f s. \r '], ...
                counter, n_patch,...
                (n_patch-counter) * time);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
        
        x = X(x_range(i):x_range(i+1),y_range(j):y_range(j+1),:);
        
        % Scattering transform of the patch:
        Wop = wavelet_factory_2d(size(x), filt_opt, scat_opt);
        S_seg = scat(x, Wop);
        
        S_seg = hmm_prepare_S(S_seg, n_state);
        
        % MAP patch = ripple:
        [tmp_P_hat_ri, ~] = ...
            hmm_MAP(S_seg, theta_est_ripple, false);
        [tmp_P_hat_se, ~] = ...
            hmm_MAP(S_seg, theta_est_seabed, false);
    
        P_hat_ri = mean(mean(tmp_P_hat_ri));
        P_hat_se = mean(mean(tmp_P_hat_se));
        
        % Segmentation:
        if P_hat_ri > P_hat_se
            % Ripple:
            segmentation(x_range(i):x_range(i+1),y_range(j):y_range(j+1)) = 1;
        else
            % Seabed:
            segmentation(x_range(i):x_range(i+1),y_range(j):y_range(j+1)) = 2;
        end
        
        counter = counter + 1;
    end
end

% Plot:
figure
subplot(2,1,1)
imagesc(X)
subplot(2,1,2)
imagesc(segmentation)
colormap pink





