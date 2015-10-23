function [ set_S ] = scat_class(path_to_set, filt_opt, scat_opt, n_image)
% scat_class: COMPUTES THE SCATTERING TRANSFORM OF A BATCH OF SIMILAR
%             IMAGES
%
%   Given a set of images (path to it or generator) computes the STs.
%
%   --------
%   INPUTS:
%   --------
%   - path_to_set: string or cell{string, int}
%       Two types of input are accepted. Either a string giving a path to a
%       folder containing a set of similar images. Or a cell giving the
%       name of a known generator ('square' or 'circle') and the number of
%       images to generate.
%   - filt_opt: (optional) struct
%       Filtering options for the scattering transform
%   - scat_opt: (optional) struct)
%       Scattering options for the scattering transform
%
%   --------
%   OUTPUTS:
%   --------
%   - transform: cell
%       Cell of the same length as the number of inputs storing the
%       scattering transform
%
%   WARNING: RAM usage (?) to avoid potential issues work with small
%            (100/200) batches.

    %% Initialization:
    if nargin < 2
        filt_opt = struct();
    end
    if nargin < 3
        scat_opt = struct();
    end
    if nargin < 4
        n_image = 0;
    end
        

    % Display
    reverseStr = '';
    fprintf(' * Image processing: \n')

    %% Case where the input is a path:
    if ischar(path_to_set)
        
        % List all the images:
        allFiles = dir(fullfile(path_to_set, '*.png'));
        allNames = {allFiles.name};

        if n_image == 0 || n_image > length(allNames)
            n_image = length(allNames);
        end
        
        % Create a random sampler:
        rdm_spl = randsample(1:length(allNames), n_image);
        
        % LOOP OVER THE IMAGES:
        for i=1:n_image
            if i==1              
                % Initilization w/ first image:
                x = im2double(imread(fullfile(path_to_set, ...
                    allNames{rdm_spl(i)})));
                               
                % Pre-compute the WT op that will be applied to the image:
                Wop = wavelet_factory_2d(size(x), filt_opt, scat_opt);
        
                tic;
                S = scat(x, Wop);
                time = toc;

                % Stock STs in a cell:
                set_S = [{} {S}];       
            else
                % Print time remaining:
                msg = sprintf('--- Image %i/%i --- Expected remaining time: %.4f s. \r ' ,...
                    i, n_image, (n_image-i) * time);
                fprintf([reverseStr, msg]);
                reverseStr = repmat(sprintf('\b'), 1, length(msg));

                % ST:
                S = scat(im2double(imread(fullfile(path_to_set, ...
                    allNames{rdm_spl(i)}))), Wop);

                set_S = [set_S {S}];
            end
        end
        
        %% Case where the input is a cell:
    elseif iscell(path_to_set)
        
        if length(path_to_set) < 3
            size_im = [640 640];
        else
            size_im = path_to_set{3};
        end
        if length(path_to_set) < 4
            empty = true;
        else
            empty = path_to_set{4};
        end
        
        % Generate path_to_set{2} number of square and their ST
        Wop = wavelet_factory_2d(size_im, filt_opt, scat_opt);
        
        if strcmp(path_to_set{1},'square')
            x = generate_square(empty, true, true, false, size_im);     % empty, noise, translate, rotate, size)
        elseif strcmp(path_to_set{1},'circle')
            x = generate_circle(empty, true, true, size_im);     % empty, noise, translate, size)
        else
            disp('Generator not implemented yet')
            return
        end
        
        tic;
        S = scat(x, Wop);
        time = toc;
        
        % Stock STs in a cell:
        set_S = [{} {S}];
        % GENERATE THE REQUIERED NUMBER OF IMAGES:
        for i = 2:path_to_set{2}
            msg = sprintf('--- Image %i/%i --- Expected remaining time: %.4f s. \r ' ,...
                i, path_to_set{2}, (path_to_set{2}-(i-1)) * time);
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
            
            % ST:
            if strcmp(path_to_set{1},'square')
                x = generate_square(empty, true, true, false, size_im);     % empty, noise, translate, rotate, size)
            elseif strcmp(path_to_set{1},'circle')
                x = generate_circle(empty, true, true, size_im);     % empty, noise, translate, size)               
                % empty, noise, translate, rotate, size)
            end
            
            [S, U] = scat(x, Wop);
            
            set_S = [set_S {S}];
        end
        
    %% Error catching:
    else
        disp('Invalid input')
        % +++
        class(path_to_set)
        set_S = [];
    end
    
    
end

