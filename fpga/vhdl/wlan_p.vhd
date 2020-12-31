-- This file is part of bladeRF-wiphy.
--
-- Copyright (C) 2020 Nuand, LLC.
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;
    use ieee.math_real.all ;
    use ieee.math_complex.all ;

package wlan_p is

    -- Convenience types
    type wlan_sample_t is record
        i       :   signed(15 downto 0) ;
        q       :   signed(15 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type wlan_equalizer_sample_t is record
        i       :   signed(22 downto 0) ;
        q       :   signed(22 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type integer_array_t is array(natural range <>) of integer ;
    type real_array_t is array(natural range <>) of real ;
    type complex_array_t is array(natural range <>) of complex ;
    type sample_array_t is array(natural range <>) of wlan_sample_t ;
    type bsd_array_t is array(natural range <>) of signed(7 downto 0) ;

    -- Bit soft decisions
    type wlan_bsds_t is record
        bsds    :   bsd_array_t(5 downto 0) ;
        valid   :   std_logic ;
    end record ;

    -- Datarate selection
    type wlan_datarate_t is (
        WLAN_RATE_1,  WLAN_RATE_2,  WLAN_RATE_5_5, WLAN_RATE_11,
        WLAN_RATE_6,  WLAN_RATE_9,  WLAN_RATE_12, WLAN_RATE_18,
        WLAN_RATE_24, WLAN_RATE_36, WLAN_RATE_48, WLAN_RATE_54
    ) ;

    type wlan_modulation_t is (
        WLAN_DBPSK, WLAN_DQPSK, WLAN_BPSK, WLAN_QPSK, WLAN_16QAM, WLAN_64QAM
    ) ;

    -- Bandwidth selection
    type wlan_bandwidth_t is (
        WLAN_BW_5, WLAN_BW_10, WLAN_BW_20
    ) ;

    procedure nop( signal clock : in std_logic ; count : natural ) ;

    function NULL_SAMPLE return wlan_sample_t ;
    function NULL_EQ_SAMPLE return wlan_equalizer_sample_t ;

    -- FFT has bin 0 as DC
    constant SHORT_SEQ_FREQ : complex_array_t(0 to 63) := (
         4     =>  (-1.472, -1.472),
         8     =>  (-1.472, -1.472),
        12     =>  ( 1.472,  1.472),
        16     =>  ( 1.472,  1.472),
        20     =>  ( 1.472,  1.472),
        24     =>  ( 1.472,  1.472),
        40     =>  ( 1.472,  1.472),
        44     =>  (-1.472, -1.472),
        48     =>  ( 1.472,  1.472),
        52     =>  (-1.472, -1.472),
        56     =>  (-1.472, -1.472),
        60     =>  ( 1.472,  1.472),
        others =>  ( 0.000,  0.000)
    ) ;

    -- Short sequence in time truncated to the repetition point at 16 samples
    constant SHORT_SEQ_TIME : complex_array_t := (
        ( 0.04600,  0.04600),
        (-0.13245,  0.00234),
        (-0.01347, -0.07853),
        ( 0.14276, -0.01265),
        ( 0.09200,  0.00000),
        ( 0.14276, -0.01265),
        (-0.01347, -0.07853),
        (-0.13245,  0.00234),
        ( 0.04600,  0.04600),
        ( 0.00234, -0.13245),
        (-0.07853, -0.01347),
        (-0.01265,  0.14276),
        ( 0.00000,  0.09200),
        (-0.01265,  0.14276),
        (-0.07853, -0.01347),
        ( 0.00234, -0.13245)
    ) ;

    constant LONG_SEQ_FREQ : complex_array_t := (
        ( 0.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 0.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        (-1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0),
        ( 1.0, 0.0)
    ) ;

    constant LONG_SEQ_TIME : complex_array_t := (
        ( 0.15625,  0.00000),
        (-0.00512, -0.12033),
        ( 0.03975, -0.11116),
        ( 0.09683,  0.08280),
        ( 0.02111,  0.02789),
        ( 0.05982, -0.08771),
        (-0.11513, -0.05518),
        (-0.03832, -0.10617),
        ( 0.09754, -0.02589),
        ( 0.05334,  0.00408),
        ( 0.00099, -0.11500),
        (-0.13680, -0.04738),
        ( 0.02448, -0.05853),
        ( 0.05867, -0.01494),
        (-0.02248,  0.16066),
        ( 0.11924, -0.00410),
        ( 0.06250, -0.06250),
        ( 0.03692,  0.09834),
        (-0.05721,  0.03930),
        (-0.13126,  0.06523),
        ( 0.08222,  0.09236),
        ( 0.06956,  0.01412),
        (-0.06031,  0.08129),
        (-0.05646, -0.02180),
        (-0.03504, -0.15089),
        (-0.12189, -0.01657),
        (-0.12732, -0.02050),
        ( 0.07507, -0.07404),
        (-0.00281,  0.05377),
        (-0.09189,  0.11513),
        ( 0.09172,  0.10587),
        ( 0.01228,  0.09760),
        (-0.15625,  0.00000),
        ( 0.01228, -0.09760),
        ( 0.09172, -0.10587),
        (-0.09189, -0.11513),
        (-0.00281, -0.05377),
        ( 0.07507,  0.07404),
        (-0.12732,  0.02050),
        (-0.12189,  0.01657),
        (-0.03504,  0.15089),
        (-0.05646,  0.02180),
        (-0.06031, -0.08129),
        ( 0.06956, -0.01412),
        ( 0.08222, -0.09236),
        (-0.13126, -0.06523),
        (-0.05721, -0.03930),
        ( 0.03692, -0.09834),
        ( 0.06250,  0.06250),
        ( 0.11924,  0.00410),
        (-0.02248, -0.16066),
        ( 0.05867,  0.01494),
        ( 0.02448,  0.05853),
        (-0.13680,  0.04738),
        ( 0.00099,  0.11500),
        ( 0.05334, -0.00408),
        ( 0.09754,  0.02589),
        (-0.03832,  0.10617),
        (-0.11513,  0.05518),
        ( 0.05982,  0.08771),
        ( 0.02111, -0.02789),
        ( 0.09683, -0.08280),
        ( 0.03975,  0.11116),
        (-0.00512,  0.12033)
    ) ;

end package ;

package body wlan_p is

    procedure nop( signal clock : in std_logic ; count : natural ) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clock) ;
        end loop ;
    end procedure ;

    function NULL_SAMPLE return wlan_sample_t is
    begin
        return (
            i       =>  (others =>'0'),
            q       =>  (others =>'0'),
            valid   =>  '0'
        ) ;
    end function ;

    function NULL_EQ_SAMPLE return wlan_equalizer_sample_t is
    begin
        return (
            i       =>  (others =>'0'),
            q       =>  (others =>'0'),
            valid   =>  '0'
        ) ;
    end function ;


end package body ;

