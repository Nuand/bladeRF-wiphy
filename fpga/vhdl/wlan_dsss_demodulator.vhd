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

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

entity wlan_dsss_demodulator is
    port (
      clock            :   in  std_logic ;
      reset            :   in  std_logic ;

      modulation       :   in  wlan_modulation_t ;

      in_bin_idx       :   in  natural ;
      despread         :   in  wlan_sample_t ;

      out_bin_idx      :   out natural ;
      out_bits         :   out std_logic_vector( 1 downto 0 ) ;
      out_valid        :   out std_logic
    ) ;
end entity ;

architecture arch of wlan_dsss_demodulator is

    signal history     : sample_array_t( 19 downto 0 );

    signal res_i       : signed( 19 downto 0 ) ;
    signal a_i, a_q, b_i, b_q : signed(15 downto 0) ;
    signal res_q       : signed( 19 downto 0 ) ;

    signal res_valid   : std_logic ;

    signal coded_bits  : std_logic_vector( 1 downto 0 ) ;
    signal coded_valid : std_logic ;
    signal coded_idx   : natural ;

    signal decoded_bits : std_logic_vector( 19 downto 0 ) ;
    signal demod_bits   : std_logic_vector( 19 downto 0 ) ;

    type bit_history_t is array(0 to 20) of std_logic_vector(7 downto 0) ;
    signal bit_history : bit_history_t ;
begin

    -- demodulate bits
    process( clock )
        variable wtf : signed (19 downto 0 );
    begin
        if( reset = '1' ) then
            history     <= ( others => NULL_SAMPLE ) ;
            coded_bits  <= ( others => '0' ) ;
            coded_valid <= '0' ;
            coded_idx   <= 0 ;
            demod_bits  <= ( others => '0' ) ;

        elsif( rising_edge( clock ) ) then
            coded_valid <= '0' ;

            if( despread.valid = '1' ) then
                for i in 0 to history'high - 1 loop
                    history(i+1) <= history(i) ;
                end loop ;
                history(0) <= despread ;

                if( modulation = WLAN_DBPSK ) then
                    coded_idx <= in_bin_idx ;
                    a_i <= despread.i;
                    a_q <= history(19).i;
                    b_i <= despread.q;
                    b_q <= history(19).q;
                    wtf := resize((shift_right(despread.i * history(19).i,4) + shift_right(despread.q * history(19).q,4)), 20);
                    res_i <= wtf;
                    if( wtf < 0 ) then
                        demod_bits(in_bin_idx) <= '1' ;
                        coded_bits(0) <= '1' ;
                    else
                        demod_bits(in_bin_idx) <= '0' ;
                        coded_bits(0) <= '0' ;
                    end if ;
                    coded_valid <= '1' ;
                end if ;
            end if ;

        end if ;
    end process ;

    -- descramble decoded bits
    process( clock )
    begin
        if( reset = '1' ) then
            out_bin_idx <= 0 ;
            out_bits    <= ( others => '0' ) ;
            out_valid   <= '0' ;
            bit_history <= ( others => ( others => '0' ) ) ;
            decoded_bits<= ( others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            out_valid   <= '0' ;
            if( coded_valid = '1' ) then
                if( modulation = WLAN_DBPSK ) then
                    -- save per bin descrambler register
                    bit_history(coded_idx) <= bit_history(coded_idx)(6 downto 0) & coded_bits(0) ;

                    -- descramble bit
                    out_bits(0) <= coded_bits(0) xor bit_history(coded_idx)(3) xor bit_history(coded_idx)(6) ;
                    decoded_bits(coded_idx) <= coded_bits(0) xor bit_history(coded_idx)(3) xor bit_history(coded_idx)(6) ;
                    out_bin_idx <= coded_idx ;
                    out_valid   <= '1' ;
                end if ;
            end if ;
        end if ;
    end process ;

end architecture ;
