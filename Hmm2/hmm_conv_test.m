function [cv_ach_strct, cv_ach_bool] = ...
    hmm_conv_test(theta, theta_old, cv_ach_strct, step, mixing, cv_sens, init)
% hmm_conv_test: CONVERGENCE TEST FOR EM ALGORITHM
%   Given a theta at step n and theta at step n-1, this function asseses if
%   convergence has occcured.

    %% Preparation:
    % optional variables:
    if ~exist('mixing','var')
        mixing = 10;
    end
    if ~exist('cv_sens','var')
        cv_sens = 1e-4;
    end
    if ~exist('init','var')
        init= false;
    end
    
    % Sizes:
    n_layer = length(theta);
    n_scale = zeros(1,n_layer);
    s_image = size(theta{1}.proba{1}(:,:,1));
    n_state = size(theta{1}.proba{1},3);
   
    if init
        % Structure to store convergence status:
        cv_ach_strct = cell(1, n_layer);

        for layer=1:n_layer
            n_scale(1,layer) = length(theta{layer}.proba);

            % Structure:
            if layer ==  1
                cv_ach_strct{layer}.proba = cell(1,n_scale(1,layer));
                cv_ach_strct{layer}.general = cell(1,n_scale(1,layer));

                % Initialization of the matrices
                for scale=1:n_scale(1,layer)
                    cv_ach_strct{layer}.proba{scale} = zeros([s_image n_state]);
                    cv_ach_strct{layer}.general{scale} = zeros([s_image n_state]);
                end
            else
                cv_ach_strct{layer}.epsilon = cell(1,n_scale(1,layer));
                cv_ach_strct{layer}.mu = cell(1,n_scale(1,layer));
                cv_ach_strct{layer}.sigma = cell(1,n_scale(1,layer));
                cv_ach_strct{layer}.general = cell(1,n_scale(1,layer));

                % Initialization of the matrices:
                for scale=1:n_scale(1,layer)
                    cv_ach_strct{layer}.proba{scale} = zeros([s_image n_state]);
                    cv_ach_strct{layer}.epsilon{scale} = zeros([s_image n_state n_state]);
                    cv_ach_strct{layer}.mu{scale} = zeros([s_image n_state]);
                    cv_ach_strct{layer}.sigma{scale} = zeros([s_image n_state]);
                    cv_ach_strct{layer}.general{scale} = zeros([s_image n_state]);
                end
            end
        end
    else
        for layer=1:n_layer
            n_scale(1,layer) = length(theta{layer}.proba);
        end
    end
       
    %% Convergence test:
    % If the number of step is too small then cv didn't occur (burning
    % time)
    if ~init
        cv_ach_bool = false; %+++ WRONG should be initialized to true
        
        % Mixing time:
        if step < mixing
            cv_ach_bool = false;
        else
            % Loop over the layers:
            for layer=1:n_layer 
                fields = fieldnames(cv_ach_strct{layer});                  
                %  Loop over the scales at 'layer':
                for scale=1:n_scale(1,layer)
                    for i=1:numel(fields)                     
                        if ~strcmp(fields{i},'general') 
                            % Delta:
                            tmp_delta = ...
                                abs(theta{layer}.(fields{i}){scale} ...
                                - theta_old{layer}.(fields{i}){scale});

                            % Convergence structure boolean:                       
                            cv_ach_strct{layer}.(fields{i}){scale}(...
                                tmp_delta < cv_sens) = ...
                                    cv_ach_strct{layer}.(fields{i}){scale}(...
                                        tmp_delta < cv_sens) + 1;
                            cv_ach_strct{layer}.(fields{i}){scale}(...
                                         tmp_delta >= cv_sens) = 0;

                            % Cv achieve general:
                            if ~strcmp(fields{i},'epsilon')
                                cv_ach_strct{layer}.general{scale} = ...
                                    max(...
                                        cv_ach_strct{layer}.general{scale}, ...
                                        cv_ach_strct{layer}.(fields{i}){scale});
                            else
                                tmp_cv = sum(cv_ach_strct{layer}.(fields{i}){scale},4);
                                tmp_cv(tmp_cv <= 1) = 0;
                                tmp_cv(tmp_cv > 1) = 1 ;
                                
                                cv_ach_strct{layer}.general{scale} = ...
                                    max(tmp_cv, ...
                                        cv_ach_strct{layer}.general{scale});
                            end

                            % Convergence boolean:
                            if any(any(any(any(cv_ach_strct{layer}.(fields{i}){scale} == 0))))
                                cv_ach_bool = false;
                            end      
                        end
                    end
                end
            end
        end
    else
        cv_ach_bool = false;
    end
end

