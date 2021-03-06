function [theta, dob] = ...
    conditional_M(set_S, theta, set_proba, eps_uni, ...
        cv_status, theta_old, check_struct, verbose)
% conditional_M: COMPUTE THE MAXIMISATION STEP OF THE EXPECTATION
%                MAXIMISATION ALGORITHM
%
%   See "Wavelet-based statistical signal processing using hidden markov
%   models" for more details on the algorithm
%
%   --------
%   INPUTS:
%   --------
%   - set_S: cell{cell(struct)}
%       Set of structures obtained with the function 'hmm_EM_E'.
%   - theta: cell(struct)
%       Structure with the same organisation as 'S' the 'scatnet' lib
%       containing the modelisation parameters.
%   - set_proba: cell{cell(struct)}
%       Conditional probabilities
%   - eps_uni: (optional) bool (default: true)
%       If set to true epsilon is considered to be uniform accross the
%       image (ie: same probability transition from father to child for all
%       the pixel of a same image
%   - cv_ach_strct: 
%   - verbose: (optional) bool (default= true)
%       If true then 'hmm_Scheck_sum' displays debugging info.
%
%   --------
%   OUTPUTS:
%   --------
%   - theta: cell(struct)
%       Updated structure with the same organisation as 'S' the 'scatnet'
%       lib containing the estimated modelisation parameters for this step.
%   - dob: (optional) struct
%       Debuging Object, place holder to pass along all variable needed for
%       debugging.
%
%   --------
%   ISSUES:
%   --------
%
%   --------
%   TODO:
%   --------
%   - Use sanity checks as stopping signals.
%   - Lot of optimization possible in the computation of the betas
%   (beta_exclude node is computed several times, useless for loops (?),
%   useless variables...
%   - Add a masking option to ignore some pixels update. Replace them with 
%   the "old" value. In the check function add a ignore variable. 

% TB added as a variable



    %% Preparation:
    % Arguments:       
    if ~exist('verbose','var')
        verbose = true;
    end
    
    % Sizes:
    n_layer = length(set_S{1});
    n_state = size(theta{1}.proba{1}, 3);
    n_image = length(set_proba);
    s_image = size(set_S{1}{1}.signal{1});

    n_scale = zeros(1,n_layer);
      
    for layer=1:n_layer
        n_scale(1,layer) = length(set_S{1}{layer}.signal);
    end
    
    % Cv limit:
    cv_lim = cv_status.limit;

    %% Update the parameter vector theta:
    for layer=1:n_layer
        for scale=1:n_scale(1,layer)
            % Summing temporary variables:
            tmp_proba = zeros(size(theta{layer}.proba{1}));
            tmp_mu = zeros(size(theta{layer}.mu{1}));
            tmp_sigma = zeros(size(theta{layer}.sigma{1}));           
            % +aaa+++ Test for uniform epsilon
            if eps_uni
                tmp_epsilon = zeros(n_state,n_state);
                % Resizing temporary variables:
                tmp_father = zeros(n_state,n_state);
            else
                tmp_epsilon = zeros(size(theta{layer}.epsilon{1}));
                % Resizing temporary variables:
                tmp_father = zeros(size(theta{layer}.epsilon{1}));
            end
            
            % P_{s_u}(k) - PROBA OF STATE:
            % P_{s_u}(k) = 1/n_im sum_{i=1}^{n_im} P(s_u^i = k|w^i, theta)
            for im=1:n_image
                tmp_proba = tmp_proba + set_proba{im}{layer}.ofNode{scale};
            end

            % Normalize 'proba':
            tmp_proba = tmp_proba / n_image;

            % The means and variances of the mixed gaussians as well as the
            % probabilities of transition are not define for the root
            % layer:
            if layer > 1
                % PROBA OF TRANSITION & MEAN & VARIANCE:
                % eps_{u,rho(u)}^{mn} mu_{u} & sgm_{u} :
                % eps_{u,rho(u)}^{jk} =  P(s_u^i = k s_{rho(u)=j |w^i, theta)
                %                           / (K P(s_rho(u)=k)
                for im=1:n_image
                    % Sum epsilon:                   
                    if eps_uni
                          tmp_epsilon = tmp_epsilon + ...
                            squeeze(sum(sum(set_proba{im}{layer}.ofNodeAndParent{scale},2),1));                      
                    else
                        tmp_epsilon = tmp_epsilon + ...
                            set_proba{im}{layer}.ofNodeAndParent{scale};
                    end

                    % Resizing the ST coefficient for matrix product:
                    tmp_W = repmat(set_S{im}{layer}.signal{scale},1,1,n_state);

                    % Sum mean:
                    tmp_mu = tmp_mu ...
                        + tmp_W .* set_proba{im}{layer}.ofNode{scale};

                    % Sum variance:
                    tmp_sigma = tmp_sigma ...
                        + ((tmp_W - theta{layer}.mu{scale}).^2 ...
                        .* set_proba{im}{layer}.ofNode{scale});
                end

                % Resizing the father probability for matrix product from
                % [s_im 1] to [s_im n_state, n_state] :
                f_layer = layer-1;
                f_scale = set_S{1}{layer}.hmm{scale}.parent;
                % +aaa+++ Test for uniform epsilon
                if eps_uni
                    for c_state=1:n_state
                        for f_state=1:n_state
                            tmp_father(f_state,c_state) = ...
                                sum(sum(theta{f_layer}.proba{f_scale}(:,:,f_state),2),1);
                        end
                    end
                else
                    for c_state=1:n_state
                        for f_state=1:n_state
                            tmp_father(:,:,f_state,c_state) = ...
                                theta{f_layer}.proba{f_scale}(:,:,f_state);
                        end
                    end
                end
                % Normalize 'epsilon':                                     % ISSUE: epsilon is not summing to 1
                tmp_epsilon = tmp_epsilon ./ (n_image .* tmp_father);

                % Normalize 'mu':
                tmp_mu = tmp_mu ./ (n_image * theta{layer}.proba{scale});

                % Try to avoid overflow by tresholding:
                tmp_mu = tmp_mu.*(tmp_mu>1e-4) + 1e-4*(tmp_mu<=1e-4);

                % Normalise 'sigma':
                tmp_sigma = sqrt(tmp_sigma ./ (n_image * theta{layer}.proba{scale}));
                
                % Try to avoid overflow by tresholding:
                tmp_sigma = tmp_sigma.*(tmp_sigma>1e-4) + 1e-4*(tmp_sigma<=1e-4);

                %% Updates:
                % Epsilon:
                if eps_uni
                    % Case where 'Epsilon' is uniform over a transition:
                    s_eps = [1 1 s_image];
                    tmp_epsilon = permute(repmat(tmp_epsilon,s_eps),...
                        [3 4 1 2]);
                end
                              
                % Ignore already converged updates:
                theta{layer}.epsilon{scale} = ...
                    repmat(...
                        not(cv_status.params{layer}.epsilon{scale} > cv_lim),...
                        1,1,n_state,n_state) .* tmp_epsilon ...
                    + repmat(...
                        (cv_status.params{layer}.epsilon{scale} > cv_lim), ...
                        1,1,n_state,n_state) ...
                            .* theta_old{layer}.epsilon{scale};  
                        
                % Correct nan values:
                tmp_mask = logical(squeeze(sum(sum(...
                    isnan(theta{layer}.epsilon{scale}),3),4)));
                tmp_mask = repmat(tmp_mask,1,1,n_state,n_state);

                theta{layer}.epsilon{scale}(tmp_mask) = ...
                    theta_old{layer}.epsilon{scale}(tmp_mask);
                
                                        
                % Correct infinite values:
                tmp_mask = logical(squeeze(sum(sum(...
                    abs(theta{layer}.epsilon{scale})==inf,3),4)));
                tmp_mask = repmat(tmp_mask,1,1,n_state,n_state);

                theta{layer}.epsilon{scale}(tmp_mask) = ...
                    theta_old{layer}.epsilon{scale}(tmp_mask);
                
                
                %+++ SANITY CHECKS:
                % sum:
                check_sum = hmm_Scheck_sum(theta{layer}.epsilon{scale}, ...
                    ones(size(squeeze(theta{layer}.epsilon{scale}(:,:,1,:)))),...
                    'Cond_M', 'Epsilon', '[1]', layer, scale, ...
                    verbose);
                % +++      
                
                % Mu:
                % Ignore already converged/bugy updates:
                theta{layer}.mu{scale} = ...
                    repmat(...
                        not(cv_status.params{layer}.mu{scale} > cv_lim),...
                        1,1,n_state) .* tmp_mu ...
                    + repmat(...
                        (cv_status.params{layer}.mu{scale} > cv_lim), ...
                        1,1,n_state) .* theta_old{layer}.mu{scale};
                    
                % Correct nan values:                    
                tmp_mask = logical(squeeze(sum(...
                    isnan(theta{layer}.mu{scale}),3)));
                tmp_mask = repmat(tmp_mask,1,1,n_state);

                theta{layer}.mu{scale}(tmp_mask) = ...
                    theta_old{layer}.mu{scale}(tmp_mask);
   
                % Correct nan values:                    
                tmp_mask = logical(squeeze(sum(...
                    abs(theta{layer}.mu{scale})==inf,3)));
                tmp_mask = repmat(tmp_mask,1,1,n_state);

                theta{layer}.mu{scale}(tmp_mask) = ...
                    theta_old{layer}.mu{scale}(tmp_mask);
                
                % Sigma:
                % Ignore already converged/bugy updates:
                theta{layer}.sigma{scale} = ...
                    repmat(...
                        not(cv_status.params{layer}.sigma{scale} > cv_lim),...
                        1,1,n_state) .* tmp_sigma ...
                    + repmat(...
                        (cv_status.params{layer}.sigma{scale} > cv_lim), ...
                        1,1,n_state) .* theta_old{layer}.sigma{scale};
                    
                % Correct nan values:                    
                tmp_mask = logical(squeeze(sum(...
                    isnan(theta{layer}.sigma{scale}),3)));
                tmp_mask = repmat(tmp_mask,1,1,n_state);

                theta{layer}.sigma{scale}(tmp_mask) = ...
                    theta_old{layer}.sigma{scale}(tmp_mask);

                % Correct nan values:                    
                tmp_mask = logical(squeeze(sum(...
                    abs(theta{layer}.sigma{scale})==inf,3)));
                tmp_mask = repmat(tmp_mask,1,1,n_state);

                theta{layer}.sigma{scale}(tmp_mask) = ...
                    theta_old{layer}.sigma{scale}(tmp_mask); 
                
                % Correct 0 values:                    
                tmp_mask = logical(squeeze(sum(...
                    (theta{layer}.sigma{scale}) == 0 ,3)));
                tmp_mask = repmat(tmp_mask,1,1,n_state);
                
                theta{layer}.sigma{scale}(tmp_mask) = ...
                    theta_old{layer}.sigma{scale}(tmp_mask);                 
                
            end
            
            % Proba:
            % Ignore already converged/bugy updates:            
            theta{layer}.proba{scale} =  ...                                        
                repmat(...
                    not(cv_status.params{layer}.proba{scale} > cv_lim),...
                    1,1,n_state) .* tmp_proba ...
                + repmat(...
                    (cv_status.params{layer}.proba{scale} > cv_lim), ...
                    1,1,n_state) .* theta_old{layer}.proba{scale};            

            % Correct nan values:                    
            tmp_mask = logical(squeeze(sum(...
                isnan(theta{layer}.proba{scale}),3)));
            tmp_mask = repmat(tmp_mask,1,1,n_state);

            theta{layer}.proba{scale}(tmp_mask) = ...
                theta_old{layer}.proba{scale}(tmp_mask);
            
            % Correct infinite values:                    
            tmp_mask = logical(squeeze(sum(...
                abs(theta{layer}.proba{scale})==inf,3)));
            tmp_mask = repmat(tmp_mask,1,1,n_state);

            theta{layer}.proba{scale}(tmp_mask) = ...
                theta_old{layer}.proba{scale}(tmp_mask);
            
            % +++ SANITY CHECKS:
            % 0 or Nan:         
%             cv_status{layer}{scale} = ...
%                 max(cv_status{layer}{scale},  ...
%                     hmm_Scheck_0nan(theta{layer}.mu{scale},...
%                         'cond_M', 'theta.mu', layer, scale, verbose));
%             cv_status{layer}{scale} = ...
%                 max(cv_status{layer}{scale},  ...
%                     hmm_Scheck_0nan(theta{layer}.sigma{scale},...
%                         'cond_M', 'theta.sigma', layer, scale, verbose));
%             cv_status{layer}{scale} = ...
%                 max(cv_status{layer}{scale},  ...
%                     hmm_Scheck_0nan(theta{layer}.proba{scale},...
%                         'cond_M', 'theta.proba', layer, scale, verbose)); 
        end
    end
end

