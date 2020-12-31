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

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

library wlan_pll ;


entity wlan_clock_tb is
end entity ;

architecture arch of wlan_clock_tb is

    signal wclock        :   std_logic         := '1' ;
    signal wreset        :   std_logic         := '1' ;
    signal wdata         :   unsigned(7 downto 0)  := ( others => '0' ) ;
    signal wvalid        :   std_logic         := '1' ;
    signal wfull         :   std_logic         := '1' ;

    signal rclock        :   std_logic         := '1' ;
    signal rreset        :   std_logic         := '1' ;
    signal rempty        :   std_logic         := '1' ;
    signal rdata         :   std_logic_vector(7 downto 0)  := ( others => '0' ) ;

    signal ack_valid     :   std_logic         := '0' ;

    signal fifo_re       :   std_logic         := '0' ;

    signal alt           :   std_logic         := '0' ;

begin
    wclock <= not wclock after 20 ns;
    rclock <= not rclock after 10 ns;

    process(wclock)
    begin
      if( rising_edge( wclock ) ) then
         alt <= not alt;
         if (alt = '0' ) then
            wdata <= wdata + 1;
         end if;
      end if;
    end process;

    U_rx_data_dc_fifo: dcfifo
      generic map (
        lpm_width       =>  8,
        lpm_widthu      =>  6,
        lpm_numwords    =>  32,
        lpm_showahead   =>  "ON"
      )
      port map (
        wrclk           => wclock,
        wrreq           => alt and not wfull,
        data            => std_logic_vector(wdata),

        wrfull          => wfull,
        wrempty         => open,
        wrusedw         => open,

        rdclk           => rclock,
        rdreq           => not rempty,
        q               => rdata,

        rdfull          => open,
        rdempty         => rempty,
        rdusedw         => open
      ) ;


end architecture ;
