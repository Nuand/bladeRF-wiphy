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

library work ;
    use work.wlan_p.all ;

entity wlan_modulator is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    init            :   in  std_logic ;

    data            :   in  std_logic_vector(287 downto 0) ;
    modulation      :   in  wlan_modulation_t ;
    in_valid        :   in  std_logic ;

    ifft_ready      :   in  std_logic ;

    symbol_start    :   out std_logic ;
    symbol_end      :   out std_logic ;
    symbol_sample   :   out wlan_sample_t
  ) ;
end entity ;

architecture arch of wlan_modulator is

    function to_sample( x : complex ) return wlan_sample_t is
        variable rv : wlan_sample_t ;
    begin
        rv.i := to_signed(integer(round(4096.0*x.re)), rv.i'length) ;
        rv.q := to_signed(integer(round(4096.0*x.im)), rv.q'length) ;
        rv.valid := '1' ;
        return rv ;
    end function ;

    -- Table 18-8
    function make_bpsk_table return sample_array_t is
        variable rv : sample_array_t(1 downto 0) ;
    begin
        rv(0) := to_sample( (-1.0,  0.0) ) ;
        rv(1) := to_sample( ( 1.0,  0.0) ) ;
        return rv ;
    end function ;

    -- Table 18-9
    function make_qpsk_table return sample_array_t is
        constant SCALE  :   real := 1.0/sqrt(2.0) ;
        variable rv     :   sample_array_t(3 downto 0) ;
    begin
        rv(0) := to_sample( (SCALE*(-1.0), SCALE*(-1.0)) ) ;
        rv(1) := to_sample( (SCALE*( 1.0), SCALE*(-1.0)) ) ;
        rv(2) := to_sample( (SCALE*(-1.0), SCALE*( 1.0)) ) ;
        rv(3) := to_sample( (SCALE*( 1.0), SCALE*( 1.0)) ) ;
        return rv ;
    end function ;

    -- Table 18-10
    function make_16qam_table return sample_array_t is
        constant SCALE  :   real := 1.0/sqrt(10.0) ;
        variable bits   :   unsigned(3 downto 0) ;
        variable sample :   complex ;
        variable rv     :   sample_array_t(15 downto 0) ;
    begin
        for i in rv'range loop
            bits := to_unsigned(i,bits'length) ;
            -- I bits
            case bits(1 downto 0) is
                when "00" => sample.re := SCALE*(-3.0) ;
                when "01" => sample.re := SCALE*( 3.0) ;
                when "10" => sample.re := SCALE*(-1.0) ;
                when "11" => sample.re := SCALE*( 1.0) ;
                when others => report "Weird" severity failure ;
            end case ;

            -- Q bits
            case bits(3 downto 2) is
                when "00" => sample.im := SCALE*(-3.0) ;
                when "01" => sample.im := SCALE*( 3.0) ;
                when "10" => sample.im := SCALE*(-1.0) ;
                when "11" => sample.im := SCALE*( 1.0) ;
                when others => report "Ack" severity failure ;
            end case ;
            rv(i) := to_sample( sample ) ;
        end loop ;
        return rv ;
    end function ;

    -- Table 18-11
    function make_64qam_table return sample_array_t is
        constant SCALE  :   real := 1.0/sqrt(42.0) ;
        variable bits   :   unsigned(5 downto 0) ;
        variable sample :   complex ;
        variable rv     :   sample_array_t(63 downto 0) ;
    begin
        for i in rv'range loop
            bits := to_unsigned(i, bits'length) ;

            -- I bits
            case bits(2 downto 0) is
                when "000" => sample.re := SCALE*(-7.0) ;
                when "001" => sample.re := SCALE*( 7.0) ;
                when "010" => sample.re := SCALE*(-1.0) ;
                when "011" => sample.re := SCALE*( 1.0) ;
                when "100" => sample.re := SCALE*(-5.0) ;
                when "101" => sample.re := SCALE*( 5.0) ;
                when "110" => sample.re := SCALE*(-3.0) ;
                when "111" => sample.re := SCALE*( 3.0) ;
                when others => report "Ugh!" severity failure ;
            end case ;

            -- Q bits
            case bits(5 downto 3) is
                when "000" => sample.im := SCALE*(-7.0) ;
                when "001" => sample.im := SCALE*( 7.0) ;
                when "010" => sample.im := SCALE*(-1.0) ;
                when "011" => sample.im := SCALE*( 1.0) ;
                when "100" => sample.im := SCALE*(-5.0) ;
                when "101" => sample.im := SCALE*( 5.0) ;
                when "110" => sample.im := SCALE*(-3.0) ;
                when "111" => sample.im := SCALE*( 3.0) ;
                when others => report "Blah" severity failure ;
            end case ;
            rv(i) := to_sample( sample ) ;
        end loop ;
        return rv ;
    end function ;

    -- Modulation tables
    constant MOD_BPSK       :   sample_array_t  := make_bpsk_table ;
    constant MOD_QPSK       :   sample_array_t  := make_qpsk_table ;
    constant MOD_16QAM      :   sample_array_t  := make_16qam_table ;
    constant MOD_64QAM      :   sample_array_t  := make_64qam_table ;

    type fsm_t is (IDLE, WAIT_IFFT_READY, MODULATING) ;

    type state_t is record
        fsm             :   fsm_t ;
        data            :   unsigned(287 downto 0) ;
        byt             :   natural range 0 to 630 ;
        index           :   natural range 0 to 63 ;
        modulation      :   wlan_modulation_t ;
        symbol          :   wlan_sample_t ;
        symbol_start    :   std_logic ;
        symbol_end      :   std_logic ;
        pilot_polarity  :   std_logic ;
        lfsr_advance    :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.data := (others =>'0') ;
        rv.byt := 0 ;
        rv.index := 0 ;
        rv.modulation := WLAN_BPSK ;
        rv.symbol := NULL_SAMPLE ;
        rv.symbol_start := '0' ;
        rv.symbol_end := '0' ;
        rv.pilot_polarity := '1' ;
        rv.lfsr_advance := '0' ;
        return rv ;
    end function ;

    function reorder_data( x : std_logic_vector(287 downto 0) ; modulation : wlan_modulation_t ) return unsigned is
        variable rv     : std_logic_vector(287 downto 0) ;
    begin
        -- Swap locations of positive and negative frequencies in the vector
        case modulation is
            when WLAN_BPSK =>
                rv(24*1-1 downto 0)     := x(48*1-1 downto 24*1) ;
                rv(48*1-1 downto 24*1)  := x(24*1-1 downto 0) ;
            when WLAN_QPSK =>
                rv(24*2-1 downto 0)     := x(48*2-1 downto 24*2) ;
                rv(48*2-1 downto 24*2)  := x(24*2-1 downto 0) ;
            when WLAN_16QAM =>
                rv(24*4-1 downto 0)     := x(48*4-1 downto 24*4) ;
                rv(48*4-1 downto 24*4)  := x(24*4-1 downto 0) ;
            when WLAN_64QAM =>
                rv(24*6-1 downto 0)     := x(48*6-1 downto 24*6) ;
                rv(48*6-1 downto 24*6)  := x(24*6-1 downto 0) ;
            when others =>
        end case ;
        return unsigned(rv) ;
    end function ;

    signal lfsr_advance     :   std_logic ;
    signal lfsr_data        :   std_logic_vector(0 downto 0) ;

    signal current, future  :   state_t := NULL_STATE ;

begin

    symbol_start    <= current.symbol_start ;
    symbol_end      <= current.symbol_end ;
    symbol_sample   <= current.symbol ;

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
        future <= current ;
        future.lfsr_advance <= '0' ;
        future.symbol.valid <= '0' ;
        future.symbol_start <= '0' ;
        future.symbol_end <= '0' ;
        future.pilot_polarity <= lfsr_data(0) ;
        case current.fsm is
            when IDLE =>
                future.symbol <= NULL_SAMPLE ;
                future.symbol_start <= '0' ;
                future.symbol_end <= '0' ;
                if( init = '1' ) then
                    -- Reset the pilot polarity LFSR here
                end if ;
                if( in_valid = '1' ) then
                    future.modulation <= modulation ;
                    future.data <= reorder_data(data, modulation) ;
                    if( ifft_ready = '1' ) then
                       future.fsm <= MODULATING ;
                    else
                       future.fsm <= WAIT_IFFT_READY ;
                    end if;
                end if ;

            when WAIT_IFFT_READY =>
                if( ifft_ready = '1' ) then
                   future.fsm <= MODULATING ;
                end if;
                
            when MODULATING =>
                future.symbol_start <= '0' ;
                future.symbol_end <= '0' ;

                case current.index is
                    -- Check for DC null
                    when 0 =>
                        future.symbol <= NULL_SAMPLE ;
                        future.symbol.valid <= '1' ;
                        future.symbol_start <= '1' ;

                    -- Check for outside nulls
                    when 27 to 37 =>
                        future.symbol <= NULL_SAMPLE ;
                        future.symbol.valid <= '1' ;

                    -- Check for 3 positive pilots
                    when 7|43|57 =>
                        if( current.pilot_polarity = '1' ) then
                            future.symbol <= MOD_BPSK(0) ;
                        else
                            future.symbol <= MOD_BPSK(1) ;
                        end if ;

                    -- Check for 1 negative pilot
                    when 21 =>
                        if( current.pilot_polarity = '1' ) then
                            future.symbol <= MOD_BPSK(1) ;
                        else
                            future.symbol <= MOD_BPSK(0) ;
                        end if ;

                    -- Otherwise data
                    when others =>
                        case current.modulation is
                            when WLAN_BPSK =>
                                future.symbol <= MOD_BPSK(to_integer(current.data(0 downto 0))) ;
                                future.data <= shift_right(current.data,1) ;
                            when WLAN_QPSK =>
                                future.symbol <= MOD_QPSK(to_integer(current.data(1 downto 0))) ;
                                future.data <= shift_right(current.data,2) ;
                            when WLAN_16QAM =>
                                future.symbol <= MOD_16QAM(to_integer(current.data(3 downto 0))) ;
                                future.data <= shift_right(current.data,4) ;
                            when WLAN_64QAM =>
                                future.symbol <= MOD_64QAM(to_integer(current.data(5 downto 0))) ;
                                future.data <= shift_right(current.data,6) ;
                            when others =>
                        end case ;

                end case ;

                -- Check if we've reached a full symbol length
                if( current.index < 63 ) then
                    future.index <= current.index + 1 ;
                else
                    future.lfsr_advance <= '1' ;
                    future.symbol_end <= '1' ;
                    future.byt <= current.byt + 1;
                    future.index <= 0 ;
                    future.fsm <= IDLE ;
                end if ;
        end case ;
    end process ;

end architecture ;

