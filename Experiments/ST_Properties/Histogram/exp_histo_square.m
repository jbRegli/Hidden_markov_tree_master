%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%         OK
% This script realizes the scattering transform of several images of a    %
% same class. Then it plots the histogram of the ST coefficient           %
% distributions.                                                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all
close all

%% Initialization:
label = 'square';
number = 100;

% plot info:
layer = 2;
index = 10;
pixel = 250;

%% Images from a class:
info = {label, number};

%% Scattering transform:
% Parameters:
filt_opt.J = 4; % scales
filt_opt.L = 4; % orientations
filt_opt.filter_type = 'morlet';
scat_opt.oversampling = 2;
scat_opt.M = 2;
% filt_opt = struct();
% scat_opt = struct();

% ST:
set_S = ST_class(info, filt_opt, scat_opt);

%% Display:
data = plot_ST_histo(set_S, layer, index, number);
