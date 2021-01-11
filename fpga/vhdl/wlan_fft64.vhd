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
    use work.nco_p.all ;
    use work.wlan_rx_p.all ;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

entity wlan_fft64 is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    init            :   in  std_logic ;
    signal_dec      :   in  std_logic ;
    symbol_start    :   in  std_logic ;
    dphase          :   in signed( 15 downto 0 ) ;
    in_sample       :   in  wlan_sample_t ;
    out_sample      :   out wlan_sample_t ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_fft64 is

    signal sink_sop     :   std_logic ;
    signal sink_sop_r   :   std_logic ;
    signal sink_eop     :   std_logic ;
    signal sink_eop_r   :   std_logic ;
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


    signal fft_sample   :   wlan_sample_t ;

    signal samples : sample_array_t( 0 to 15 ) ;

    signal fifo_input  : std_logic_vector( 31 downto 0 ) ;
    signal fifo_output : std_logic_vector( 31 downto 0 ) ;
    signal fifo_usedw  : std_logic_vector( 7 downto 0 ) ;
    signal fifo_write  : std_logic ;
    signal fifo_read   : std_logic ;
    signal fifo_read_r : std_logic ;
    signal fifo_full   : std_logic ;
    signal fifo_empty  : std_logic ;

    type fsm_writer_t is (W_IDLE, WRITE_IN);
    type fsm_reader_t is (R_IDLE, START_CORDIC, READ_OUT, HOLD_OFF);

    type state_t is record
        wfsm        :  fsm_writer_t ;
        wcount      :  unsigned( 9 downto 0 ) ;
        rfsm        :  fsm_reader_t ;
        rcount      :  unsigned( 9 downto 0 ) ;
        sop         :  std_logic ;
        eop         :  std_logic ;
        read        :  std_logic ;
        write       :  std_logic ;
        signal_dec  :  std_logic ;
        symbol_index:  unsigned( 12 downto 0 ) ;
        hold_off_cnt:  natural range 0 to 100;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.wfsm  := W_IDLE ;
        rv.wcount := ( others => '0' ) ;
        rv.rfsm  := R_IDLE ;
        rv.rcount := ( others => '0' ) ;
        rv.sop   := '0' ;
        rv.eop   := '0' ;
        rv.read  := '0' ;
        rv.write := '0' ;
        rv.signal_dec := '0' ;
        rv.symbol_index := ( others => '0' ) ;
        rv.hold_off_cnt := 0;
        return rv ;
    end function ;

    signal current, future : state_t ;

    signal nco_inputs   :   nco_input_t ;
    signal nco_outputs  :   nco_output_t ;
    signal nco_en       :   std_logic ;

    signal corrected_i  :   signed( 15 downto 0 ) ;
    signal corrected_q  :   signed( 15 downto 0 ) ;
begin

    nco_en <= '1' when (current.rfsm = START_CORDIC or current.rfsm = READ_OUT) else '0';
    nco_inputs <= ( dphase => dphase, valid => nco_en ) ;

    U_nco : entity work.nco
      port map (
        clock   => clock,
        reset   => reset or init,
        inputs  => nco_inputs,
        outputs => nco_outputs
      ) ;

    sync : process( clock )
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge( clock ) ) then
            if( init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    fifo_write <= '1' when ( ( symbol_start = '1' or current.wfsm = WRITE_IN ) and in_sample.valid = '1' ) else '0' ;
    fifo_read  <= '1' when ( current.rfsm = READ_OUT ) else '0' ;

    comb: process(all)
    begin
        future <= current ;
        if( init = '1' ) then
            future.symbol_index <= ( others => '0' ) ;
        end if ;

--        if( init = '1' ) then
--            future.signal_dec <= '0' ;
--        elsif( signal_dec = '1' ) then
--            future.signal_dec <= '1' ;
--        end if ;

        case current.wfsm is
            when W_IDLE =>
                if( symbol_start = '1' ) then
                    future.wfsm <= WRITE_IN ;
                    future.wcount <= to_unsigned( 0, future.wcount'length ) ;
                end if ;

            when WRITE_IN =>
                if( in_sample.valid = '1' ) then
                    future.wcount <= current.wcount + 1 ;
                end if ;
                if( current.wcount >= 64 ) then
                    future.wfsm <= W_IDLE ;
                end if ;
        end case ;

        case current.rfsm is
            when R_IDLE =>
                if( unsigned( fifo_usedw ) >= 47 ) then
                    if( ( current.symbol_index = 2 and signal_dec = '1') or
                                current.symbol_index /= 2 ) then
                        future.rfsm <= START_CORDIC ;
                        future.rcount <= to_unsigned( 15, future.rcount'length ) ;
                    end if ;
                end if ;
            when START_CORDIC =>
                if( current.rcount = 0 ) then
                    future.rcount <= to_unsigned( 64, future.rcount'length ) ;
                    future.symbol_index <= current.symbol_index + 1 ;
                    future.sop <= '1' ;
                    future.rfsm <= READ_OUT ;
                else
                    future.rcount <= current.rcount - 1;
                end if ;
            when READ_OUT =>
                future.sop <= '0' ;
                future.eop <= '0' ;
                if( unsigned( current.rcount ) = 2 ) then
                    future.eop <= '1' ;
                end if ;
                if( unsigned( current.rcount ) <= 1 ) then
                    future.hold_off_cnt <= 70 ;
                    future.rfsm <= HOLD_OFF ;
                end if ;
                future.rcount <= current.rcount - 1 ;
            when HOLD_OFF =>
                if( current.hold_off_cnt = 0 ) then
                    future.rfsm <= R_IDLE;
                else
                    future.hold_off_cnt <= current.hold_off_cnt - 1;
                end if;

        end case ;
    end process ;

    U_fifo : scfifo
      generic map (
        lpm_width       =>  fifo_input'length,
        lpm_widthu      =>  fifo_usedw'length,
        lpm_numwords    =>  2**(fifo_usedw'length),
        lpm_showahead   =>  "ON"
      ) port map (
        clock           =>  clock,
        aclr            =>  reset,
        sclr            =>  init,
        data            =>  std_logic_vector( in_sample.i ) & std_logic_vector( in_sample.q ),
        wrreq           =>  fifo_write ,
        rdreq           =>  fifo_read,
        q               =>  fifo_output,
        full            =>  fifo_full,
        empty           =>  fifo_empty,
        usedw           =>  fifo_usedw
      ) ;

    sink_sop <= current.sop ;
    sink_eop <= current.eop ;
    sink_real <= std_logic_vector(in_sample.i) ;
    sink_imag <= std_logic_vector(in_sample.q) ;
    sink_valid <= in_sample.valid ;

    sink_error <= (others =>'0') ;
    source_ready <= '1' ;

    out_sample <= fft_sample ;
    done <= '0' when reset = '1' else source_eop and source_valid when rising_edge(clock) ;

    cfo_correction_stage : process(clock, reset)
    begin
        if( reset = '1' ) then
            sink_sop_r <= '0' ;
            sink_eop_r <= '0' ;
            fifo_read_r <= '0' ;
        elsif( rising_edge(clock) ) then
            sink_sop_r <= sink_sop ;
            sink_eop_r <= sink_eop ;
            fifo_read_r <= fifo_read ;
            corrected_i <= resize(shift_right(signed(fifo_output( 31 downto 16 )) * nco_outputs.re - signed(fifo_output( 15 downto 0 )) * nco_outputs.im, 11), 16);
            corrected_q <= resize(shift_right(signed(fifo_output( 31 downto 16 )) * nco_outputs.im + signed(fifo_output( 15 downto 0 )) * nco_outputs.re, 11), 16);
        end if ;
    end process ;

--    U_fft64 : entity fft64.fft64
--      port map (
--        clk             =>  clock,
--        reset_n         =>  not(reset),
--        fftpts_in       =>  std_logic_vector(to_unsigned(64,7)),
--        inverse         =>  "0",
--        sink_sop        =>  sink_sop_r,
--        sink_eop        =>  sink_eop_r,
--        sink_valid      =>  fifo_read_r,
--        sink_real       =>  std_logic_vector(corrected_i),
--        sink_imag       =>  std_logic_vector(corrected_q),
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

      U_fft64 : entity work.fft(mult)
        generic map(
          N     => 64,
          BITS  => 16
        ) port map (
          clock     =>  clock,
          reset     =>  reset,

          inverse   =>  '0',
          in_real   =>  std_logic_vector(corrected_i),
          in_imag   =>  std_logic_vector(corrected_q),
          in_valid  =>  fifo_read_r,
          in_sop    =>  sink_sop_r,
          in_eop    =>  sink_eop_r,

          out_real  =>  source_real,
          out_imag  =>  source_imag,
          out_error =>  open,
          out_valid =>  source_valid,
          out_sop   =>  source_sop,
          out_eop   =>  source_eop
        );

    present_output : process(clock, reset)
    begin
        if( reset = '1' ) then
            fft_sample <= NULL_SAMPLE ;
        elsif( rising_edge(clock) ) then
            fft_sample.valid <= source_valid ;
            if( source_valid = '1' ) then
                fft_sample.i <= signed(source_real(15 downto 0)) ;
                fft_sample.q <= signed(source_imag(15 downto 0)) ;
            end if ;
        end if ;
    end process ;

end architecture ;


