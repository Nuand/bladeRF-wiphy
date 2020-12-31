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

% Null OFDM symbol
null = zeros(64,1) ;

% Short preamble generation
SHORT_ONE = 1.472 + 1.472*1j ;

% Bins for positive and negative values
% NOTE: MATLAB has bin 1 as the DC bin, but standard uses
% bin 0 as DC, so we will define all bins here similar to the
% standard, and when indexing them, we will add the MATLAB offset.
SHORT_POS = [12, 16, 20, 24, 40, 48, 60] ;
SHORT_NEG = [4, 8, 44, 52, 56] ;

short_preamble.freq = zeros(64,1) ;
short_preamble.freq(SHORT_POS+1) = SHORT_ONE ;
short_preamble.freq(SHORT_NEG+1) = -SHORT_ONE ;
short_preamble.time = ifft(short_preamble.freq) ;

% Long preamble generation
LONG_ONE = 1 ;

% Bins for positive and negative values
LONG_POS = [1, 4, 5, 7, 9, 15, 16, 19, 21, 23, 24, 25, 26, 38, 39, 42, 43, 45, 47, 48, 49, 50, 51, 52, 55, 56, 58, 60, 61, 62, 63 ] ;
LONG_NEG = [2, 3, 6, 8, 10, 11, 12, 13, 14, 17, 18, 20, 22, 40, 41, 44, 46, 53, 54, 57, 59 ] ;

long_preamble.freq = zeros(64,1) ;
long_preamble.freq(LONG_POS+1) = LONG_ONE ;
long_preamble.freq(LONG_NEG+1) = -LONG_ONE ;
long_preamble.time = ifft(long_preamble.freq) ;


