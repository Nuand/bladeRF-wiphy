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

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;
    use wlan.cordic_p.all ;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

entity wlan_phase_correction is
  port (
    clock            :   in  std_logic ;
    reset            :   in  std_logic ;

    init             :   in  std_logic ;

    in_sample        :   in  wlan_sample_t ;
    in_done          :   in  std_logic ;

    out_sample       :   out wlan_sample_t ;
    out_done         :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_phase_correction is

    type fsm_writer_t is (IDLE, WRITE_SAMPLES) ;
    type fsm_calculate_t is (IDLE, CAPTURE_CORDIC, CAPTURE_CORRECTION) ;
    type fsm_reader_t is (IDLE, READ_SAMPLES) ;

    type state_t is record
        wfsm            :   fsm_writer_t ;
        cfsm            :   fsm_calculate_t ;
        rfsm            :   fsm_reader_t ;
        windex          :   natural range 0 to 70 ;
        rindex          :   natural range 0 to 70 ;
        pilot_polarity  :   std_logic ;
        lfsr_advance    :   std_logic ;

        atan_sample     :   wlan_sample_t ;
        atan_count      :   natural range 0 to 5 ;
        atan_sum        :   signed( 31 downto 0 ) ;
        atan_sum_valid  :   std_logic ;
        norm_x_sum      :   signed( 31 downto 0 ) ;
        norm_y_sum      :   signed( 31 downto 0 ) ;

        phasor          :   wlan_sample_t ;

        cordic_valid    :   std_logic_vector( 15 downto 0 ) ;

        fifo_read       :   std_logic ;

        clear_ready     :   std_logic ;
        set_ready       :   std_logic ;
        ready           :   std_logic ;

        out_sample      :   wlan_sample_t ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.wfsm := IDLE ;
        rv.cfsm := IDLE ;
        rv.rfsm := IDLE ;
        rv.rindex := 0 ;
        rv.windex := 0 ;

        rv.pilot_polarity := '1' ;
        rv.lfsr_advance := '0' ;

        rv.atan_count := 0 ;
        rv.atan_sum := ( others => '0' ) ;
        rv.norm_x_sum := ( others => '0' ) ;
        rv.norm_y_sum := ( others => '0' ) ;

        rv.cordic_valid := ( others => '0' ) ;

        rv.fifo_read := '0' ;

        rv.clear_ready := '0' ;
        rv.set_ready := '0' ;
        rv.ready := '0' ;

        rv.out_sample.valid := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    signal lfsr_data    :   std_logic_vector( 0 downto 0 ) ;
    signal lfsr_advance :   std_logic ;

    signal fifo_input  : std_logic_vector( 31 downto 0 ) ;
    signal fifo_output : std_logic_vector( 31 downto 0 ) ;
    signal fifo_usedw  : std_logic_vector( 7 downto 0 ) ;
    signal fifo_write  : std_logic ;
    signal fifo_read   : std_logic ;
    signal fifo_read_r : std_logic ;
    signal fifo_full   : std_logic ;
    signal fifo_empty  : std_logic ;

    signal cordic_inputs  : cordic_xyz_t ;
    signal cordic_outputs : cordic_xyz_t ;
    signal cordic_normed  : cordic_xyz_t ;

    signal correction_inputs  : cordic_xyz_t ;
    signal correction_outputs : cordic_xyz_t ;

    signal fifo_sample        : wlan_sample_t ;

begin
    out_sample <= current.out_sample ;

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
        wrreq           =>  in_sample.valid,
        rdreq           =>  fifo_read,
        q               =>  fifo_output,
        full            =>  fifo_full,
        empty           =>  fifo_empty,
        usedw           =>  fifo_usedw
      ) ;

    fifo_read <= current.fifo_read ;
    fifo_sample.valid <= fifo_read ;
    fifo_sample.i <= signed(fifo_output( 31 downto 16 )) ;
    fifo_sample.q <= signed(fifo_output( 15 downto 0 )) ;

    lfsr_advance    <= current.lfsr_advance ;

    U_lfsr : entity work.wlan_lfsr
      generic map (
        WIDTH       =>  lfsr_data'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  (others =>'1'),
        init_valid  =>  init,

        advance     =>  lfsr_advance,
        data        =>  lfsr_data,
        data_valid  =>  open
      ) ;

    -- take atan2() of delay correlator using CORDIC
    cordic_inputs <= (  x => resize(current.atan_sample.i, 16),
                        y => resize(current.atan_sample.q, 16),
                        z => (others => '0'),
                        valid => current.atan_sample.valid ) ;

    U_cordic : entity work.cordic
      port map (
        clock   => clock,
        reset   => reset,
        mode    => CORDIC_VECTORING,
        inputs  => cordic_inputs,
        outputs => cordic_outputs,
        normalized => cordic_normed
      ) ;

    correction_inputs <= ( x => to_signed(1234,16), y => to_signed(0,16),  z => resize(shift_right(current.atan_sum, 2), 16), valid => current.atan_sum_valid ) ;

    U_correction_cordic : entity work.cordic
    port map (
        clock   => clock,
        reset   => reset,
        mode    => CORDIC_ROTATION,
        inputs  => correction_inputs,
        outputs => correction_outputs
      ) ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            if( init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.out_sample.valid <= '0' ;
        future.atan_sum_valid <= '0' ;
        future.lfsr_advance <= '0' ;
        future.fifo_read <= '0' ;
        future.atan_sample.valid <= '0' ;

        future.pilot_polarity <= lfsr_data(0);
        future.cordic_valid <= current.atan_sample.valid & current.cordic_valid( 15 downto 1 ) ;

        future.set_ready <= '0' ;
        future.clear_ready <= '0' ;

        if( current.set_ready = '1' ) then
            future.ready <= '1' ;
        elsif( current.clear_ready = '1' ) then
            future.ready <= '0' ;
        end if ;

        case current.wfsm is
            when IDLE =>
                future.wfsm <= WRITE_SAMPLES ;
            when WRITE_SAMPLES =>

                if( in_sample.valid = '1' ) then
                    case current.windex is
                        -- Check for DC null
                        when 0 =>

                        -- Check for outside nulls
                        when 27 to 37 =>

                        -- Check for 3 positive pilots
                        when 7|43|57 =>
                            if( current.pilot_polarity = '1' ) then
                                future.atan_sample.i <= - in_sample.i ;
                                future.atan_sample.q <= - in_sample.q ;
                                future.atan_sample.valid <= in_sample.valid ;
                            else
                                future.atan_sample <= in_sample;
                            end if ;

                        -- Check for 1 negative pilot
                        when 21 =>
                            if( current.pilot_polarity = '1' ) then
                                future.atan_sample <= in_sample;
                            else
                                future.atan_sample.i <= - in_sample.i ;
                                future.atan_sample.q <= - in_sample.q ;
                                future.atan_sample.valid <= in_sample.valid ;
                            end if ;

                        -- Otherwise data
                        when others =>

                    end case ;

                    -- Check if we've reached a full symbol length
                    if( current.windex < 64 ) then
                        future.windex <= current.windex + 1 ;
                    end if ;
                end if ;
                if( current.windex = 64) then
                    future.lfsr_advance <= '1' ;
                    future.windex <= 0 ;
                end if ;
        end case ;

        case current.cfsm is
            when IDLE =>
                future.cfsm <= CAPTURE_CORDIC ;
                future.atan_sum <= ( others => '0' ) ;
                future.norm_x_sum <= ( others => '0' ) ;
                future.norm_y_sum <= ( others => '0' ) ;
                future.atan_count <= 0 ;

            when CAPTURE_CORDIC =>
                if( cordic_normed.valid = '1' ) then
                    future.norm_x_sum <= current.norm_x_sum + cordic_normed.x ;
                    future.norm_y_sum <= current.norm_y_sum - cordic_normed.y ;

                    future.atan_count <= current.atan_count + 1 ;
                    if( current.atan_count = 3 ) then
                        future.cfsm <= CAPTURE_CORRECTION ;
                    end if ;
                end if ;

            when CAPTURE_CORRECTION =>
                future.phasor.i <= resize(shift_right(current.norm_x_sum, 2), 16) ;
                future.phasor.q <= resize(shift_right(current.norm_y_sum, 2), 16) ;
                future.set_ready <= '1' ;
                future.cfsm <= IDLE ;
        end case ;


        case current.rfsm is
            when IDLE =>
                if( current.ready = '1' ) then
                    future.clear_ready <= '1' ;
                    future.rindex <= 0 ;
                    future.rfsm <= READ_SAMPLES ;
                end if ;

            when READ_SAMPLES =>
                if( fifo_empty = '0' ) then
                    future.rindex <= current.rindex + 1 ;
                    future.fifo_read <= '1' ;
                    if (current.rindex = 63 ) then
                        future.rfsm <= IDLE ;
                    end if ;
                end if ;
        end case ;

        if( current.fifo_read = '1' ) then
            future.out_sample.i <= resize(shift_right( current.phasor.i * fifo_sample.i - current.phasor.q * fifo_sample.q, 11 ), 16 ) ;
            future.out_sample.q <= resize(shift_right( current.phasor.i * fifo_sample.q + current.phasor.q * fifo_sample.i, 11 ), 16 ) ;
            future.out_sample.valid <= '1' ;
        end if ;
    end process ;

end architecture ;


