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
    use work.wlan_tx_p.all ;

entity wlan_tx is
  port (
    -- 40MHz clock rate with async assert/sync deassert reset signal
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    -- Control word structure
    tx_vector       :   in  wlan_tx_vector_t ;
    tx_vector_valid :   in  std_logic ;

    -- Status signal
    tx_status       :   out wlan_tx_status_t ;
    tx_status_valid :   out std_logic ;

    -- Data FIFO interface
    fifo_re         :   out std_logic ;
    fifo_data       :   in  std_logic_vector(7 downto 0) ;
    fifo_empty      :   in  std_logic ;

    -- Baseband output signals
    bb              :   out wlan_sample_t ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_tx is

    -- Controller signals
    signal params               :   wlan_tx_params_t ;
    signal params_valid         :   std_logic ;
    signal status               :   wlan_tx_status_t ;
    signal status_valid         :   std_logic ;

    -- Framer
    signal framer_data          :   std_logic_vector(7 downto 0) ;
    signal framer_valid         :   std_logic ;
    signal framer_done          :   std_logic ;

    -- Scrambler
    signal scrambler_data       :   std_logic_vector(7 downto 0) ;
    signal scrambler_valid      :   std_logic ;
    signal scrambler_done       :   std_logic ;

    -- Encoder signals
    signal encoder_start        :   std_logic ;
    signal encoder_done         :   std_logic ;

    -- Short sequence data
    signal short                :   wlan_sample_t ;
    signal short_start          :   std_logic ;
    signal short_done           :   std_logic ;

    -- Long sequence data
    signal long                 :   wlan_sample_t ;
    signal long_valid_cp        :   std_logic ;
    signal long_start           :   std_logic ;
    signal long_done            :   std_logic ;

    -- Interlever
    signal interleaver_mod      :   wlan_modulation_t ;
    signal interleaver_data     :   std_logic_vector(287 downto 0) ;
    signal interleaver_valid    :   std_logic ;

    -- Modulated signal
    signal mod_init             :   std_logic ;
    signal mod_data             :   std_logic_vector(287 downto 0) ;
    signal mod_type             :   wlan_modulation_t ;
    signal mod_valid            :   std_logic ;
    signal mod_sample           :   wlan_sample_t ;
    signal mod_start            :   std_logic ;
    signal mod_end              :   std_logic ;

    -- IFFT signal
    signal ifft_sample          :   wlan_sample_t ;
    signal ifft_valid_cp        :   std_logic ;
    signal ifft_ready           :   std_logic ;

    -- Cyclic Prefix signal
    signal cp_i                 :   signed(15 downto 0) ;
    signal cp_q                 :   signed(15 downto 0) ;
    signal cp_re                :   std_logic ;
    signal cp_empty             :   std_logic ;

    -- Sample signal
    signal sample_i             :   signed(15 downto 0) ;
    signal sample_q             :   signed(15 downto 0) ;
    signal sample_re            :   std_logic ;
    signal sample_empty         :   std_logic ;
    signal sample_ready         :   std_logic ;

    signal buffer_room          :   std_logic ;

    -- Time series signal
    signal out_sample           :   wlan_sample_t ;

    -- End status signal
    signal tx_done              :   std_logic ;

    signal ifft_done            :   std_logic ;

begin

    -- Configure TX based on TX vector
    U_tx_controller : entity work.wlan_tx_controller
      port map (
        clock           =>  clock,
        reset           =>  reset,

        tx_vector       =>  tx_vector,
        tx_vector_valid =>  tx_vector_valid,

        params          =>  params,
        params_valid    =>  params_valid,

        status          =>  status,
        status_valid    =>  status_valid,

        short_start     =>  short_start,
        short_done      =>  short_done,

        long_done       =>  long_done,

        encoder_start   =>  encoder_start,
        encoder_done    =>  encoder_done,

        mod_init        =>  mod_init,
        mod_end         =>  mod_end,

        tx_done         =>  tx_done
      ) ;

    U_framer : entity work.wlan_framer
      port map (
        clock           =>  clock,
        reset           =>  reset,

        params          =>  params,
        params_valid    =>  params_valid,

        encoder_start   =>  encoder_start,

        buffer_room     =>  buffer_room,

        fifo_data       =>  fifo_data,
        fifo_empty      =>  fifo_empty,
        fifo_re         =>  fifo_re,

        mod_done        =>  mod_end,

        out_data        =>  framer_data,
        out_valid       =>  framer_valid,
        done            =>  framer_done
      ) ;

    U_scrambler : entity work.wlan_scrambler
      port map (
        clock           =>  clock,
        reset           =>  reset,

        params          =>  params,
        params_valid    =>  params_valid,

        in_data         =>  framer_data,
        in_valid        =>  framer_valid,
        in_done         =>  framer_done,

        out_data        =>  scrambler_data,
        out_valid       =>  scrambler_valid,
        done            =>  scrambler_done
      ) ;

    U_encoder : entity work.wlan_encoder
      port map (
        clock           =>  clock,
        reset           =>  reset,

        params          =>  params,
        params_valid    =>  params_valid,

        pdu_start       =>  encoder_start,
        pdu_end         =>  encoder_done,

        scrambler       =>  scrambler_data,
        scrambler_valid =>  scrambler_valid,
        scrambler_done  =>  scrambler_done,

        mod_data        =>  mod_data,
        mod_type        =>  mod_type,
        mod_valid       =>  mod_valid,
        mod_end         =>  mod_end
      ) ;

    -- Interleaver
    U_interleaver : entity work.wlan_interleaver
      port map (
        clock               =>  clock,
        reset               =>  reset,

        modulation          =>  mod_type,
        data                =>  mod_data,
        in_valid            =>  mod_valid,

        interleaved         =>  interleaver_data,
        interleaved_mod     =>  interleaver_mod,
        interleaved_valid   =>  interleaver_valid
      ) ;

    -- Modulation
    U_modulator : entity work.wlan_modulator
      port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  mod_init,
        data            =>  interleaver_data,
        modulation      =>  interleaver_mod,
        in_valid        =>  interleaver_valid,

        ifft_ready      =>  ifft_ready,

        symbol_start    =>  mod_start,
        symbol_end      =>  mod_end,
        symbol_sample   =>  mod_sample
      ) ;

    -- IFFT
    U_ifft64 : entity work.wlan_ifft64
      port map (
        clock           =>  clock,
        reset           =>  reset,
        symbol_start    =>  mod_start,
        symbol_end      =>  mod_end,
        in_sample       =>  mod_sample,
        out_sample      =>  ifft_sample,
        out_valid_cp    =>  ifft_valid_cp,
        ifft_ready      =>  ifft_ready,
        done            =>  ifft_done
      ) ;

    -- Short sequence insertion
    U_short_sequence : entity work.wlan_tx_short
      port map (
        clock           =>  clock,
        reset           =>  reset,
        start           =>  short_start,
        done            =>  short_done,
        out_sample      =>  short
      ) ;

    -- Long sequence insertion
    long_start <= short_done ;
    U_long_sequence : entity work.wlan_tx_long
      port map (
        clock           =>  clock,
        reset           =>  reset,
        start           =>  long_start,
        done            =>  long_done,
        out_sample      =>  long,
        out_valid_cp    =>  long_valid_cp
      ) ;

    -- CP buffer (16 samples at a time)
    U_cp_buffer : entity work.wlan_sample_buffer
      port map (
        clock           =>  clock,
        reset           =>  reset or tx_vector_valid,
        short           =>  NULL_SAMPLE,
        long            =>  (long.i, long.q, long_valid_cp),
        symbol          =>  (ifft_sample.i, ifft_sample.q, ifft_valid_cp),
        sample_i        =>  cp_i,
        sample_q        =>  cp_q,
        sample_re       =>  cp_re,
        sample_empty    =>  cp_empty
      ) ;

    -- Symbol buffer (64 samples at a time)
    U_symbol_buffer : entity work.wlan_sample_buffer
      port map (
        clock           =>  clock,
        reset           =>  reset or tx_vector_valid,
        room            =>  buffer_room,
        short           =>  short,
        long            =>  long,
        symbol          =>  ifft_sample,
        sample_i        =>  sample_i,
        sample_q        =>  sample_q,
        sample_re       =>  sample_re,
        sample_empty    =>  sample_empty
      ) ;

    -- Apply temporal window and send out the door
    U_symbol_shaper : entity work.wlan_symbol_shaper
      port map (
        clock           =>  clock,
        reset           =>  reset,
        cp_i            =>  cp_i,
        cp_q            =>  cp_q,
        cp_re           =>  cp_re,
        cp_empty        =>  cp_empty,
        sample_i        =>  sample_i,
        sample_q        =>  sample_q,
        sample_re       =>  sample_re,
        sample_empty    =>  sample_empty,
        out_sample      =>  out_sample,
        done            =>  tx_done
      ) ;

    -- Register the output
    bb <= out_sample when rising_edge(clock) ;
    done <= tx_done when rising_edge(clock) ;

end architecture ;

