%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script realizes a set of classification tests on few classes from  %
% the KTH texture dataset in order to draw performance statistics.        %
% n_exp = 100;                                                            %
%                                                                         %
% BEST PARAMETER SO FAR: CS=0.5                                           %
% n_training = 5; n_testing = 20;                                         %
% --- ST ---                                                              %                                                   
% filt_opt.J = 4; filt_opt.L = 3; filt_opt.filter_type = 'morlet';        %
% scat_opt.oversampling = 2; scat_opt.M = 2;                              %
% --- EM ---                                                              %                                                   
% EM_meta.n_step = 50; EM_meta.n_state = 2;                               %
% EM_meta.distribution = 'MixtGauss'; EM_meta.eps_uni = true;             %
% EM_meta.mixing = 10; EM_meta.cv_sens = 1e-4; EM_meta.cv_steps = 5;      %
% EM_meta.cv_ratio = 0.8; EM_meta.rerun = true; EM_meta.rerun_count = 0;  %
% EM_meta.rerun_lim = 20;                                                 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all

%% ===== Meta parameters: =====
% Number of experiment:
n_exp = 100;
score = cell(1,n_exp);
csv_name = 'V4_stat_clf_KTH_multi_N10_J3_L3.csv';
mat_name = 'V4_theta_N2_est_';
max_score = 0;
format = 'mat';
directory = './Save/Models/KTH/';

for experiment=1:n_exp
    fprintf('--------- EXPERIMENT %i/%i --------- \n', experiment, n_exp)
    
    %% ===== PREPARE: SCHMT =====
    n_training = 10; % Dataset training + testing has 160 images per class 
    n_testing = 20;

    % EM parameters:
    EM_meta.n_step = 50;
    EM_meta.n_state = 2;
    EM_meta.distribution = 'MixtGauss';
    EM_meta.eps_uni = true;
    EM_meta.mixing = 10;
    EM_meta.cv_sens = 1e-4;
    EM_meta.cv_steps = 5;
    EM_meta.cv_ratio = 0.8;
    EM_meta.rerun = true;
    EM_meta.rerun_count = 0;
    EM_meta.rerun_lim = 20;

    options.verbose = false;

    % ST Parameters:
    filt_opt.J = 3; % scales
    filt_opt.L = 3; % orientations
    filt_opt.filter_type = 'morlet';
    scat_opt.oversampling = 2;
    scat_opt.M = 2;
    
    %% ===== PREPARE: DATA =====
    % Data path:
    im_format = 'png';
    dir_data = '/home/jeanbaptiste/Datasets/Texture/KTH_TIPS/';

    % Labels available:
    % 'aluminium_foil' , 'brown_bread', 'corduroy' , 'cotton' , ...
    %    'cracker' , 'linen' , 'orange_peel' , 'sandpaper' , 'sponge' ,...
    %    'styrofoam'
    S_label = {'aluminium_foil' , 'brown_bread', 'corduroy' , 'cotton' , ...
            'cracker' , 'linen' , 'orange_peel' , 'sandpaper' , 'sponge' ,...
            'styrofoam'}; 
    n_label = length(S_label);
    
    %% ===== PREPARE: SCORE STRUCTURE =====
    score{experiment}.clf_score = 0.0;
    score{experiment}.confusion = zeros(n_label, n_label);
    
    %% ===== PREPARE: TRAINING & TEST SETS =====
    % Create a random sampler:
    allFile = zeros(1,n_label);
    for label=1:n_label
        tmp_file = dir(fullfile(dir_data, S_label{label}, '/', ['*.' im_format]));
        tmp_name = {tmp_file.name};
        allFile(label) = length(tmp_name);
    end

    rdm_spl = randsample(1:min(allFile), min(allFile));

    rdm_training = rdm_spl(1:n_training);
    rdm_test = rdm_spl(n_training+1:n_training+ n_testing); % rdm_spl(n_training+1:end);

    clear allFiles tmp_file tmp_name
    
    %% ===== TRAINING: =====
    theta_est = cell(1,n_label);
    cv_stat = cell(1,n_label);
    for label=1:n_label
        path_to_training = {{dir_data, S_label{label}, im_format}, rdm_training};

        fprintf('------ TRAINING CLASS %s %i/%i ------ \n', ...
            S_label{label}, label, n_label)

        % ST:
        set_S = ST_class(path_to_training, filt_opt, scat_opt, n_training, im_format);

        % Prepare the scattering structure for HMM:
        for im=1:length(set_S)
            set_S{im} = hmm_prepare_S(set_S{im}, EM_meta.n_state);
        end

        % Hmm model:
        [theta_est{label}, cv_stat{label}, ~] = ...
            conditional_EM(set_S, EM_meta, options);
    end
    
    %% ===== MAP - CLASSIFICATION SCORE: =====
    fprintf('------ TESTING ------ \n')

    n_test = length(rdm_test);

    % confusion = matrix(n_label, n_label)
    % confusion(i,j): number of object i labeled as j
    confusion = zeros(n_label, n_label);

    % P_hat = matrix(n_label, n_label)
    % P_hat(i,j) probability of an object of class i given model for class j
    P_hat = zeros(n_label, n_label);

    path_to_test = cell(1, n_label);
    S_test = cell(1, n_label);

    for label = 1:n_label
        path_to_test{label} = {{dir_data, S_label{label}, im_format}, ...
            rdm_test};
        S_test{label} = ST_class(path_to_test{label}, ...
            filt_opt, scat_opt, n_test, im_format);
    end

    % Prepare the scattering structure for HMM:
    im_count = 1;
    for im=1:n_test
        for label=1:n_label
            S_test{label}{im} = hmm_prepare_S(S_test{label}{im},...
                EM_meta.n_state);

            for label_model=1:n_label
                [tmp_P_hat, ~] = ...
                    hmm_MAP(S_test{label}{im}, theta_est{label_model}, false);

                P_hat(im_count, label_model) = mean(mean(tmp_P_hat));
                test_label(im_count) = label;
            end
            im_count = im_count + 1;

            % Rescaling:
    %         tmp_mean = mean(P_hat(:,:, im_count));
    %         P_hat(:,:, im_count) = P_hat(:,:, im_count) ./ repmat(tmp_mean,length(tmp_mean),1);         
        end
    end
    for im=1:(n_test * n_label)
        [~, max_idx] = max(P_hat(im,:));
        if max_idx == test_label(im)
            confusion(test_label(im),test_label(im)) = ...
                confusion(test_label(im),test_label(im)) + 1/n_test;
        else
            confusion(test_label(im), max_idx) = ...
                confusion(test_label(im), max_idx) + 1/n_test;
        end
    end

    score{experiment}.clf_score = sum(diag(confusion)) / n_label;
    score{experiment}.confusion = confusion;  
    
    fprintf('The total classification score is %.4f. \n', ...
        score{experiment}.clf_score)

    if score{experiment}.clf_score > max_score
        delete([directory mat_name '*.mat']);        
        
        max_score = score{experiment}.clf_score;
        % Save the model:
        save([directory mat_name num2str(max_score) '.mat'],'theta_est');       
    end
   
    %% ===== CSV WRITTING: =====
    csv_line = [score{experiment}.clf_score];
    
    dlmwrite ([directory csv_name],csv_line, '-append');
    
    clearvarlist = ['clearvarlist'; setdiff(who,{'n_exp';'score'; ...
        'csv_name';'max_score';'format';'mat_name';'directory'})];
    clear(clearvarlist{:})
end

% Avg clf score:
clf_avg = 0;
for i=1:n_exp
    clf_avg = clf_avg + score{i}.clf_score/n_exp;
end
  
         