function [data] = plot_ST_histo(transform, layer, index, pixel)
%plot_ST_histo: HISTOGRAM OVER A CLASS AT FOR A GIVEN PIXEL, LAYER AND
%               INDEX
%
%   --------
%   INPUTS:
%   --------
%   - transform: cell
%       Cell of the same length as the number of inputs storing the
%       scattering transform
%   - layer: int
%   - index: int
%   - pixel: int
%   --------
%   OUTPUTS:
%   --------
%   - data: vector
%       Value of the pixel at the given layer and index over the images of
%       the set

    data = [];
    for i=1:length(transform)
        data = vertcat(data, ...
                       reshape(transform{i}{layer}.signal{index}(pixel),...
                               numel(transform{i}{layer}.signal{index}(pixel)),1));
    end
    hist(data)
    title(['Pixel ' num2str(pixel) ' - layer ' num2str(layer)...
           ' - index ' num2str(index) ' of the ST over the set'])
    
end

