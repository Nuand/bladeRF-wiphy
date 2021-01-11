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
library fft64;
library work ;
    use work.wlan_p.all ;

entity wlan_ifft64 is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    symbol_start    :   in  std_logic ;
    symbol_end      :   in  std_logic ;
    in_sample       :   in  wlan_sample_t ;
    out_sample      :   out wlan_sample_t ;
    out_valid_cp    :   out std_logic ;
    ifft_ready      :   out std_logic ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_ifft64 is

    signal sink_sop     :   std_logic ;
    signal sink_eop     :   std_logic ;
    signal sink_valid   :   std_logic ;
    signal sink_ready   :   std_logic ;
    signal sink_real    :   std_logic_vector(15 downto 0) ;
    signal sink_imag    :   std_logic_vector(15 downto 0) ;
    signal sink_error   :   std_logic_vector(1 downto 0) ;

    signal source_sop   :   std_logic ;
    signal source_eop   :   std_logic ;
    signal source_valid :   std_logic ;
    signal source_ready :   std_logic ;
    signal source_real  :   std_logic_vector(15 downto 0) ;
    signal source_imag  :   std_logic_vector(15 downto 0) ;
    signal source_error :   std_logic_vector(1 downto 0) ;

    signal cp_valid     :   std_logic ;

    signal ifft_sample  :   wlan_sample_t ;

    signal ready        :   std_logic ;

    signal inflight     :   natural range 0 to 5 ;
    signal cooldown     :   natural range 0 to 200 ;

begin

    sink_sop <= symbol_start ;
    sink_eop <= symbol_end ;
    sink_real <= std_logic_vector(in_sample.i) ;
    sink_imag <= std_logic_vector(in_sample.q) ;
    sink_valid <= in_sample.valid ;

    sink_error <= (others =>'0') ;
    source_ready <= '1' ;

    out_sample <= ifft_sample ;
    out_valid_cp <= cp_valid ;
    done <= '0' when reset = '1' else source_eop and source_valid when rising_edge(clock) ;

    ifft_ready <= '0' when ( source_eop = '1' or ready = '0' or inflight >= 2 or cooldown > 0) else '1' ;

    U_ifft64 : entity work.fft(mult)
      generic map(
        N     => 64,
        BITS  => 16
      ) port map (
        clock     =>  clock,
        reset     =>  reset,

        inverse   =>  '1',
        in_real   =>  std_logic_vector(sink_real),
        in_imag   =>  std_logic_vector(sink_imag),
        in_valid  =>  sink_valid,
        in_sop    =>  sink_sop,
        in_eop    =>  sink_eop,

        out_real  =>  source_real,
        out_imag  =>  source_imag,
        out_error =>  open,
        out_valid =>  source_valid,
        out_sop   =>  source_sop,
        out_eop   =>  source_eop
      );

--    U_ifft64 : entity fft64.fft64
--      port map (
--        clk             =>  clock,
--        reset_n         =>  not(reset),
--        fftpts_in       =>  std_logic_vector(to_unsigned(64,7)),
--        inverse         =>  "1",
--        sink_sop        =>  sink_sop,
--        sink_eop        =>  sink_eop,
--        sink_valid      =>  sink_valid,
--        sink_real       =>  sink_real,
--        sink_imag       =>  sink_imag,
--        sink_error      =>  sink_error,
--        source_ready    =>  source_ready,
--        fftpts_out      =>  open,
--        sink_ready      =>  sink_ready,
--        source_error    =>  source_error,
--        source_sop      =>  source_sop,
--        source_eop      =>  source_eop,
--        source_valid    =>  source_valid,
--        source_real     =>  source_real,
--        source_imag     =>  source_imag
--      ) ;

    present_output : process(clock, reset)
        variable cp_down : natural range 0 to 48 ;
    begin
        if( reset = '1' ) then
            cp_down := 47 ;
            cp_valid <= '0' ;
            ready <= '1' ;
            ifft_sample <= NULL_SAMPLE ;
            inflight <= 0;
            cooldown <= 0;
        elsif( rising_edge(clock) ) then
            ifft_sample.valid <= source_valid ;
            cp_valid <= '0' ;
            if( source_valid = '1' and source_sop = '1' ) then
                ready <= '0';
            elsif( source_eop = '1' ) then
                ready <= '1';
            end if;

            if( sink_valid = '1' and sink_sop = '1' ) then
                cooldown <= 128;
                -- increment, unless source is also outputting
                if( source_valid = '1' and source_sop = '1' ) then
                    inflight <= inflight;
                else
                    inflight <= inflight + 1;
                end if ;
            elsif( source_valid = '1' and source_sop = '1' ) then
                if( sink_valid = '1' and sink_sop = '1' ) then
                    cooldown <= 128;
                end if;
                inflight <= inflight - 1;
            else
                if( cooldown > 0 ) then
                    cooldown <= cooldown - 1;
                end if;
                  
            end if ;

            if( source_valid = '1' ) then
                ifft_sample.i <= resize(shift_left(signed(source_real)+8,2),ifft_sample.i'length) ;
                ifft_sample.q <= resize(shift_left(signed(source_imag)+8,2),ifft_sample.q'length) ;
                if( cp_down = 0 ) then
                    cp_valid <= '1' ;
                end if ;
                if( source_sop = '1' ) then
                    cp_down := 47 ;
                elsif( source_eop = '1' ) then
                    cp_down := 47 ;
                elsif( cp_down > 0 ) then
                    cp_down := cp_down - 1 ;
                end if ;
            end if ;
        end if ;
    end process ;

end architecture ;

