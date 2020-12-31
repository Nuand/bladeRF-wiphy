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

library work ;
    use work.wlan_p.all ;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

entity wlan_sample_buffer is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    -- Status
    room            :   out std_logic ;

    -- Short sequence inputs
    short           :   in  wlan_sample_t ;

    -- Long sequence inputs
    long            :   in  wlan_sample_t ;

    -- Symbol IFFT inputs
    symbol          :   in  wlan_sample_t ;

    -- Sample FIFO outputs
    sample          :   out wlan_sample_t ;
    sample_i        :   out signed(15 downto 0) ;
    sample_q        :   out signed(15 downto 0) ;
    sample_re       :   in  std_logic ;
    sample_empty    :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_sample_buffer is

    signal fifo_write   :   std_logic ;
    signal fifo_read    :   std_logic ;
    signal fifo_input   :   std_logic_vector(31 downto 0) ;
    signal fifo_output  :   std_logic_vector(31 downto 0) ;
    signal fifo_empty   :   std_logic ;
    signal fifo_full    :   std_logic ;
    signal fifo_usedw   :   std_logic_vector(9 downto 0) ;

    signal mux_i        :   signed(15 downto 0) ;
    signal mux_q        :   signed(15 downto 0) ;

begin

    check_fifo : process(clock)
    begin
        if( rising_edge(clock) ) then
            if( fifo_full = '1' and fifo_write = '1' ) then
                report "Writing to a full FIFO"
                    severity error ;
            end if ;
        end if ;
    end process ;

    fifo_input <= std_logic_vector(mux_i) & std_logic_vector(mux_q) ;
    fifo_write <= short.valid or long.valid or symbol.valid ;
    fifo_read <= sample_re ;
    sample_i <= signed(fifo_output(31 downto 16)) ;
    sample_q <= signed(fifo_output(15 downto 0)) ;
    sample_empty <= fifo_empty ;

    mux_input : process(all)
    begin
        if( short.valid = '1' ) then
            mux_i <= short.i ;
            mux_q <= short.q ;
        elsif( long.valid = '1' ) then
            mux_i <= long.i ;
            mux_q <= long.q ;
        elsif( symbol.valid = '1' ) then
            mux_i <= symbol.i ;
            mux_q <= symbol.q ;
        else
            mux_i <= (others =>'0') ;
            mux_q <= (others =>'0') ;
        end if ;
    end process ;

    room <= '1' when unsigned(fifo_usedw) < 2**(fifo_usedw'length)-128 else '0' ;

    U_fifo : scfifo
      generic map (
        lpm_width       =>  fifo_input'length,
        lpm_widthu      =>  fifo_usedw'length,
        lpm_numwords    =>  2**(fifo_usedw'length),
        lpm_showahead   =>  "ON"
      ) port map (
        clock           =>  clock,
        aclr            =>  reset,
        data            =>  fifo_input,
        wrreq           =>  fifo_write,
        rdreq           =>  fifo_read,
        q               =>  fifo_output,
        full            =>  fifo_full,
        empty           =>  fifo_empty,
        usedw           =>  fifo_usedw
      ) ;

end architecture ;

