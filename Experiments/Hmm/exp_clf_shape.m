%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%         OK
% This script realizes a classification test of the STHMT on genereted    %
% shapes (square and circle).                                             %
% The SCHMT is trained to model squares.                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all

%% Initialization:
% Size of the simulated images:
s_im = [32 32];

% Number of states:
n_state = 2;

% Number of "images" in the training set;
n_image = 300;

% Number of optimization step:
n_step = 100;

% Mixing time:
mixing = min(round(n_step/10),30);

% Model distribution:
distribution = 'MixtGauss';
% Epsilon uniform over the pixels of a father/son transition
eps_uni= false;
% Display error messages:
verbose = false;
% Sensibility f the convergence test:
cv_sens = 1e-5;

%% CLASS 1 - SQUARE - TRAINING: 
path_to_square = {'square', n_image, s_im};
fprintf('------ TRAINING SQUARE ------ \n')

% Parameters:
filt_opt.J = 3; % scales
filt_opt.L = 3; % orientations
filt_opt.filter_type = 'morlet';
scat_opt.oversampling = 2;
scat_opt.M = 2;

% ST:
set_S_square = ST_class(path_to_square, filt_opt, scat_opt);

% Prepare the scattering structure for HMM:
for im=1:length(set_S_square)
    set_S_square{im} = hmm_prepare_S(set_S_square{im}, n_state);
end

% Hmm model:
[theta_est_square, cv_stat_square, dob_square] = ...
    conditional_EM(set_S_square, n_step, n_state, distribution, ...
        eps_uni, verbose, mixing, cv_sens);

%% CLASS 1 - CIRCLE - TRAINING: 
path_to_circle = {'circle', n_image, s_im};
fprintf('------ TRAINING CIRCLE ------ \n')

% ST:
set_S_circle = ST_class(path_to_circle, filt_opt, scat_opt);

% Prepare the scattering structure for HMM:
for im=1:length(set_S_circle)
    set_S_circle{im} = hmm_prepare_S(set_S_circle{im}, n_state);
end

% Hmm model:
[theta_est_circle, cv_stat_circle, dob_circle] = ...
    conditional_EM(set_S_circle, n_step, n_state, distribution, ...
        eps_uni, verbose, mixing, cv_sens);                          

%% MAP - CLASSIFICATION SCORE:
fprintf('------ TESTING ------ \n')
n_test = 50;
score_square = 0;
score_circle = 0;

% (Image_class)_(Model_class):
P_hat_sq_sq = cell(1,n_test);
P_hat_sq_ci = cell(1,n_test);
P_hat_ci_sq = cell(1,n_test);
P_hat_ci_ci = cell(1,n_test);

% Creating the test set:
path_to_square = {'square', n_test, s_im};
square_S = ST_class(path_to_square, filt_opt, scat_opt);
path_to_circle = {'circle', n_test, s_im};
circle_S = ST_class(path_to_circle, filt_opt, scat_opt);

% Prepare the scattering structure for HMM:
fprintf(' * MAP \n')
for im=1:n_test
    square_S{im} = hmm_prepare_S(square_S{im}, n_state);
    circle_S{im} = hmm_prepare_S(circle_S{im}, n_state);
    
    % MAP model = square:
    [tmp_P_hat_sq_sq, H_tree_square] = ...
        hmm_MAP(square_S{im}, theta_est_square, false);
    [tmp_P_hat_sq_ci, H_tree_circle] = ...
        hmm_MAP(square_S{im}, theta_est_circle, false);
    
    P_hat_sq_sq{im} = mean(mean(tmp_P_hat_sq_sq));
    P_hat_sq_ci{im} = mean(mean(tmp_P_hat_sq_ci));

    if max(P_hat_sq_ci{im}, P_hat_sq_sq{im}) == P_hat_sq_sq{im}
        score_square = score_square + 1/n_test;
    end
    
    % MAP model = circle:
    [tmp_P_hat_ci_sq, ~] = ...
        hmm_MAP(circle_S{im}, theta_est_square, false);
    [tmp_P_hat_ci_ci, ~] = ...
        hmm_MAP(circle_S{im}, theta_est_circle, false);
    
    P_hat_ci_sq{im} = mean(mean(tmp_P_hat_ci_sq));
    P_hat_ci_ci{im} = mean(mean(tmp_P_hat_ci_ci));

    if max(P_hat_ci_ci{im}, P_hat_ci_sq{im}) == P_hat_ci_ci{im}
        score_circle = score_circle + 1/n_test;
    end
end

fprintf('The total classification score is %.4f. \n', ...
    (score_circle + score_square)/2)
fprintf('The classification score for squares is %.4f. \n', ...
    score_square)
fprintf('The total classification score for circles is %.4f. \n', ...
    score_circle)