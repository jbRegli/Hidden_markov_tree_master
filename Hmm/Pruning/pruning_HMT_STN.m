function [theta] = pruning_HMT_STN(theta, prun_params)

% pruning_HMT_STN: PRUNE THE TREE ACCORDING TO SIGNAL TO NOISE RATION.
%
%   THis function compute the signal to noise ratio  of each leaf of the
%   tree and remove 'prun_param.rmv_prc'% of the leaf with the highest 
%   signal to noise ratio (\frac{\abs(\mu)}{\sigma}) .
%
%   --------
%   INPUTS:
%   --------
%   - theta: cell(struct)
%       Structure with the same organisation as 'S' the 'scatnet' lib used
%       to store the model parameters.
%   - prun_params: (optional) struct
%       Each fields is a meta parameter for the pruning.
%           - .rmv_prc: (optional) float(0,1) (default: 0.5)
%               Percentage of highest signal to noise ratio leafs to be
%               removed
%           - .n_iteration: (optional) int (default: 1)
%               Number of iteration over the pruning. If all the children 
%               of a node are removed during the first pruning iteration
%               then the second pass is done on the   ---- TBC
%       
%   --------
%   OUTPUTS:
%   --------
%   - theta: cell(struct)
%       Structure with a new organisation as some node are now ignored.
%
%   --------
%   TODO:
%   --------

    %% Preparation:  
    % Arguments:
    if nargin < 2
       prun_params = struct();
    end
    
    % Fields of the input structure:
    prun_params = isfield_Pruning(prun_params);

    
    % Variables (2):
    n_layer = length(theta);
    n_scale = zeros(1,n_layer);
       
    % Sizes (2):
    n_layer = length(theta);
    n_scale = zeros(1,n_layer);
    s_image = size(theta{1}.proba{1}(:,:,1));
    EM_metaparameters.n_state = size(theta{1}.proba{1},3);
    
    % Extreme values test:
    check_strct = cell(1,n_layer);
    
    for layer=1:n_layer
        % Number of scale: per layer:
        n_scale(1,layer) = length(theta{layer}.proba);
        
        check_strct{layer}.ofNode = cell(1,n_scale(1,layer));
        check_strct{layer}.ofNodeAndParent = cell(1,n_scale(1,layer));
        
        % Initialization of the matrices:
        for scale=1:n_scale(1,layer)
            check_strct{layer}.ofNode{scale} = zeros([s_image EM_metaparameters.n_state]);
            check_strct{layer}.ofNodeAndParent{scale} = ...
                zeros([s_image EM_metaparameters.n_state EM_metaparameters.n_state]);
        end
    end
    
    % Convergence test:
    [cv_status, cv_ach_bool] = ...
        hmm_conv_test(theta, theta_old, [], 1, ...
        EM_metaparameters.mixing, EM_metaparameters.cv_sens, ...
        EM_metaparameters.cv_steps, true);        

    % Display:
    fprintf('* EM algorithm: \n');
    reverseStr = '';
    
    % Select a random layer and scale in the scattering transform for 
    % plotting: 
    lay = randi(n_layer);
    scal= randi(n_scale(lay));

    % Select a random pixel in the image:    
    x = randi(s_image(1));
    y = randi(s_image(2));

    %% EM:
    step = 1;

    while (step <= EM_metaparameters.n_step && not(cv_ach_bool))
        % Print remaining steps and times:
        if step == 1
            tic;
            % Display and update:
            msg = sprintf('--- Step %i/%i ---', step, EM_metaparameters.n_step);
            fprintf([reverseStr, msg]);
            if not(options.verbose)
                reverseStr = repmat(sprintf('\b'), 1, length(msg));
            end
        else
            if step == 2
                time = toc;
            end
            % Display and update:
            if EM_metaparameters.n_step == inf
                msg = sprintf('--- Step %i --- Single step time: %.2f s. \r ' ,...
                    step, time);
            else
                msg = sprintf('--- Step %i/%i --- Maximum expected remaining time: %.2f s. \r ' ,...
                    step, EM_metaparameters.n_step, (EM_metaparameters.n_step-(step-1)) * time);
            end
            
            fprintf([reverseStr, msg, msg2, msg3, msg4, msg5, msg6]);
            if not(options.verbose)
                reverseStr = repmat(sprintf('\b'), 1,  ...
                    length(msg) + length(msg2) + length(msg3) + length(msg4)...
                    + length(msg5) + length(msg6));
            end
        end

        % Old theta for convergence testing:
        if step > 1
            theta_old = theta;
        end
        
        % Expectation:
        % Hidden state probabibility:
        hidStates = conditional_HIDDEN(set_S{1}, theta, options.verbose);        
        for im=randperm(n_image)
            % UP pass: Compute the betas
            cond_up = conditional_UP(set_S{im}, theta, hidStates, options.verbose);
            % Down pass: Compute the alphas
            alpha = conditional_DOWN(set_S{im}, theta, hidStates, cond_up, options.verbose);
            % Conditional probabilities:
            [set_proba{im}, check_strct, ~] = ...
                conditional_P(set_S{im}, theta, hidStates, ...
                cond_up, alpha, check_strct, options.verbose);
        end

        % Maximisation:
        % Catch event where the conditional probabilities would be equal to
        theta = ...
            conditional_M(set_S, theta, set_proba, ...
                EM_metaparameters.eps_uni, cv_status, theta_old, ...
                check_strct, options.verbose);

        % Check theta values:
        check_bool = hmm_check_theta(theta);
        if check_bool
            fprintf('--- Breaking - theta test... \n')
            theta = theta_old;
            break
        end
                
        % Convergence testing:
        [cv_status, cv_ach_bool] = ...
            hmm_conv_test(theta, theta_old, cv_status, step, ...
                EM_metaparameters.mixing, EM_metaparameters.cv_sens, ...
                EM_metaparameters.cv_steps, false);
        
        % +++ 
        % Statistics on the number of converged pixels:
        cv_stat = hmm_conv_stat(cv_status);
        
        % Display:
        if lay == 1
            msg2 = sprintf('+++ cv_status{%i}.proba{%i}=  %s \n', ...
                lay, scal, mat2str(squeeze(cv_status.params{lay}.proba{scal}(x,y,:))));
            msg3 = sprintf('+++ theta{%i}.proba{%i} - theta_old{%i}.proba{%i}=  %s \n', ...
                lay, scal, lay, scal, mat2str(squeeze(theta{lay}.proba{scal}(x,y,:)-theta_old{lay}.proba{scal}(x,y,:))));
            msg4 = sprintf('');
            msg5 = sprintf('');
            msg6 = sprintf('');
        else
            msg2 = sprintf('+++ cv_status{%i}.mu{%i}=  %s \n', ...
                lay, scal, mat2str(squeeze(cv_status.params{lay}.mu{scal}(x,y,:))));
            msg3 = sprintf('+++ theta{%i}.mu{%i} - theta_old{%i}.mu{%i}=  %s \n', ...
                lay, scal, lay, scal, mat2str(squeeze(theta{lay}.mu{scal}(x,y,:)-theta_old{lay}.mu{scal}(x,y,:))));
            msg4 = sprintf('+++ cv_status{%i}.epsilon{%i}=  %s \n', ...
                lay, scal, mat2str(squeeze(cv_status.params{lay}.epsilon{scal}(x,y,:))));
            msg5 = sprintf('+++ theta{%i}.epsilon{%i} - theta_old{%i}.epsilon{%i}=  %s \n', ...
                lay, scal, lay, scal, mat2str(squeeze(theta{lay}.epsilon{scal}(x,y,:)-theta_old{lay}.epsilon{scal}(x,y,:))));
        end
        
        msg6 = sprintf('+++ cv_stat.overallCv = %.5f \n', cv_stat.overallCv);
        
        if cv_stat.overallCv > EM_metaparameters.cv_ratio
            cv_ach_bool = true;
            EM_metaparameters.cv_ratio
            break
        end

        % Step iteration
        step=step+1;
    end

    % Convergence:
    if cv_ach_bool
        fprintf('--- Convergence achieved in %i steps. \n', step)
    else
        fprintf('--- Convergence has not yet been achieved after %i steps. \n', ...
            step-1)
    end

    % Statistics on the number of converged pixels:
    cv_stat = hmm_conv_stat(cv_status);
    
    % +++ Debuging object:
    dob.set_distrib = set_hidStates;
    dob.cond_up = cond_up;
    dob.alpha = alpha;
    dob.set_proba = set_proba;
    dob.cv_status = cv_status;
end

