    function [ set_S ] = ST_class(path_to_set, filt_opt, scat_opt, n_image, format)
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

    %% ===== Initialization: =====
    if nargin < 2
        filt_opt = struct();
    end
    if nargin < 3
        scat_opt = struct();
    end
    if nargin < 4
        n_image = 0;
    end
    if nargin < 5
        format = 'png';
    end

    % Display
    reverseStr = '';
    fprintf(' * Image processing: \n')

    %% ===== Case where the input is a path to a dataset: =====
    if ischar(path_to_set)
        % List all the images:
        allFiles = dir(fullfile(path_to_set,  ['*.' format]));
        allNames = {allFiles.name};

        if n_image == 0 || n_image > length(allNames)
            n_image = length(allNames);
        end

        % Create a random sampler:
        rdm_spl = randsample(1:length(allNames), n_image);

        % LOOP OVER THE IMAGES:
        if strcmp(format, 'png')
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
        elseif strcmp(format, 'mat')
            for i=1:n_image
                if i==1
                    % Initilization w/ first image:
                    tmp_x = load(fullfile(path_to_set, allNames{rdm_spl(i)}));
                    x = tmp_x.b;

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
                    tmp_x = load(fullfile(path_to_set, allNames{rdm_spl(i)}));
                    x = tmp_x.b;
                    S = scat(x, Wop);

                    set_S = [set_S {S}];
                end
            end            
        else
            disp('ST_class: unknown data format')
            set_S = [{}];
        end

    %% ===== Case where a path to a set and a ramdom sampler: =====
    elseif iscell(path_to_set) && iscell(path_to_set{1})
        path_to_images = fullfile(path_to_set{1}{1}, path_to_set{1}{2});
        
        allFiles = dir(fullfile(path_to_set{1}{1}, path_to_set{1}{2}, ...
            '/', ['*.' path_to_set{1}{3}]));
        allNames = {allFiles.name};
        
        % random sampler:
        rdm_spl = path_to_set{2};        
            
        % LOOP OVER THE IMAGES:
        if strcmp(path_to_set{1}{3}, 'png') || strcmp(path_to_set{1}{3}, 'jpg')
            for i=1:n_image
                if i==1
                    % Initilization w/ first image:
                    x = im2double(imread(fullfile(path_to_images, ...
                        allNames{rdm_spl(i)})));
                    
                    % +++ Resize to avoid wrong image sizes:
                    x = x(50:100,50:100);
                    
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
                    x = im2double(imread(fullfile(path_to_images, ...
                        allNames{rdm_spl(i)})));   
                    
                    % +++ Resize to avoid wrong image sizes:
                    x = x(50:100,50:100);
                                        
                    
                    S = scat(x, Wop);

                    set_S = [set_S {S}];
                end
            end
        elseif strcmp(format, 'mat')
            for i=1:n_image
                if i==1
                    % Initilization w/ first image:
                    tmp_x = load(fullfile(path_to_images, allNames{rdm_spl(i)}));
                    x = tmp_x.b;

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
                    tmp_x = load(fullfile(path_to_images, allNames{rdm_spl(i)}));
                    x = tmp_x.b;
                    
                    S = scat(x, Wop);

                    set_S = [set_S {S}];
                end
            end
        elseif strcmp(format, 'ubyte')
            % Add MNIST loader to the path:
            addpath(path_to_set{1}{1})
            
            % Loard MNIST:
            tmp_mnist = loadMNISTImages('train-images-idx3-ubyte');
            tmp_label = loadMNISTLabels('train-labels-idx1-ubyte');
            
            tmp_mnist= reshape(tmp_mnist, sqrt(size(tmp_mnist,1)), ...
                sqrt(size(tmp_mnist,1)), size(tmp_mnist,2));
            
            tmp_class = tmp_mnist(:,: ,tmp_label== path_to_set{1}{2});
            
            for i=1:n_image
            	if i==1
                	% Initilization w/ first image:
                    x = tmp_class(:,:,rdm_spl(i));
                    
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
                    x = tmp_class(:,:,rdm_spl(i));
                    S = scat(x, Wop);
                    
                    set_S = [set_S {S}];
                end
            end            
        else
            disp('ST_class: unknown data format')
            set_S = [{}];
        end        
               
   %% ===== Case where a generator is provided: =====   
    elseif iscell(path_to_set) && not(iscell(path_to_set{1}))
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
            x = generate_square(empty, false, false, false, size_im);        % empty, noise, translate, rotate, size)
        elseif strcmp(path_to_set{1},'circle')
            x = generate_circle(empty, false, false, size_im);               % empty, noise, translate, size)
        elseif strcmp(path_to_set{1},'triangle')
            x = generate_triangle(empty, false, false, false, size_im);      % empty, noise, translate, rotate, size)
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
                x = generate_square(empty, false, true, false, size_im);     % empty, noise, translate, rotate, size)
            elseif strcmp(path_to_set{1},'circle')
                x = generate_circle(empty, false, true, size_im);     % empty, noise, translate, size)
                % empty, noise, translate, rotate, size)
            elseif strcmp(path_to_set{1},'triangle')
                x = generate_triangle(empty, false, true, false, size_im);      % empty, noise, translate, rotate, size)
            end

            [S, U] = scat(x, Wop);

            set_S = [set_S {S}];
        end

    %% ===== Error catching: =====
    else
        disp('Invalid input')
        % +++
        class(path_to_set)
        set_S = [];
    end
end

