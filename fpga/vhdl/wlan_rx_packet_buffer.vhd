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

entity wlan_rx_packet_buffer is
    port (
      clock              :   in std_logic ;
      reset              :   in std_logic ;

      framer_quiet_reset :   in std_logic ;
      framer_done        :   in std_logic ;
      crc_correct        :   in std_logic ;

      in_params          :   in wlan_rx_params_t ;
      in_params_valid    :   in std_logic ;

      in_data            :   in std_logic_vector( 7 downto 0 ) ;
      in_data_valid      :   in std_logic ;

      dsss_framer_done   :   in std_logic ;
      dsss_crc_correct   :   in std_logic ;

      dsss_params        :   in wlan_rx_params_t ;
      dsss_params_valid  :   in std_logic ;

      dsss_data          :   in std_logic_vector( 7 downto 0 ) ;
      dsss_data_valid    :   in std_logic ;

      out_params         :  out wlan_rx_params_t ;
      out_params_valid   :  out std_logic ;

      out_data           :  out std_logic_vector( 7 downto 0 ) ;
      out_data_valid     :  out std_logic ;

      out_end_of_packet  :  out std_logic
    ) ;
end entity;

architecture arch of wlan_rx_packet_buffer is
    type wfsm_t is (IDLE, WRITE_DATA, DUMP_BUFFER, COMMIT_BUFFER) ;
    type rfsm_t is (IDLE, READ, CLEAR_BUFFER, EOP) ;
    type state_t is record
        wfsm                :   wfsm_t ;
        rfsm                :   rfsm_t ;

        read                :   std_logic ;

        buf_a_writing       :   std_logic ;
        buf_a_reading       :   std_logic ;

        buf_a_ready         :   std_logic ;
        buf_b_ready         :   std_logic ;

        buf_a_reset         :   std_logic ;
        buf_b_reset         :   std_logic ;

        buf_a_clear         :   std_logic ;
        buf_b_clear         :   std_logic ;

        buf_a_params        :   wlan_rx_params_t ;
        buf_b_params        :   wlan_rx_params_t ;

        out_params          :   wlan_rx_params_t ;
        out_params_valid    :   std_logic ;

        out_end_of_packet   :   std_logic ;

        timer               :   natural range 0 to 1600 ;

        dsss_mode           :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.wfsm := IDLE ;

        rv.read := '0' ;

        rv.buf_a_writing := '0' ;
        rv.buf_a_reading := '0' ;

        rv.buf_a_ready := '0' ;
        rv.buf_b_ready := '0' ;

        rv.buf_a_reset := '0' ;
        rv.buf_b_reset := '0' ;

        rv.buf_a_clear := '0' ;
        rv.buf_b_clear := '0' ;

        rv.out_params_valid := '0' ;

        rv.out_end_of_packet := '0' ;

        rv.timer := 0 ;

        rv.dsss_mode := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    signal fifo_a_q         :   std_logic_vector( 7 downto 0 ) ;
    signal fifo_a_empty     :   std_logic ;
    signal fifo_a_usedw     :   std_logic_vector( 10 downto 0 ) ;

    signal fifo_b_q         :   std_logic_vector( 7 downto 0 ) ;
    signal fifo_b_empty     :   std_logic ;
    signal fifo_b_usedw     :   std_logic_vector( 10 downto 0 ) ;

    signal fifo_data        :   std_logic_vector( 7 downto 0 ) ;
    signal fifo_wrreq_a     :   std_logic ;
    signal fifo_wrreq_b     :   std_logic ;
begin

    out_params <= current.out_params ;
    out_params_valid <= current.out_params_valid ;

    out_data <= fifo_a_q when current.buf_a_reading = '1' else fifo_b_q ;
    out_data_valid <= current.read ;

    out_end_of_packet <= current.out_end_of_packet ;

    U_fifo_a : scfifo
      generic map (
        lpm_width       =>  8,
        lpm_widthu      =>  11,
        lpm_numwords    =>  1600,
        lpm_showahead   =>  "ON"
      ) port map (
        clock           =>  clock,
        aclr            =>  reset,
        sclr            =>  current.buf_a_reset or current.buf_a_clear,
        data            =>  fifo_data,
        wrreq           =>  fifo_wrreq_a,
        rdreq           =>  current.read and current.buf_a_reading,
        q               =>  fifo_a_q,
        full            =>  open,
        empty           =>  fifo_a_empty,
        usedw           =>  fifo_a_usedw
      ) ;

    U_fifo_b : scfifo
      generic map (
        lpm_width       =>  8,
        lpm_widthu      =>  11,
        lpm_numwords    =>  1600,
        lpm_showahead   =>  "ON"
      ) port map (
        clock           =>  clock,
        aclr            =>  reset,
        sclr            =>  current.buf_b_reset or current.buf_b_clear,
        data            =>  fifo_data,
        wrreq           =>  fifo_wrreq_b,
        rdreq           =>  current.read and not current.buf_a_reading,
        q               =>  fifo_b_q,
        full            =>  open,
        empty           =>  fifo_b_empty,
        usedw           =>  fifo_b_usedw
      ) ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process(all)
    begin
        if( current.dsss_mode = '1' ) then
            fifo_data <= dsss_data ;
            fifo_wrreq_a <= dsss_data_valid and current.buf_a_writing ;
            fifo_wrreq_b <= dsss_data_valid and not current.buf_a_writing ;
        else
            fifo_data <= in_data ;
            fifo_wrreq_a <= in_data_valid and current.buf_a_writing ;
            fifo_wrreq_b <= in_data_valid and not current.buf_a_writing ;
        end if ;
        future <= current ;

        future.buf_a_reset <= '0' ;
        future.buf_b_reset <= '0' ;
        future.buf_a_ready <= '0' ;
        future.buf_b_ready <= '0' ;
        case current.wfsm is
            when IDLE =>
                if( (framer_quiet_reset = '0' and in_params_valid = '1') or dsss_params_valid = '1' ) then
                    if( current.buf_a_writing = '1' and fifo_a_empty = '1') then

                        if( dsss_params_valid = '1' ) then
                            future.buf_a_params <= dsss_params ;
                        else
                            future.buf_a_params <= in_params ;
                        end if ;

                        future.wfsm <= WRITE_DATA ;
                    elsif( current.buf_a_writing = '0' and fifo_b_empty = '1' ) then
                        if( dsss_params_valid = '1' ) then
                            future.buf_b_params <= dsss_params ;
                        else
                            future.buf_b_params <= in_params ;
                        end if ;
                        future.wfsm <= WRITE_DATA ;
                    end if ;
                    future.dsss_mode <= dsss_params_valid ;
                end if ;

            when WRITE_DATA =>
                if( current.dsss_mode = '0' ) then
                    if( framer_quiet_reset = '1' or ( framer_done = '1' and crc_correct = '0' ) ) then
                        future.wfsm <= DUMP_BUFFER ;
                    end if ;
                    if( framer_done = '1' and crc_correct = '1' ) then
                        future.wfsm <= COMMIT_BUFFER ;
                    end if ;
                else
                    if( dsss_framer_done = '1' ) then
                        if ( dsss_crc_correct = '1' ) then
                            future.wfsm <= COMMIT_BUFFER ;
                        else
                            future.wfsm <= DUMP_BUFFER ;
                        end if ;
                    end if ;
                end if ;

            when DUMP_BUFFER =>
                if( current.buf_a_writing = '1' ) then
                    future.buf_a_reset <= '1' ;
                else
                    future.buf_b_reset <= '1' ;
                end if ;
                future.wfsm <= IDLE ;

            when COMMIT_BUFFER =>
                if( current.buf_a_writing = '1' ) then
                    future.buf_a_writing <= '0' ;
                    future.buf_a_ready <= '1' ;
                else
                    future.buf_a_writing <= '1' ;
                    future.buf_b_ready <= '1' ;
                end if ;

                future.wfsm <= IDLE ;
        end case ;

        future.out_end_of_packet <= '0' ;
        future.buf_a_clear <= '0' ;
        future.buf_b_clear <= '0' ;
        case current.rfsm is
            when IDLE =>
                if( current.buf_a_ready = '1' and fifo_a_empty = '0' ) then
                    future.out_params <= current.buf_a_params ;
                    future.out_params_valid <= '1' ;
                    future.buf_a_reading <= '1' ;
                    future.timer <= current.buf_a_params.length - 2 ;
                    future.rfsm <= READ ;
                elsif( current.buf_b_ready = '1' and fifo_b_empty = '0' ) then
                    future.out_params <= current.buf_b_params ;
                    future.out_params_valid <= '1' ;
                    future.buf_a_reading <= '0' ;
                    future.timer <= current.buf_b_params.length - 2 ;
                    future.rfsm <= READ ;
                end if ;

            when READ =>
                if( ( current.buf_a_reading = '1' and fifo_a_empty = '1' ) or
                    ( current.buf_a_reading = '0' and fifo_b_empty = '1' ) or
                    current.timer = 0) then

                    future.read <= '0' ;
                    future.rfsm <= CLEAR_BUFFER ;
                else
                    future.read <= '1' ;
                    future.timer <= current.timer - 1 ;
                end if ;

            when CLEAR_BUFFER =>
                if( current.buf_a_reading = '1' ) then
                    future.buf_a_clear <= '1' ;
                else
                    future.buf_b_clear <= '1' ;
                end if ;
                if( ( current.buf_a_reading = '1' and fifo_a_empty = '1' ) or
                    ( current.buf_a_reading = '0' and fifo_b_empty = '1' ) ) then
                    future.rfsm <= EOP ;
                end if ;

            when EOP =>
                future.out_end_of_packet <= '1' ;
                future.out_params_valid <= '0' ;
                future.rfsm <= IDLE ;
        end case ;
    end process ;
end architecture ;

