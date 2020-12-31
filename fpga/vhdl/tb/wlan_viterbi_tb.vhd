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
    use wlan.wlan_rx_p.all ;

library viterbi_decoder ;

entity wlan_viterbi_tb is
end entity ;

architecture arch of wlan_viterbi_tb is

    signal clock        :   std_logic                       := '1' ;
    signal reset        :   std_logic                       := '1' ;

    signal lfsr_init    :   std_logic                       := '0' ;
    signal lfsr_advance :   std_logic                       := '0' ;
    signal lfsr_data    :   std_logic_vector(0 downto 0) ;
    signal lfsr_valid   :   std_logic ;

    signal in_bit       :   std_logic_vector(0 downto 0)    := (others =>'0') ;
    signal in_done      :   std_logic                       := '0' ;
    signal in_valid     :   std_logic                       := '0' ;

    signal enc_init     :   std_logic                       := '0' ;
    signal enc_a        :   std_logic_vector(0 downto 0) ;
    signal enc_b        :   std_logic_vector(0 downto 0) ;
    signal enc_done     :   std_logic ;
    signal enc_valid    :   std_logic ;

    signal soft_a       :   signed(7 downto 0) ;
    signal soft_b       :   signed(7 downto 0) ;
    signal soft_valid   :   std_logic ;

    signal dec_bit      :   std_logic ;
    signal dec_valid    :   std_logic ;

    signal verify_prime     :   std_logic ;
    signal verify_advance   :   std_logic ;
    signal verify_data      :   std_logic_vector(0 downto 0) ;
    signal verify_valid     :   std_logic ;

    procedure nop( signal clock : in std_logic ; count : natural ) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clock) ;
        end loop ;
    end procedure ;

    constant LFSR_INIT_VAL : unsigned(6 downto 0) := "0101010" ;

    signal params       :   wlan_rx_params_t := NULL_PARAMS ;
    signal params_valid :   std_logic := '0' ;

begin

    clock <= not clock after 1 ns ;

    U_lfsr : entity wlan.wlan_lfsr
      generic map (
        WIDTH           =>  1
      ) port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  LFSR_INIT_VAL,
        init_valid      =>  lfsr_init,

        advance         =>  lfsr_advance,

        data            =>  lfsr_data,
        data_valid      =>  lfsr_valid
      ) ;

    in_bit <= lfsr_data ;
    in_valid <= lfsr_valid ;

    U_encoder : entity wlan.wlan_viterbi_encoder
      generic map (
        WIDTH   =>  1
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  enc_init,

        in_data     =>  in_bit,
        in_valid    =>  in_valid,
        in_done     =>  in_done,

        out_a       =>  enc_a,
        out_b       =>  enc_b,
        out_done    =>  enc_done,
        out_valid   =>  enc_valid
      ) ;

    U_decoder : entity wlan.wlan_viterbi_decoder
      port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  '0',

        in_soft_a       =>  soft_a,
        in_soft_b       =>  soft_b,
        in_erasure      =>  "00",
        in_valid        =>  soft_valid,

        params          =>  params,
        params_valid    =>  params_valid,

        out_dec_bit     =>  dec_bit,
        out_dec_valid   =>  dec_valid
      ) ;

    soft_a <= to_signed(15,soft_a'length) when enc_a(0) = '0' else to_signed(-15,soft_a'length) ;
    soft_b <= to_signed(15,soft_b'length) when enc_b(0) = '0' else to_signed(-15,soft_b'length) ;
    soft_valid <= enc_valid ;

    tb : process
    begin
        reset <= '1' ;
        nop( clock, 100 ) ;

        reset <= '0' ;
        nop( clock, 100 ) ;

        enc_init <= '1' ;
        lfsr_init <= '1' ;
        nop( clock, 1 ) ;
        enc_init <= '0' ;
        lfsr_init <= '0' ;
        nop( clock, 10 ) ;
        params.num_decoded_bits <= 10000 ;
        params_valid <= '1' ;
        nop( clock, 1 ) ;
        params_valid <= '0' ;
        nop( clock, 100 ) ;

        for i in 1 to 10000 loop
            lfsr_advance <= '1' ;
            wait until rising_edge(clock) ;
        end loop ;
        nop( clock, 10000 ) ;

        report "-- End of Simulation --" severity failure ;
    end process ;

    U_verify : entity wlan.wlan_lfsr
      generic map (
        WIDTH           =>  1
      ) port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  LFSR_INIT_VAL,
        init_valid      =>  lfsr_init,

        advance         =>  verify_advance,
        data            =>  verify_data,
        data_valid      =>  verify_valid
      ) ;

    verify_advance <= dec_valid or verify_prime ;

    verify : process
    begin
        verify_prime <= '0' ;
        wait until rising_edge(clock) and lfsr_init = '1' ;
        nop( clock, 10 ) ;
        verify_prime <= '1' ;
        nop( clock, 1 ) ;
        verify_prime <= '0' ;

        while true loop
            wait until rising_edge(clock) and dec_valid = '1' ;
            assert (dec_bit = verify_data(0))
                report "Verification mismatch"
                severity error ;
        end loop ;
    end process ;

end architecture ;
