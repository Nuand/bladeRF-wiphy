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

library work ;
    use work.wlan_p.all ;
    use work.wlan_tables_p.all ;
    use work.wlan_tx_p.all ;

library nuand;
    use nuand.fifo_readwrite_p.all;


entity wlan_top_tb is
end entity ;

architecture arch of wlan_top_tb is

    signal clock                :   std_logic                       := '1' ;
    signal reset                :   std_logic                       := '1' ;

    signal rx_enable            :   std_logic                       := '1' ;
    signal tx_enable            :   std_logic                       := '0' ;

    signal rx_i                 :   signed(15 downto 0)             := (others =>'0') ;
    signal rx_q                 :   signed(15 downto 0)             := (others =>'0') ;
    signal rx_valid             :   std_logic                       := '0' ;

    signal tx_fifo_usedw        :   std_logic_vector(11 downto 0)   := x"000";
    signal tx_fifo_read         :   std_logic                       := '1';
    signal tx_fifo_empty        :   std_logic                       := '0';
    signal tx_fifo_data         :   std_logic_vector(31 downto 0);

    signal rx_fifo_usedw        :   std_logic_vector(11 downto 0 )  := x"000";
    signal rx_fifo_write        :   std_logic ;
    signal rx_fifo_full         :   std_logic                       := '0' ;
    signal rx_fifo_data         :   std_logic_vector(31 downto 0);

    signal gain_inc_req       :   std_logic ;
    signal gain_dec_req       :   std_logic ;
    signal gain_rst_req       :   std_logic ;
    signal gain_ack           :   std_logic ;
    signal gain_nack          :   std_logic ;
    signal gain_lock          :   std_logic ;
    signal gain_max           :   std_logic ;

    constant TEST_FRAME : integer_array_t := (
        16#00070007#,
        16#00020000#,
        16#00000010#,
        16#00000000#,
        16#04030201#,
        16#08070605#,
        16#0C0B0A09#,
        16#100F0E0D#,
        16#12345678#,
        16#00000000#,


        16#00080008#,
        16#00020000#,
        16#00000010#,
        16#00000000#,
        16#04030201#,
        16#08070605#,
        16#0C0B0A09#,
        16#100F0E0D#,
        16#00000000#,
        16#00000000#,

        16#00090009#,
        16#00020000#,
        16#00000010#,
        16#00000000#,
        16#04030201#,
        16#08070605#,
        16#0C0B0A09#,
        16#100F0E0D#,
        16#00000000#,
        16#00000000#
    ) ;

    signal sample   :   wlan_sample_t ;
    signal eq       :   wlan_sample_t ;
    signal fopen    :   std_logic;


    signal tx_packet_control    :   packet_control_t ;
    signal tx_packet_empty      :   std_logic ;
    signal tx_packet_ready      :   std_logic ;

    signal rx_packet_control    :   packet_control_t ;
    signal rx_packet_ready      :   std_logic ;

begin

    rx_packet_ready <= '1' ;
    tx_packet_control.pkt_sop <= '0' ;
    tx_packet_control.pkt_eop <= '0' ;
    tx_packet_control.data_valid <= '0';
    tx_packet_control.data <= ( others => '0' );

    U_sample_loader: entity work.wlan_sample_loader
      port map (
        clock   => clock,
        fopen   => fopen,
        sample  => sample
      );

    -- Actual 40MHz clock
    clock <= not clock after 12.5 ns;
    reset <= '1', '0' after 100 ns ;
    fopen <= '0', '1' after 100 ns;

    process(all)
        variable idx : integer := 0;
    begin
        tx_fifo_data <= std_logic_vector(to_unsigned(TEST_FRAME(idx), 32));
        if( rising_edge(clock) ) then
            if( tx_fifo_read = '1' ) then
                idx := idx + 1;
            end if;
        end if;
    end process;

    U_wlan_top : entity work.wlan_top
      port map (
        rx_clock               =>  clock,
        rx_reset               =>  reset,
        rx_enable              =>  rx_enable,

        tx_clock               =>  clock,
        tx_reset               =>  reset,
        tx_enable              =>  tx_enable,

        config_reg             =>  x"00000000",

        packet_en              =>  '1',

        tx_packet_control      =>  tx_packet_control,
        tx_packet_empty        =>  tx_packet_empty,
        tx_packet_ready        =>  tx_packet_ready,

        rx_packet_control      =>  rx_packet_control,
        rx_packet_ready        =>  rx_packet_ready,

        tx_fifo_usedw          =>  tx_fifo_usedw,
        tx_fifo_read           =>  tx_fifo_read,
        tx_fifo_empty          =>  tx_fifo_empty,
        tx_fifo_data           =>  tx_fifo_data,

        rx_fifo_usedw          =>  rx_fifo_usedw,
        rx_fifo_write          =>  rx_fifo_write,
        rx_fifo_full           =>  rx_fifo_full,
        rx_fifo_data           =>  rx_fifo_data,

        gain_inc_req           =>  gain_inc_req,
        gain_dec_req           =>  gain_dec_req,
        gain_rst_req           =>  gain_rst_req,
        gain_ack               =>  gain_ack,
        gain_nack              =>  gain_nack,
        gain_lock              =>  gain_lock,
        gain_max               =>  gain_max,

        tx_ota_req             =>  open,
        tx_ota_ack             =>  '1',

        out_i                  =>  open,
        out_q                  =>  open,
        out_valid              =>  open,

        in_i                   =>  sample.i,
        in_q                   =>  sample.q,
        in_valid               =>  sample.valid

      ) ;

      gain_ack <= '1' ;
      gain_lock <= '0' ;
--    U_agc : entity work.wlan_agc_drv
--      port map (
--        clock   => clock,
--        reset   => reset,
--
--        enable  => '1',
--        gain_inc_req => gain_inc_req,
--        gain_dec_req => gain_dec_req,
--        gain_rst_req => gain_rst_req,
--        gain_ack     => gain_ack,
--        gain_nack    => gain_nack,
--
--        gain_high    => gain_max,
--        gain_mid     => open,
--        gain_low     => open,
--
--        sclk         => open,
--        miso         => '0',
--        mosi         => open,
--        cs_n         => open
--      ) ;
end architecture ;

