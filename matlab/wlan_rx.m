% This file is part of bladeRF-wiphy.
%
% Copyright (C) 2020 Nuand, LLC.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, write to the Free Software Foundation, Inc.,
% 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

%% User Parameters
snr = 99 ;

%% Initialization

% Get common stuff, x is input signal
util
clear rx
idx = 1 ;

%% AWGN Channel with some phase offset
% TODO: Make this more interesting
%h = [1] ;
% h = [ randn+1j*randn 0 (randn+1j*randn)/2 0 (randn+1j*randn)/4 ];
h = [ 0.85 0.1 0 0.05 0 0.05 ] ;
% Add noise
noise = (randn(length(x),1) + randn(length(x),1)*1j) ;
sp = sum(abs(x).^2) ;
np = sum(abs(noise).^2) ;

% Scale noise based on signal and noise power
nl = sp / (10^(snr/10)) / np ;
noise = sqrt(nl).*noise ;

sp = sum(abs(x).^2) ;
np = sum(abs(noise).^2) ;
rx.actual_snr = 10*log10(sp/np) ;

% Finally add the noise
% NOTE: Channel impulse response does not have a group delay, so don't
% delay the input, just chop it off.
xn = conv(x,h) ; xn = xn(1:length(x)) ;
xn = xn + noise ;

% Add a phase rotation
xn = xn .* exp(1j*pi/8) ;

%% Acquisition
% Acquire
% TODO: Actually acquire here, but for now we know we just advance 160
% samples into the signal
rx.short = xn(idx:idx+160-1) ;
idx = idx + 160 ; % short sequence

%% Save off T1 and T2 after GI2
% Initialize frequency offset correction
idx = idx + 32 ; % GI2
rx.t1 = xn(idx:idx+64-1) ;
rx.T1 = fft(rx.t1) ;
rx.T1(rx.T1==0) = 1e-20 ;
idx = idx + 64 ; % T1

% Figure out initial equalizer taps
rx.t2 = xn(idx:idx+64-1) ;
rx.T2 = fft(rx.t2) ;
rx.T2(rx.T2==0) = 1e-20 ;
idx = idx + 64 ; % T2

%% Initialize Equalizer from average of T1 and T2
% Since T1 and T2 should be the same, we should be able to average the
% observed samples together and try to get rid of some noise.
rx.tavg = (rx.t1 + rx.t2)./2 ;
rx.TAVG = fft(rx.tavg) ;

%rx.TAVG = fft([ h, zeros(1,64-length(h))].') ;

% Equalizer is just the reference signal divided by received signal
rx.EQ = long_preamble.freq .* conj(rx.TAVG) ./ (abs(rx.TAVG).^2 + 10^(-snr/10)) ;

%% Extract SIGNAL frame
idx = idx + 16 ; % GI
rx.signal = xn(idx:idx+64-1) ;
rx.SIGNAL = fft(rx.signal) ;
rx.SIGNAL_EQ = rx.SIGNAL .* rx.EQ ;
idx = idx + 64 ;

%% Extract DATA frames
n = 1 ;
num_data_frames = floor((length(x) - idx)/80) ;
rx.data = zeros(num_data_frames, 64) ;
rx.DATA = zeros(num_data_frames, 64) ;
idx = idx + 16 ; % GI
while n <= num_data_frames
    rx.data(n,:) = xn(idx:idx+64-1) ;
    rx.DATA(n,:) = fft(rx.data(n,:)) ;
    rx.DATA_EQ(n,:) = rx.DATA(n,:) .* rx.EQ.' ;
    % Increment
    n = n + 1 ;
    idx = idx + 80 ;
end
