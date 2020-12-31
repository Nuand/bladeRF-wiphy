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

entity wlan_encoder is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    params          :   in  wlan_tx_params_t ;
    params_valid    :   in  std_logic ;

    pdu_start       :   in  std_logic ;
    pdu_end         :   in  std_logic ;

    scrambler       :   in  std_logic_vector(7 downto 0) ;
    scrambler_valid :   in  std_logic ;
    scrambler_done  :   in  std_logic ;

    mod_data        :   out std_logic_vector(287 downto 0) ;
    mod_type        :   out wlan_modulation_t ;
    mod_valid       :   out std_logic ;
    mod_end         :   in  std_logic
  ) ;
end entity ;

architecture arch of wlan_encoder is

    -- General scrambled/encoded data

    type fsm_t is (IDLE, ENCODE_SIGNAL, ENCODE_DATA) ;

    type puncture_state_t is (PUNCTURE_AB, PUNCTURE_A, PUNCTURE_B) ;

    type state_t is record
        fsm                 :   fsm_t ;
        mod_type            :   wlan_modulation_t ;
        saved_coded         :   std_logic_vector(5 downto 0) ;
        mod_data            :   std_logic_vector(287 downto 0) ;
        mod_valid           :   std_logic ;
        puncturing_nibble   :   std_logic ;
        extra_byte          :   std_logic ;
        bits_per_symbol     :   natural range 0 to 216 ;
        bits_left           :   natural range 0 to 216 ;
        puncture_state      :   puncture_state_t ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm          := IDLE ;
        rv.mod_type     := WLAN_BPSK ;
        rv.saved_coded  := (others =>'0') ;
        rv.mod_data     := (others =>'0') ;
        rv.mod_valid    := '0' ;
        rv.puncturing_nibble   := '0' ;
        rv.extra_byte   := '0' ;
        rv.bits_per_symbol := 0 ;
        rv.bits_left   := 0 ;
        rv.puncture_state := PUNCTURE_AB ;
        return rv ;
    end function ;

    signal viterbi_init     :   std_logic ;
    signal viterbi_a        :   std_logic_vector(7 downto 0) ;
    signal viterbi_b        :   std_logic_vector(7 downto 0) ;
    signal viterbi_done     :   std_logic ;
    signal viterbi_valid    :   std_logic ;

    signal current, future  :   state_t := NULL_STATE ;

    function puncture_1_2( data : std_logic_vector ; a, b : std_logic_vector ; modulation : wlan_modulation_t ) return std_logic_vector is
        variable rv : std_logic_vector(data'range) := data ;
        variable punctured : std_logic_vector(15 downto 0) ;
    begin
        -- Interleave the values
        for i in 0 to a'high loop
            punctured(2*i)      := a(i) ;
            punctured(2*i+1)    := b(i) ;
        end loop ;
        -- Insert them into the bits
        case modulation is
            when WLAN_BPSK =>
                rv(47 downto 32)  := punctured ;
                rv(31 downto 0)   := data(47 downto 16) ;
            when WLAN_QPSK =>
                rv(95 downto 80)  := punctured ;
                rv(79 downto 0)   := data(95 downto 16) ;
            when WLAN_16QAM =>
                rv(191 downto 176) := punctured ;
                rv(175 downto 0)   := data(191 downto 16) ;
            when WLAN_64QAM =>
                rv(287 downto 272) := punctured ;
                rv(271 downto 0)   := data(287 downto 16) ;
            when others =>
                report "Not good" severity failure ;
        end case ;
        return rv ;
    end function ;

    function puncture_2_3( data : std_logic_vector ; a, b : std_logic_vector ; modulation : wlan_modulation_t ) return std_logic_vector is
        variable rv : std_logic_vector(data'range) := data ;
        variable punctured : std_logic_vector(11 downto 0) ;
    begin
        -- 2/3 puncturing pattern
        punctured(0)  := a(0) ;
        punctured(1)  := b(0) ;
        punctured(2)  := a(1) ;
        punctured(3)  := a(2) ;
        punctured(4)  := b(2) ;
        punctured(5)  := a(3) ;
        punctured(6)  := a(4) ;
        punctured(7)  := b(4) ;
        punctured(8)  := a(5) ;
        punctured(9)  := a(6) ;
        punctured(10) := b(6) ;
        punctured(11) := a(7) ;
        case modulation is
            when WLAN_BPSK =>
                rv(47 downto 36)  := punctured ;
                rv(35 downto 0)   := data(47 downto 12) ;
            when WLAN_QPSK =>
                rv(95 downto 84)  := punctured ;
                rv(83 downto 0)   := data(95 downto 12) ;
            when WLAN_16QAM =>
                rv(191 downto 180) := punctured ;
                rv(179 downto 0)   := data(191 downto 12) ;
            when WLAN_64QAM =>
                rv(287 downto 276) := punctured ;
                rv(275 downto 0)   := data(287 downto 12) ;
            when others =>
                report "Not good again" severity failure ;
        end case ;
        return rv ;
    end function ;

    function puncture_3_4_ab( data : std_logic_vector ; a, b : std_logic_vector ; modulation : wlan_modulation_t ) return std_logic_vector is
        variable rv : std_logic_vector(data'range) := data ;
        variable punctured : std_logic_vector(10 downto 0) ;
    begin
        punctured(0)  := a(0) ;
        punctured(1)  := b(0) ;
        punctured(2)  := a(1) ;
        punctured(3)  := b(2) ;
        punctured(4)  := a(3) ;
        punctured(5)  := b(3) ;
        punctured(6)  := a(4) ;
        punctured(7)  := b(5) ;
        punctured(8)  := a(6) ;
        punctured(9)  := b(6) ;
        punctured(10) := a(7) ;
        case modulation is
            when WLAN_BPSK =>
                rv(47 downto 37)  := punctured ;
                rv(36 downto 0)   := data(47 downto 11) ;
            when WLAN_QPSK =>
                rv(95 downto 85)  := punctured ;
                rv(84 downto 0)   := data(95 downto 11) ;
            when WLAN_16QAM =>
                rv(191 downto 181) := punctured ;
                rv(180 downto 0)   := data(191 downto 11) ;
            when WLAN_64QAM =>
                rv(287 downto 277) := punctured ;
                rv(276 downto 0)   := data(287 downto 11) ;
            when others =>
                report "Ugh, again" severity failure ;
        end case ;
        return rv ;
    end function ;

    function puncture_3_4_a( data : std_logic_vector ; a, b : std_logic_vector ; modulation : wlan_modulation_t ) return std_logic_vector is
        variable rv : std_logic_vector(data'range) := data ;
        variable punctured : std_logic_vector(9 downto 0) ;
    begin
        punctured(0) := a(0) ;
        punctured(1) := b(1) ;
        punctured(2) := a(2) ;
        punctured(3) := b(2) ;
        punctured(4) := a(3) ;
        punctured(5) := b(4) ;
        punctured(6) := a(5) ;
        punctured(7) := b(5) ;
        punctured(8) := a(6) ;
        punctured(9) := b(7) ;
        case modulation is
            when WLAN_BPSK =>
                rv(47 downto 38)  := punctured ;
                rv(37 downto 0)   := data(47 downto 10) ;
            when WLAN_QPSK =>
                rv(95 downto 86)  := punctured ;
                rv(85 downto 0)   := data(95 downto 10) ;
            when WLAN_16QAM =>
                rv(191 downto 182) := punctured ;
                rv(181 downto 0)   := data(191 downto 10) ;
            when WLAN_64QAM =>
                rv(287 downto 278) := punctured ;
                rv(277 downto 0)   := data(287 downto 10) ;
            when others =>
                report "Ugh, again" severity failure ;
        end case ;
        return rv ;
    end function ;

    function puncture_3_4_b( data : std_logic_vector ; a, b : std_logic_vector ; modulation : wlan_modulation_t ) return std_logic_vector is
        variable rv : std_logic_vector(data'range) := data ;
        variable punctured : std_logic_vector(10 downto 0) ;
    begin
        punctured(0)  := b(0) ;
        punctured(1)  := a(1) ;
        punctured(2)  := b(1) ;
        punctured(3)  := a(2) ;
        punctured(4)  := b(3) ;
        punctured(5)  := a(4) ;
        punctured(6)  := b(4) ;
        punctured(7)  := a(5) ;
        punctured(8)  := b(6) ;
        punctured(9)  := a(7) ;
        punctured(10) := b(7) ;
        case modulation is
            when WLAN_BPSK =>
                rv(47 downto 37)  := punctured ;
                rv(36 downto 0)   := data(47 downto 11) ;
            when WLAN_QPSK =>
                rv(95 downto 85)  := punctured ;
                rv(84 downto 0)   := data(95 downto 11) ;
            when WLAN_16QAM =>
                rv(191 downto 181) := punctured ;
                rv(180 downto 0)   := data(191 downto 11) ;
            when WLAN_64QAM =>
                rv(287 downto 277) := punctured ;
                rv(276 downto 0)   := data(287 downto 11) ;
            when others =>
                report "Ugh, again" severity failure ;
        end case ;
        return rv ;
    end function ;

    function reverse(x : std_logic_vector) return std_logic_vector is
        variable rv : std_logic_vector(x'range) ;
    begin
        for i in x'range loop
            rv(x'high-i) := x(i) ;
        end loop ;
        return rv ;
    end function ;

    signal data_reversed : std_logic_vector(mod_data'range) ;


begin

    mod_type <= current.mod_type ;
    mod_data <= current.mod_data ;
    mod_valid <= current.mod_valid ;

    data_reversed <= reverse(current.mod_data) ;

    U_viterbi_encoder : entity work.wlan_viterbi_encoder
      generic map (
        WIDTH       =>  scrambler'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  params_valid,

        in_data     =>  scrambler,
        in_valid    =>  scrambler_valid,
        in_done     =>  scrambler_done,

        out_a       =>  viterbi_a,
        out_b       =>  viterbi_b,
        out_done    =>  viterbi_done,
        out_valid   =>  viterbi_valid
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
        variable  tmp_data        :   std_logic_vector(287 downto 0) ;
    begin
        future <= current ;
        future.mod_valid <= '0' ;
        case current.fsm is
            when IDLE =>
                future.mod_data <= ( others => '0' );
                if( params_valid = '1' ) then
                    future.fsm <= ENCODE_SIGNAL ;
                    future.mod_type <= WLAN_BPSK ;
                    future.bits_left <= 24-8 ;
                    future.bits_per_symbol <= params.n_dbps ;
                    future.puncture_state <= PUNCTURE_AB ;
                    if( params.datarate = WLAN_RATE_9) then
                        future.saved_coded  <= ( others => '0' ) ;
                        future.puncturing_nibble <= '1' ;
                        future.extra_byte <= '1' ;
                    else
                        future.puncturing_nibble <= '0' ;
                    end if ;
                end if ;

            when ENCODE_SIGNAL =>
                -- Encode 24 bits at R=1/2 with BPSK modulation, no scrambling
                if( viterbi_valid = '1' ) then
                    future.mod_data <= puncture_1_2( current.mod_data, viterbi_a, viterbi_b, WLAN_BPSK ) ;
                    if( current.bits_left = 0 ) then
                        future.mod_valid <= '1' ;
                        future.fsm <= ENCODE_DATA ;
                        future.extra_byte <= '1' ;
                        if( current.puncturing_nibble = '1' and current.extra_byte = '1' ) then
                           future.bits_left <= current.bits_per_symbol ;
                        else
                           future.bits_left <= current.bits_per_symbol - 8 ;
                        end if ;
                    else
                        future.bits_left <= current.bits_left - 8 ;
                    end if ;
                end if ;

            when ENCODE_DATA =>
                future.mod_type <= params.modulation ;
                if( viterbi_valid = '1' ) then
                    case params.datarate is

                        when WLAN_RATE_6|WLAN_RATE_12|WLAN_RATE_24 =>
                            -- R=1/2
                            future.mod_data <= puncture_1_2(current.mod_data, viterbi_a, viterbi_b, params.modulation) ;

                        when WLAN_RATE_9 =>
                            case current.puncture_state is
                                when PUNCTURE_AB =>
                                    tmp_data := puncture_3_4_ab(current.mod_data, viterbi_a, viterbi_b, WLAN_QPSK) ;
                                    future.puncture_state <= PUNCTURE_B ;
                                when PUNCTURE_A =>
                                    tmp_data := puncture_3_4_a(current.mod_data, viterbi_a, viterbi_b, WLAN_QPSK) ;
                                    future.puncture_state <= PUNCTURE_AB ;
                                when PUNCTURE_B =>
                                    tmp_data := puncture_3_4_b(current.mod_data, viterbi_a, viterbi_b, WLAN_QPSK) ;
                                    future.puncture_state <= PUNCTURE_A ;
                                when others =>
                                    report "Ahfkjhf" severity failure ;
                            end case ;
                            if( current.bits_left = 4) then
                                future.mod_valid <= '1' ;
                                -- at the last byte of stuff

                                if( current.extra_byte = '1' ) then
                                    -- getting extra byte, so save it
                                    -- made 54 bits, save top 6, send 48 bits
                                    future.mod_data(47 downto 0) <= tmp_data(89 downto 42);
                                    future.saved_coded <= tmp_data(95 downto 90);
                                else
                                    -- made 42 bits
                                    future.mod_data(47 downto 0) <= tmp_data(95 downto 54) & current.saved_coded;
                                end if ;
                            else
                                future.mod_data <= tmp_data ;
                            end if ;

                        when WLAN_RATE_18|WLAN_RATE_36|WLAN_RATE_54 =>
                            -- R=3/4
                            case current.puncture_state is
                                when PUNCTURE_AB =>
                                    future.mod_data <= puncture_3_4_ab(current.mod_data, viterbi_a, viterbi_b, params.modulation) ;
                                    future.puncture_state <= PUNCTURE_B ;
                                when PUNCTURE_A =>
                                    future.mod_data <= puncture_3_4_a(current.mod_data, viterbi_a, viterbi_b, params.modulation) ;
                                    future.puncture_state <= PUNCTURE_AB ;
                                when PUNCTURE_B =>
                                    future.mod_data <= puncture_3_4_b(current.mod_data, viterbi_a, viterbi_b, params.modulation) ;
                                    future.puncture_state <= PUNCTURE_A ;
                                when others =>
                                    report "Ahfkjhf" severity failure ;
                            end case ;

                        when WLAN_RATE_48 =>
                            -- R=2/3
                            future.mod_data <= puncture_2_3(current.mod_data, viterbi_a, viterbi_b, params.modulation) ;
                        when others         =>
                            report "Foff" severity failure ;
                    end case ;
                    if( current.bits_left = 0  or current.bits_left = 4) then
                        future.mod_valid <= '1' ;
                        if( current.puncturing_nibble = '1')  then
                            if( current.extra_byte = '1' ) then
                                future.bits_left <= current.bits_per_symbol - 8 ;
                            else
                                future.bits_left <= current.bits_per_symbol ;
                            end if ;
                            future.extra_byte <= not current.extra_byte ;
                        else
                            future.bits_left <= current.bits_per_symbol - 8 ;
                        end if;
                        if( viterbi_done = '1' ) then
                            future.fsm <= IDLE ;
                        end if ;
                    else
                        if( current.bits_left = 4 ) then
                            -- BPSK R=3/4 here
                            future.bits_left <= 0 ;
                        else
                            future.bits_left <= current.bits_left - 8 ;
                        end if ;
                    end if ;
                end if ;

        end case ;
    end process ;

end architecture ;

