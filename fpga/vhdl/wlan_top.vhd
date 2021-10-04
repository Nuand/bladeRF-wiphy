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

library wlan;
    use wlan.wlan_p.all ;
    use wlan.wlan_tx_p.all ;
    use wlan.wlan_rx_p.all ;

library nuand;
    use nuand.fifo_readwrite_p.all;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

entity wlan_top is
  port (
    rx_clock           :   in  std_logic ;
    rx_reset           :   in  std_logic ;
    rx_enable          :   in  std_logic ;

    tx_clock           :   in  std_logic ;
    tx_reset           :   in  std_logic ;
    tx_enable          :   in  std_logic ;

    config_reg         :   in  std_logic_vector(31 downto 0 ) ;

    packet_en          :   in  std_logic ;

    tx_packet_control  :   in      packet_control_t ;
    tx_packet_empty    :   in      std_logic ;
    tx_packet_ready    :   out     std_logic ;

    rx_packet_control  :   out     packet_control_t ;
    rx_packet_ready    :   in      std_logic ;

    rx_fifo_usedw      :   in      std_logic_vector(11 downto 0);
    rx_fifo_write      :   out     std_logic ;
    rx_fifo_full       :   in      std_logic ;
    rx_fifo_data       :   out     std_logic_vector(31 downto 0) ;

    tx_fifo_usedw      :   in      std_logic_vector(11 downto 0);
    tx_fifo_read       :   buffer  std_logic ;
    tx_fifo_empty      :   in      std_logic ;
    tx_fifo_data       :   in      std_logic_vector(31 downto 0) ;

    gain_inc_req       :   out     std_logic ;
    gain_dec_req       :   out     std_logic ;
    gain_rst_req       :   out     std_logic ;
    gain_ack           :   in      std_logic ;
    gain_nack          :   in      std_logic ;
    gain_lock          :   in      std_logic ;
    gain_max           :   in      std_logic ;

    tx_ota_req         :   out     std_logic ;
    tx_ota_ack         :   in      std_logic ;

    out_i              :   buffer  signed(15 downto 0) ;
    out_q              :   buffer  signed(15 downto 0) ;
    out_valid          :   buffer  std_logic ;
    wlan_tx_ota        :   buffer  std_logic ;

    in_i               :   in signed(15 downto 0) ;
    in_q               :   in signed(15 downto 0) ;
    in_valid           :   in std_logic

  ) ;
end entity ;

architecture arch of wlan_top is

    type fsm_tx_t is (IDLE, WAIT_FOR_SOP, READ_HEADER, READ_VECTOR, VALID_VECTOR,
                      READ_PAYLOAD, READ_BLANKS, VALID_ACK, SEND_ACK, WAIT_TO_TX, WAIT_TO_ACK,
                      WAIT_FOR_ACK, WAIT_TO_RETRY_TX, VALID_RETRY_VECTOR,
                      READ_RETRY_FIFO, NO_ACK_RECEIVED, GOOD_ACK_RECEIVED, WRITE_ACK_TO_FIFO);
    type fsm_rx_t is (IDLE, TX_ACK_HEADER, TX_ACK_WRITE, READ_VECTOR,
                      WAIT_TO_WRITE_HEADER, WRITE_HEADER, WRITE_PAYLOAD,
                      PAD_ZERO);

    type state_rx_t is record
        fsm                  :  fsm_rx_t;
        header               :  std_logic_vector(127 downto 0) ;
        length               :  natural range 0 to 4096 ;
        byte_index           :  natural range 0 to 3 ;
        written_bytes        :  natural range 0 to 65536 ;
        written_words        :  natural range 0 to 4096 ;
        fifo_write           :  std_logic ;
        rx_word              :  std_logic_vector(31 downto 0) ;
        read_payload         :  std_logic ;
        packet_control       :  packet_control_t ;
        fifo_tx_ack_rreq     :  std_logic ;
    end record;

    type state_tx_t is record
        fsm                  :  fsm_tx_t ;
        header               :  std_logic_vector(127 downto 0) ;
        byte_index           :  natural range 0 to 3 ;
        read_bytes           :  natural range 0 to 65536 ;
        read_words           :  natural range 0 to 4096 ;
        fifo_read            :  std_logic ;
        tx_word              :  std_logic_vector(31 downto 0) ;
        ready_for_packet     :  std_logic ;

        tx_ack_required      :  std_logic ;
        tx_ack_attempt       :  natural range 0 to 10;
        tx_ack_timeout       :  natural range 0 to 25000;
        tx_ack_fifo_rst      :  std_logic ;
        tx_ack_fifo_write    :  std_logic ;
        tx_packet_header     :  std_logic_vector(87 downto 0) ;

        tx_packet_flags      :  std_logic_vector(15 downto 0) ;
        tx_packet_cookie     :  std_logic_vector(31 downto 0) ;

        fifo_tx_ack_wreq     :  std_logic ;
        fifo_tx_ack_data     :  std_logic_vector( 63 downto 0 ) ;

        timer                :  natural range 0 to 20000 ;
        tx_vector            :  wlan_tx_vector_t ;
        tx_vector_valid      :  std_logic ;
        in_ack               :  std_logic ;
        in_wait_for_ack      :  std_logic ;

        tx_ota_req           :  std_logic ;
    end record;

    function datarate_to_lv( x : wlan_datarate_t ) return std_logic_vector is
        variable rv : std_logic_vector(3 downto 0) ;
    begin
        case x is
            when WLAN_RATE_6  => rv := x"0" ;
            when WLAN_RATE_9  => rv := x"1" ;
            when WLAN_RATE_12 => rv := x"2" ;
            when WLAN_RATE_18 => rv := x"3" ;
            when WLAN_RATE_24 => rv := x"4" ;
            when WLAN_RATE_36 => rv := x"5" ;
            when WLAN_RATE_48 => rv := x"6" ;
            when WLAN_RATE_54 => rv := x"7" ;
            when others       => rv := x"0" ;
        end case ;
        return rv ;
    end function ;

    function bandwidth_to_lv( x : wlan_bandwidth_t ) return std_logic_vector is
        variable rv : std_logic_vector(3 downto 0) ;
    begin
        case x is
            when WLAN_BW_5   => rv := x"0" ;
            when WLAN_BW_10  => rv := x"1" ;
            when WLAN_BW_20  => rv := x"2" ;
            when others      => rv := x"0" ;
        end case ;
        return rv ;
    end function ;

    signal tx_vector            :  wlan_tx_vector_t ;
    signal tx_vector_valid      :  std_logic ;
    signal tx_status            :  wlan_tx_status_t ;
    signal tx_status_valid      :  std_logic ;
    signal tx_wlan_fifo_re      :  std_logic ;
    signal tx_wlan_fifo_data    :  std_logic_vector(7 downto 0) ;
    signal tx_wlan_fifo_empty   :  std_logic ;
    signal bb                   :  wlan_sample_t ;
    signal done                 :  std_Logic ;

    function NULL_RX_STATE return state_rx_t is
        variable rv : state_rx_t;
    begin
        rv.fsm := IDLE ;
        rv.header := (others => '0' ) ;
        rv.length := 0 ;
        rv.byte_index := 0 ;
        rv.written_words := 0 ;
        rv.written_bytes := 0 ;
        rv.fifo_write := '0' ;
        rv.rx_word := (others => '0' ) ;
        rv.read_payload := '0' ;
        rv.fifo_tx_ack_rreq := '0';
        return rv ;
    end function ;

    function NULL_TX_STATE return state_tx_t is
        variable rv : state_tx_t;
    begin
        rv.fsm := IDLE ;
        rv.read_words := 0 ;
        rv.read_bytes := 0 ;
        rv.header := (others => '0' ) ;
        rv.tx_word := (others => '0' ) ;

        rv.ready_for_packet := '0' ;

        rv.tx_ack_required := '0' ;
        rv.tx_ack_attempt := 3;
        rv.tx_ack_timeout := 2500;
        rv.tx_ack_fifo_rst   := '0';
        rv.tx_ack_fifo_write := '0';
        rv.tx_packet_header := ( others => '0' );

        rv.tx_packet_flags   := ( others => '0' ) ;
        rv.tx_packet_cookie  := ( others => '0' ) ;

        rv.fifo_tx_ack_wreq  := '0' ;
        rv.fifo_tx_ack_data  := ( others => '0' ) ;

        rv.timer := 0 ;
        rv.byte_index := 0 ;
        rv.fifo_read := '0' ;
        rv.tx_vector_valid := '0' ;
        rv.in_ack := '0' ;
        rv.in_wait_for_ack := '0' ;

        rv.tx_ota_req := '0' ;
        return rv ;
    end function ;

    signal current_tx_state, future_tx_state          :  state_tx_t ;
    signal current_rx_state, future_rx_state          :  state_rx_t ;
    attribute keep: boolean;
    attribute noprune: boolean;
    attribute preserve: boolean;

    attribute keep of tx_vector : signal is true;
    attribute noprune of tx_vector : signal is true;
    attribute preserve of tx_vector : signal is true;

    attribute keep of done : signal is true;
    attribute noprune of done : signal is true;
    attribute preserve of done : signal is true;

    attribute keep of current_tx_state : signal is true;
    attribute noprune of current_tx_state : signal is true;
    attribute preserve of current_tx_state : signal is true;

    signal rx_end_of_packet   :  std_logic ;
    signal rx_status  :  wlan_rx_status_t ;
    signal rx_status_valid  :  std_logic ;
    signal rx_vector  :  wlan_rx_vector_t ;
    signal rx_vector_valid  :  std_logic ;

    signal rx_data         :  std_logic_vector( 7 downto 0 ) ;
    signal rx_data_valid   :  std_logic ;
    signal rx_data_read    :  std_logic ;

    signal ack_mac         :   std_logic_vector( 47 downto 0 ) ;
    signal ack_valid       :   std_logic ;

    signal tx_idle         :  std_logic ;
    signal tx_difs_ready   :  std_logic ;
    signal tx_sifs_ready   :  std_logic ;

    signal tx_ack_ready    :  std_logic ;
    signal tx_ack_re       :  std_logic ;
    signal tx_ack_data     :  std_logic_vector( 7 downto 0 ) ;

    signal rx_block        :  std_logic ;
    signal rx_quiet        :  std_logic ;

    signal tx_req          :  std_logic ;

    signal ack_timer_val   :  unsigned( 15 downto 0 );

    signal tx_retry_fifo_q       :   std_logic_vector( 7 downto 0 ) ;
    signal tx_retry_fifo_rst     :   std_logic ;
    signal tx_retry_fifo_empty   :   std_logic ;
    signal tx_retry_fifo_usedw   :   std_logic_vector( 10 downto 0 ) ;

    signal fifo_tx_ack_wfull     :   std_logic ;

    signal fifo_tx_ack_q         :   std_logic_vector( 63 downto 0 ) ;
    signal fifo_tx_ack_rempty    :   std_logic ;

    signal tx_retry_fifo_data    :   std_logic_vector( 7 downto 0 ) ;
    signal tx_retry_fifo_write   :   std_logic ;
    signal tx_retry_fifo_read    :   std_logic ;

    signal acked_packet          :   std_logic ;
begin
    rx_block <= wlan_tx_ota;
    --rx_block <= '0';

    tx_req <= '1' when ( tx_packet_empty = '0' ) else '0' ;
    U_dcf : entity work.wlan_dcf
      port map (
        rx_clock            =>  rx_clock,
        rx_reset            =>  rx_reset,
        rx_enable           =>  rx_enable,

        rand_lsb            =>  in_i(0),
        rand_valid          =>  in_valid,

        rx_quiet            =>  rx_quiet,

        rx_block            =>  open,

        tx_clock            =>  tx_clock,
        tx_reset            =>  tx_reset,
        tx_enable           =>  tx_enable,

        tx_req              =>  tx_req,
        tx_idle             =>  not wlan_tx_ota,

        tx_sifs_ready       =>  tx_sifs_ready,
        tx_difs_ready       =>  tx_difs_ready
      ) ;

    U_ack_gen : entity work.wlan_ack_generator
      port map (
        wclock              =>  rx_clock,
        wreset              =>  rx_reset,

        ack_mac             =>  ack_mac,
        ack_valid           =>  ack_valid,

        rclock              =>  tx_clock,
        rreset              =>  tx_reset,

        fifo_data           =>  tx_ack_data,
        fifo_re             =>  tx_ack_re,
        done_tx             =>  done,

        ack_ready           =>  tx_ack_ready
      ) ;

    U_wlan_rx : entity work.wlan_rx
      port map (
        clock40m            =>  rx_clock,
        reset40m            =>  rx_reset,

        bb_i                =>  in_i,
        bb_q                =>  in_q,
        bb_valid            =>  in_valid,

        equalized_i         =>  open,
        equalized_q         =>  open,
        equalized_valid     =>  open,

        gain_inc_req        => gain_inc_req,
        gain_dec_req        => gain_dec_req,
        gain_rst_req        => gain_rst_req,
        gain_ack            => gain_ack,
        gain_nack           => gain_nack,
        gain_lock           => gain_lock,
        gain_max            => gain_max,

        ack_mac             =>  ack_mac,
        ack_valid           =>  ack_valid,

        acked_packet        =>  acked_packet,

        rx_quiet            =>  rx_quiet,
        rx_block            =>  rx_block,

        rx_end_of_packet    =>  rx_end_of_packet,
        rx_status           =>  rx_status,
        rx_status_valid     =>  rx_status_valid,

        rx_vector           =>  rx_vector,
        rx_vector_valid     =>  rx_vector_valid,

        rx_data_req         =>  current_rx_state.read_payload,
        rx_data             =>  rx_data,
        rx_data_valid       =>  rx_data_valid,

        mse                 =>  open,
        mse_valid           =>  open
      ) ;

    U_wlan_tx : entity work.wlan_tx
      port map (
        clock               =>  tx_clock,
        reset               =>  tx_reset,

        tx_vector           =>  tx_vector,
        tx_vector_valid     =>  tx_vector_valid,

        tx_status           =>  tx_status,
        tx_status_valid     =>  tx_status_valid,

        fifo_re             =>  tx_wlan_fifo_re,
        fifo_data           =>  tx_wlan_fifo_data,
        fifo_empty          =>  tx_wlan_fifo_empty,

        bb                  =>  bb,
        done                =>  done
      ) ;

    wlan_tx_ota <= '1' when ( tx_ota_ack = '1' and current_tx_state.tx_ota_req = '1' ) else '0';

    tx_idle <= '1' when (current_tx_state.fsm /= IDLE) else '0' ;

    out_i <= resize(shift_right(bb.i, 2), 16);
    out_q <= resize(shift_right(bb.q, 2), 16);
    out_valid <= bb.valid;

    rx_fifo_data <= current_rx_state.rx_word ;
    rx_fifo_write <= current_rx_state.fifo_write ;

    rx_packet_control.pkt_core_id <= ( others => '0' ) ;
    rx_packet_control.pkt_flags   <= ( others => '0' ) ;
    rx_packet_control.pkt_sop     <= current_rx_state.packet_control.pkt_sop ;
    rx_packet_control.pkt_eop     <= current_rx_state.packet_control.pkt_eop ;
    rx_packet_control.data        <= current_rx_state.rx_word ;
    rx_packet_control.data_valid  <= current_rx_state.fifo_write ;

    rx_state_comb : process(all)
        variable written_bytes : natural range 0 to 4096;
    begin
        future_rx_state <= current_rx_state;
        future_rx_state.fifo_write <= '0' ;
        future_rx_state.read_payload <= '0' ;

        future_rx_state.fifo_tx_ack_rreq  <= '0' ;

        future_rx_state.packet_control.pkt_sop <= '0' ;
        future_rx_state.packet_control.pkt_eop <= '0' ;

        case current_rx_state.fsm is

            when IDLE =>
                if( fifo_tx_ack_rempty = '0' ) then
                    future_rx_state.fsm <= TX_ACK_HEADER;
                end if;

                if( rx_vector_valid = '1' ) then
                    future_rx_state.fsm <= READ_VECTOR ;
                    future_rx_state.header <= ( others => '0' ) ;
                    future_rx_state.rx_word <= ( others => '0' ) ;
                end if ;

            when TX_ACK_HEADER =>
                future_rx_state.header(63 downto 0) <= fifo_tx_ack_q ;
                future_rx_state.written_words <= 0 ;
                if( rx_packet_ready = '1' ) then
                    future_rx_state.fifo_tx_ack_rreq  <= '1' ;
                    future_rx_state.fsm <= TX_ACK_WRITE ;
                end if;

            when TX_ACK_WRITE =>
                future_rx_state.rx_word <= current_rx_state.header(31 downto 0);
                future_rx_state.header <= x"00000000" & current_rx_state.header(127 downto 32);

                future_rx_state.fifo_write <= '1' ;

                future_rx_state.written_words <= current_rx_state.written_words + 1 ;
                if( current_rx_state.written_words = 0 ) then
                    future_rx_state.packet_control.pkt_sop <= '1' ;
                elsif( current_rx_state.written_words = 3 ) then
                    future_rx_state.packet_control.pkt_eop <= '1' ;
                    future_rx_state.fsm <= IDLE;
                end if;

            when READ_VECTOR =>
                future_rx_state.length <= rx_vector.length - 2 ; -- 2 for SERVICE, and 4 for FCS
                future_rx_state.header(23  downto 0 ) <= x"0" & bandwidth_to_lv(rx_vector.bandwidth) & x"0001";
                future_rx_state.header(31  downto 24) <= x"0" & datarate_to_lv(rx_vector.datarate);
                future_rx_state.header(47  downto 32) <= std_logic_vector(to_unsigned(rx_vector.length - 2, 16));
                future_rx_state.header(127 downto 48) <= ( others => '0' );
                if( rx_packet_ready = '1' ) then
                   future_rx_state.fsm <= WRITE_HEADER ;
                else
                   future_rx_state.fsm <= WAIT_TO_WRITE_HEADER ;
                end if;
                future_rx_state.byte_index <= 0 ;

            when WAIT_TO_WRITE_HEADER =>
                if( rx_packet_ready = '1' ) then
                   future_rx_state.fsm <= WRITE_HEADER ;
                end if;

            when WRITE_HEADER =>
                future_rx_state.rx_word <= current_rx_state.header(31 downto 0);
                if( current_rx_state.byte_index = 0 ) then
                    future_rx_state.packet_control.pkt_sop <= '1' ;
                end if;
                future_rx_state.fifo_write <= '1' ;

                future_rx_state.header <= x"00000000" & current_rx_state.header(127 downto 32);

                if( current_rx_state.byte_index = 3 ) then
                    future_rx_state.byte_index <= 0 ;
                    future_rx_state.written_words <= 4 ;
                    future_rx_state.written_bytes <= 1 ;
                    future_rx_state.fsm <= WRITE_PAYLOAD ;
                else
                    future_rx_state.byte_index <= current_rx_state.byte_index + 1 ;
                end if ;

            when WRITE_PAYLOAD =>
                future_rx_state.read_payload <= '1' ;
                if( rx_data_valid = '1' ) then
                    if( current_rx_state.byte_index = 3 ) then
                        future_rx_state.rx_word(31 downto 24) <= rx_data ;
                    elsif( current_rx_state.byte_index = 2 ) then
                        future_rx_state.rx_word(23 downto 16) <= rx_data ;
                    elsif( current_rx_state.byte_index = 1 ) then
                        future_rx_state.rx_word(15 downto 8) <= rx_data ;
                    elsif( current_rx_state.byte_index = 0 ) then
                        future_rx_state.rx_word(7 downto 0) <= rx_data ;
                    end if ;
                    future_rx_state.written_bytes <= current_rx_state.written_bytes + 1 ;

                    if( current_rx_state.byte_index = 3 ) then
                        future_rx_state.fifo_write <= '1' ;
                        future_rx_state.written_words <= current_rx_state.written_words + 1 ;
                        if( current_rx_state.written_bytes = current_rx_state.length ) then
                            future_rx_state.packet_control.pkt_eop    <= '1' ;
                        end if;
                        future_rx_state.byte_index <= 0 ;
                    else
                        future_rx_state.byte_index <= current_rx_state.byte_index + 1 ;
                    end if ;
                end if ;
                if( rx_end_of_packet = '1' or current_rx_state.length <= current_rx_state.written_bytes ) then
                    future_rx_state.fsm <= PAD_ZERO ;
                end if ;

            when PAD_ZERO =>
                if( current_rx_state.byte_index = 3 ) then
                    future_rx_state.rx_word(31 downto 24) <= x"00" ;
                elsif( current_rx_state.byte_index = 2 ) then
                    future_rx_state.rx_word(31 downto 16) <= x"0000" ;
                elsif( current_rx_state.byte_index = 1 ) then
                    future_rx_state.rx_word(31 downto 8) <= x"000000" ;
                elsif( current_rx_state.byte_index = 0 ) then
                    future_rx_state.rx_word(31 downto 0) <= ( others => '0' ) ;
                end if ;

                future_rx_state.fsm <= IDLE ;

                if( current_rx_state.byte_index /= 0 ) then
                    future_rx_state.packet_control.pkt_eop    <= '1' ;
                    future_rx_state.fifo_write <= '1' ;
                end if ;

        end case ;
    end process ;

    process( rx_clock, rx_reset )
    begin
        if( rx_reset = '1' ) then
            current_rx_state <= NULL_RX_STATE ;
        elsif( rising_edge(rx_clock) ) then
            current_rx_state <= future_rx_state ;
        end if ;
    end process ;


    tx_packet_ready <= '1' when ( current_tx_state.fifo_read = '1' or current_tx_state.ready_for_packet = '1' ) else '0' ;

    tx_vector_valid <= current_tx_state.tx_vector_valid ;
    tx_vector <= current_tx_state.tx_vector ;
    tx_ota_req <= current_tx_state.tx_ota_req ;
    ack_timer_val <= unsigned(config_reg(15 downto 0));

    tx_state_comb : process(all)
    begin
        future_tx_state <= current_tx_state;

        case current_tx_state.fsm is
            when SEND_ACK =>
                tx_wlan_fifo_data <= tx_ack_data ;
                tx_retry_fifo_read <= '0';
                tx_ack_re <= tx_wlan_fifo_re ;
            when READ_RETRY_FIFO =>
                if( current_tx_state.read_bytes = 1 ) then
                   tx_wlan_fifo_data <= tx_retry_fifo_q or x"08";
                else
                   tx_wlan_fifo_data <= tx_retry_fifo_q;
                end if;
                tx_retry_fifo_read <= tx_wlan_fifo_re;
                tx_ack_re <= '0' ;
            when others =>
               case current_tx_state.byte_index is
                   when 0 => tx_wlan_fifo_data <= current_tx_state.tx_word( 7 downto  0) ;
                   when 1 => tx_wlan_fifo_data <= current_tx_state.tx_word(15 downto  8) ;
                   when 2 => tx_wlan_fifo_data <= current_tx_state.tx_word(23 downto 16) ;
                   when 3 => tx_wlan_fifo_data <= current_tx_state.tx_word(31 downto 24) ;
               end case;
               tx_retry_fifo_read <= '0';
               tx_ack_re <= '0' ;
        end case ;

        if( current_tx_state.fsm = READ_RETRY_FIFO or current_tx_state.fsm = READ_PAYLOAD) then
            tx_retry_fifo_write <= tx_wlan_fifo_re;
        else
            tx_retry_fifo_write <= '0';
        end if;

        future_tx_state.fifo_read <= '0';
        future_tx_state.tx_vector_valid <= '0';
        future_tx_state.ready_for_packet <= '0';

        future_tx_state.tx_ack_fifo_rst    <= '0';
        future_tx_state.tx_ack_fifo_write  <= '0';

        future_tx_state.fifo_tx_ack_wreq   <= '0' ;

        case current_tx_state.fsm is

            when IDLE =>
                if( tx_ack_ready = '1' ) then
                    future_tx_state.timer <= 5; --to_integer(ack_timer_val) ;

                    future_tx_state.fsm <= WAIT_TO_ACK ;

                elsif( tx_difs_ready = '1' and tx_packet_empty = '0' ) then
                    future_tx_state.timer <= 400 ; -- move back to 2500
                    future_tx_state.tx_ota_req <= '1' ;

                    future_tx_state.fsm <= WAIT_TO_TX ;

                    future_tx_state.read_words <= 0 ;
                else
                    future_tx_state <= NULL_TX_STATE;
                end if;

            when WAIT_TO_ACK =>
                future_tx_state.in_ack <= '1' ;

                future_tx_state.tx_vector.datarate <= WLAN_RATE_6 ;
                future_tx_state.tx_vector.bandwidth <= WLAN_BW_20 ;
                future_tx_state.tx_vector.length <= 10 ;
                if( current_tx_state.timer = 0 ) then
                    future_tx_state.timer <= 20 ; -- move back to 2500
                    future_tx_state.tx_ota_req <= '1' ;
                    future_tx_state.fsm <= WAIT_TO_TX ;
                else
                    future_tx_state.timer <= current_tx_state.timer - 1 ;
                end if ;

            when WAIT_TO_TX =>
                if( current_tx_state.timer = 0 ) then
                    if( tx_ota_ack = '1' ) then
                        if( current_tx_state.in_ack = '1' ) then
                            future_tx_state.fsm <= VALID_ACK;
                        else
                            future_tx_state.ready_for_packet <= '1';
                            future_tx_state.fsm <= WAIT_FOR_SOP;
                        end if ;
                    end if ;
                else
                    future_tx_state.timer <= current_tx_state.timer - 1 ;
                end if ;

            when VALID_ACK =>
                future_tx_state.fsm <= SEND_ACK ;
                future_tx_state.tx_vector_valid <= '1' ;

            when SEND_ACK =>
                if( done = '1' ) then
                    if( current_tx_state.in_wait_for_ack = '1' ) then
                       future_tx_state.fsm <= WAIT_FOR_ACK;
                    else
                       future_tx_state.fsm <= IDLE;
                    end if;
                    future_tx_state.in_ack <= '0' ;
                    future_tx_state.tx_ota_req <= '0' ;
                end if ;

            when WAIT_FOR_SOP =>
                if( tx_packet_control.pkt_sop = '1' ) then
                    future_tx_state.header <= tx_packet_control.data & current_tx_state.header(127 downto 32) ;
                    future_tx_state.read_words <= current_tx_state.read_words + 1;

                    future_tx_state.ready_for_packet <= '0';
                    future_tx_state.fsm <= READ_HEADER;
                else
                    future_tx_state.ready_for_packet <= '1';
                end if;

            when READ_HEADER =>
                if( current_tx_state.read_words <= 2 ) then
                   future_tx_state.fifo_read <= '1';
                else
                   future_tx_state.fifo_read <= '0';
                end if;

                if( tx_packet_control.data_valid = '1' ) then
                   future_tx_state.header <= tx_packet_control.data & current_tx_state.header(127 downto 32) ;
                   future_tx_state.read_words <= current_tx_state.read_words + 1;
                   if( current_tx_state.read_words = 2 ) then
                      future_tx_state.fifo_read <= '0';
                   end if;
                end if ;

                if( current_tx_state.read_words >= 3 ) then
                    future_tx_state.fsm <= READ_VECTOR ;
                end if ;

            when READ_VECTOR =>
                future_tx_state.fsm <= VALID_VECTOR ;
                future_tx_state.tx_vector.length <= to_integer(signed(current_tx_state.header(79 downto 64))) ;
                -- no ack <= current_tx_state.header(31 downto 16) (3rd and 4th bytes, currently reserverd)
                -- cookie <= current_tx_state.header(127 downto 96)
                future_tx_state.tx_packet_flags   <= current_tx_state.header(31 downto 16);
                future_tx_state.tx_packet_cookie  <= current_tx_state.header(127 downto 96);

                case current_tx_state.header(47 downto 32) is
                    when x"0000" => future_tx_state.tx_vector.datarate <= WLAN_RATE_6 ;
                    when x"0001" => future_tx_state.tx_vector.datarate <= WLAN_RATE_9 ;
                    when x"0002" => future_tx_state.tx_vector.datarate <= WLAN_RATE_12 ;
                    when x"0003" => future_tx_state.tx_vector.datarate <= WLAN_RATE_18 ;
                    when x"0004" => future_tx_state.tx_vector.datarate <= WLAN_RATE_24 ;
                    when x"0005" => future_tx_state.tx_vector.datarate <= WLAN_RATE_36 ;
                    when x"0006" => future_tx_state.tx_vector.datarate <= WLAN_RATE_48 ;
                    when x"0007" => future_tx_state.tx_vector.datarate <= WLAN_RATE_54 ;
                    when others  => future_tx_state.tx_vector.datarate <= WLAN_RATE_6 ;
                end case;

                case current_tx_state.header(63 downto 48) is
                    when x"0000" => future_tx_state.tx_vector.bandwidth <= WLAN_BW_5 ;
                    when x"0001" => future_tx_state.tx_vector.bandwidth <= WLAN_BW_10 ;
                    when x"0002" => future_tx_state.tx_vector.bandwidth <= WLAN_BW_20 ;
                    when others  => future_tx_state.tx_vector.bandwidth <= WLAN_BW_5 ;
                end case;

            when VALID_VECTOR =>
                future_tx_state.tx_word <= tx_packet_control.data ;

                future_tx_state.fifo_read <= '1';
                future_tx_state.read_words <= current_tx_state.read_words + 1;

                future_tx_state.tx_vector_valid <= '1' ;
                future_tx_state.fsm <= READ_PAYLOAD ;

                future_tx_state.tx_ack_fifo_rst  <= '1';

                future_tx_state.read_bytes <= 1;

            when READ_PAYLOAD =>
                --if( tx_packet_control.pkt_eop = '1' ) then
                --    future_tx_state.fsm <= FINISH_PACKET;
                --end if;
                if( tx_wlan_fifo_re = '1') then

                    -- figure out TX packet's ACK requirements
                    if( current_tx_state.read_bytes <= 10 ) then
                        future_tx_state.tx_packet_header <=
                              current_tx_state.tx_packet_header(79 downto 0) & tx_wlan_fifo_data ;
                    end if;
                    if( current_tx_state.read_bytes = 11 ) then
                        if( current_tx_state.tx_packet_header(75 downto 74) = "01" or
                            current_tx_state.tx_packet_header(47 downto 0) = x"FFFFFFFFFFFF" ) then
                           future_tx_state.tx_ack_required <= '0';
                        else
                           future_tx_state.tx_ack_required <= '1';
                           future_tx_state.tx_ack_attempt  <= 1;
                           future_tx_state.tx_ack_timeout  <= 0;
                        end if;
                    end if;

                    future_tx_state.read_bytes <= current_tx_state.read_bytes + 1 ;

                    if (current_tx_state.byte_index = 3) then
                        future_tx_state.fifo_read <= '1';
                        future_tx_state.read_words <= current_tx_state.read_words + 1;

                        future_tx_state.tx_word <= tx_packet_control.data ;
                        future_tx_state.byte_index <= 0;
                    else
                        future_tx_state.byte_index <= current_tx_state.byte_index + 1 ;
                    end if;
                end if;
                if( done = '1' ) then
                    future_tx_state.tx_ota_req <= '0' ;
                    if( current_tx_state.tx_ack_required = '1' ) then
                        future_tx_state.tx_ack_timeout <= 0;
                        future_tx_state.fsm <= WAIT_FOR_ACK;
                    else
                        future_tx_state <= NULL_TX_STATE ;
                    end if;
                end if;

            when WAIT_FOR_ACK =>
                future_tx_state.in_wait_for_ack <= '1' ;

                if( acked_packet = '1' ) then
                    future_tx_state.fsm <= GOOD_ACK_RECEIVED ;
                    future_tx_state.in_wait_for_ack <= '0' ;
                end if;

                if( current_tx_state.tx_ack_timeout = 2500) then
                    if( current_tx_state.tx_ack_attempt = 0) then
                       future_tx_state.fsm <= NO_ACK_RECEIVED;
                    else
                       if( tx_ack_ready = '1' ) then
                           future_tx_state.fsm <= WAIT_TO_ACK;
                       elsif( tx_difs_ready = '1' ) then
                           future_tx_state.in_wait_for_ack <= '0' ;
                           future_tx_state.fsm <= WAIT_TO_RETRY_TX;
                           future_tx_state.timer <= 2500 ;
                           future_tx_state.tx_ota_req <= '1' ;
                       end if;
                    end if;
                else
                   future_tx_state.tx_ack_timeout <= current_tx_state.tx_ack_timeout + 1;
                end if;

            when WAIT_TO_RETRY_TX =>
                if( current_tx_state.timer = 0 ) then
                    if( tx_ota_ack = '1' ) then
                       future_tx_state.fsm <= VALID_RETRY_VECTOR;
                    end if;
                else
                    future_tx_state.timer <= current_tx_state.timer - 1 ;
                end if ;

            when VALID_RETRY_VECTOR =>
                future_tx_state.tx_ack_attempt <= current_tx_state.tx_ack_attempt - 1;
                case current_tx_state.tx_vector.datarate is
                    when WLAN_RATE_9  => future_tx_state.tx_vector.datarate <= WLAN_RATE_6;
                    when WLAN_RATE_12 => future_tx_state.tx_vector.datarate <= WLAN_RATE_9;
                    when WLAN_RATE_18 => future_tx_state.tx_vector.datarate <= WLAN_RATE_12;
                    when WLAN_RATE_24 => future_tx_state.tx_vector.datarate <= WLAN_RATE_18;
                    when WLAN_RATE_36 => future_tx_state.tx_vector.datarate <= WLAN_RATE_24;
                    when WLAN_RATE_48 => future_tx_state.tx_vector.datarate <= WLAN_RATE_36;
                    when WLAN_RATE_54 => future_tx_state.tx_vector.datarate <= WLAN_RATE_48;
                    when others       => future_tx_state.tx_vector.datarate <= WLAN_RATE_6;
                end case;
                future_tx_state.tx_vector_valid <= '1' ;
                future_tx_state.fsm <= READ_RETRY_FIFO;
                future_tx_state.read_bytes <= 0;

            when READ_RETRY_FIFO =>
                if( tx_wlan_fifo_re = '1') then
                    future_tx_state.read_bytes <= current_tx_state.read_bytes + 1;
                end if;
                if( done = '1' ) then
                    future_tx_state.tx_ota_req <= '0' ;
                    future_tx_state.tx_ack_timeout <= 0;
                    future_tx_state.fsm <= WAIT_FOR_ACK;
                end if;

            when GOOD_ACK_RECEIVED =>
                future_tx_state.fifo_tx_ack_data(15 downto 0 ) <= x"0002" ;
                future_tx_state.fifo_tx_ack_data(23 downto 16) <= x"0" & bandwidth_to_lv(current_tx_state.tx_vector.bandwidth) ;
                future_tx_state.fifo_tx_ack_data(31 downto 24) <= x"0" & datarate_to_lv(current_tx_state.tx_vector.datarate) ;
                future_tx_state.fifo_tx_ack_data(63 downto 32) <= current_tx_state.tx_packet_cookie;
                if( fifo_tx_ack_wfull = '0' ) then
                   future_tx_state.fifo_tx_ack_wreq <= '1' ;
                   future_tx_state.fsm <= WRITE_ACK_TO_FIFO;
                end if;
            when NO_ACK_RECEIVED =>
                future_tx_state.fifo_tx_ack_data(15 downto 0 ) <= x"0003" ;
                future_tx_state.fifo_tx_ack_data(23 downto 16) <= x"0" & bandwidth_to_lv(current_tx_state.tx_vector.bandwidth) ;
                future_tx_state.fifo_tx_ack_data(31 downto 24) <= x"0" & datarate_to_lv(current_tx_state.tx_vector.datarate) ;
                future_tx_state.fifo_tx_ack_data(63 downto 32) <= current_tx_state.tx_packet_cookie;
                if( fifo_tx_ack_wfull = '0' ) then
                   future_tx_state.fifo_tx_ack_wreq <= '1' ;
                   future_tx_state.fsm <= WRITE_ACK_TO_FIFO;
                end if;

            when WRITE_ACK_TO_FIFO =>
                future_tx_state <= NULL_TX_STATE;

            when others =>
                future_tx_state <= NULL_TX_STATE;
        end case;
    end process ;

    U_fifo_tx_retry : scfifo
      generic map (
        lpm_width       =>  8,
        lpm_widthu      =>  11,
        lpm_numwords    =>  1600,
        lpm_showahead   =>  "ON"
      ) port map (
        clock           =>  tx_clock,
        aclr            =>  tx_reset,
        sclr            =>  tx_retry_fifo_rst,
        data            =>  tx_wlan_fifo_data,
        wrreq           =>  tx_retry_fifo_write,
        rdreq           =>  tx_retry_fifo_read,
        q               =>  tx_retry_fifo_q,
        full            =>  open,
        empty           =>  tx_retry_fifo_empty,
        usedw           =>  tx_retry_fifo_usedw
      ) ;
    tx_retry_fifo_rst <= current_tx_state.tx_ack_fifo_rst;

    process( tx_clock, tx_reset )
    begin
        if( tx_reset = '1' ) then
            current_tx_state <= NULL_TX_STATE ;
        elsif( rising_edge(tx_clock) ) then
            current_tx_state <= future_tx_state ;
        end if ;
    end process ;

    U_fifo_tx_ack: dcfifo
      generic map (
        lpm_width       =>  64,
        lpm_widthu      =>  3,
        lpm_numwords    =>  8,
        lpm_showahead   =>  "ON"
      )
      port map (
        aclr            => tx_reset,

        wrclk           => tx_clock,
        wrreq           => current_tx_state.fifo_tx_ack_wreq,
        data            => current_tx_state.fifo_tx_ack_data,

        wrfull          => fifo_tx_ack_wfull,
        wrempty         => open,
        wrusedw         => open,

        rdclk           => rx_clock,
        rdreq           => current_rx_state.fifo_tx_ack_rreq,
        q               => fifo_tx_ack_q,

        rdfull          => open,
        rdempty         => fifo_tx_ack_rempty,
        rdusedw         => open
      ) ;
end architecture ;

