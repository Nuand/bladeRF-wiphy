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

library work ;
    use work.wlan_p.all ;
    use work.wlan_tx_p.all ;

entity wlan_framer is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    params          :   in  wlan_tx_params_t ;
    params_valid    :   in  std_logic ;

    encoder_start   :   in  std_logic ;

    fifo_data       :   in  std_logic_vector(7 downto 0) ;
    fifo_empty      :   in  std_logic ;
    fifo_re         :   out std_logic ;

    buffer_room     :   in  std_logic ;

    mod_done        :   in  std_logic ;

    out_data        :   out std_logic_vector(7 downto 0) ;
    out_valid       :   out std_logic ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_framer is

    type fsm_t is (IDLE, FRAME_SIGNAL, WAIT_FOR_SIGNAL_MODULATED, FRAME_SERVICE, FRAME_DATA, WAIT_ZZ, WAIT_YY, WAIT_FOR_DATA_MODULATED, WAIT_FOR_BUFFER_ROOM) ;

    type signal_field_t is record
        rate    :   unsigned(3 downto 0) ;
        length  :   unsigned(11 downto 0) ;
        parity  :   std_logic ;
    end record ;

    function "xor"(x : std_logic_vector) return std_logic is
        variable rv : std_logic := '0' ;
    begin
        for i in x'range loop
            rv := x(i) xor rv ;
        end loop ;
        return rv ;
    end function ;

    function calculate_parity( x : signal_field_t ) return std_logic is
        constant xx : std_logic_vector(15 downto 0) := std_logic_vector(x.rate & x.length) ;
        constant rv : std_logic := "xor"(xx) ;
    begin
        return rv ;
    end function ;

    type state_t is record
        fsm                 :   fsm_t ;
        signal_field        :   signal_field_t ;
        signal_slv          :   unsigned(23 downto 0) ;
        done                :   std_logic ;
        bytes_left          :   natural range 0 to 4095 ;
        symbol_bytes_left   :   natural range 0 to 27 ;
        puncturing_nibble   :   std_logic ;
        extra_byte          :   std_logic ;
        symbol_bytes        :   natural range 0 to 27 ;
        data                :   std_logic_vector(7 downto 0) ;
        crc_data_valid      :   std_logic ;
        data_valid          :   std_logic ;
        fifo_re             :   std_logic ;
        crc_reset           :   std_logic ;
        crc_mux             :   std_logic ;
        crc_index           :   natural range 0 to 8 ;
        bad_index           :   natural range 0 to 80 ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.signal_field := ( (others =>'0'), (others =>'0'), '0' ) ;
        rv.signal_slv := (others =>'0') ;
        rv.done := '0' ;
        rv.bytes_left :=  0 ;
        rv.puncturing_nibble := '0' ;
        rv.extra_byte := '0' ;
        rv.symbol_bytes := 0 ;
        rv.symbol_bytes_left := 0 ;
        rv.data := (others =>'0') ;
        rv.crc_data_valid := '0' ;
        rv.data_valid := '0' ;
        rv.fifo_re := '0' ;
        rv.crc_reset := '0' ;
        rv.crc_mux   := '0' ;
        rv.crc_index := 0 ;
        rv.bad_index := 0 ;
        return rv ;
    end function ;

    function pack( x : signal_field_t ) return unsigned is
        variable rv : unsigned(23 downto 0) ;
    begin
        rv(3 downto 0)      := x.rate ;
        rv(4)               := '0' ;
        rv(16 downto 5)     := x.length ;
        rv(17)              := x.parity ;
        rv(23 downto 18)    := (others =>'0') ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    signal calculated_crc   :   std_logic_vector( 31 downto 0 ) ;

begin

    fifo_re <= current.fifo_re ;

    out_valid <= current.data_valid ;

    done <= current.done ;

    process(all)
    begin
        if( current.crc_mux = '1' ) then
            case current.crc_index is
              when 0 => out_data <= calculated_crc( 31 downto 24 ) ;
              when 1 => out_data <= calculated_crc( 23 downto 16 ) ;
              when 2 => out_data <= calculated_crc( 15 downto 8 ) ;
              when 3 => out_data <= calculated_crc( 7 downto 0 ) ;
              when others => out_data <= ( others => '0' ) ;
            end case ;
        else
            out_data <= current.data ;
        end if ;
    end process ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process(all)
        variable sf : signal_field_t ;
    begin
        sf := ( (others =>'0'), (others =>'0'), '0' ) ;
        future <= current ;
        future.done <= '0' ;
        future.crc_data_valid <= '0' ;
        future.data_valid <= '0' ;
        future.fifo_re <= '0' ;
        future.crc_reset <= '0' ;
        case current.fsm is

            when IDLE =>
                future.crc_mux <= '0' ;
                if( encoder_start = '1' ) then
                    future.fsm <= FRAME_SIGNAL ;
                    sf.length := to_unsigned( params.length, sf.length'length ) + 4 ;
                    case params.datarate is
                        -- Note table goes R4-R1 instead of R1-R4
                        when WLAN_RATE_6    => sf.rate := "1011" ;
                        when WLAN_RATE_9    => sf.rate := "1111" ;
                        when WLAN_RATE_12   => sf.rate := "1010" ;
                        when WLAN_RATE_18   => sf.rate := "1110" ;
                        when WLAN_RATE_24   => sf.rate := "1001" ;
                        when WLAN_RATE_36   => sf.rate := "1101" ;
                        when WLAN_RATE_48   => sf.rate := "1000" ;
                        when WLAN_RATE_54   => sf.rate := "1100" ;
                        when others         => report "Error in datarate" severity failure ;
                    end case ;
                    sf.parity := calculate_parity( sf ) ;
                    future.signal_field <= sf ;
                    future.signal_slv <= pack(sf) ;
                    future.bytes_left <= 3-1 ;
                    future.symbol_bytes <= params.n_dbps/8 ;
                    future.symbol_bytes_left <= params.n_dbps/8 - 1;
                    future.crc_reset <= '1' ;
                    if( params.datarate = WLAN_RATE_9) then
                       future.puncturing_nibble <= '1' ;
                       future.extra_byte <= '1' ;
                    else
                       future.puncturing_nibble <= '0' ;
                    end if ;
                end if ;

            when FRAME_SIGNAL =>
                -- SIGNAL field needs to be packed and sent out unscrambled
                future.data <= std_logic_vector(current.signal_slv(7 downto 0)) ;
                future.data_valid <= '1' ;
                if( current.bytes_left = 0 ) then
                    future.fsm <= WAIT_FOR_SIGNAL_MODULATED ;
                    future.bytes_left <= 2-1 ;
                else
                    future.signal_slv <= shift_right(current.signal_slv,8) ;
                    future.bytes_left <= current.bytes_left - 1 ;
                end if ;

            when WAIT_FOR_SIGNAL_MODULATED =>
                if( mod_done = '1' ) then
                    future.fsm <= FRAME_SERVICE ;
                    future.bad_index <= 0;
                end if ;

            when WAIT_ZZ =>
                if( current.bad_index = 70 ) then
                    future.fsm <= FRAME_SERVICE ;
                else
                    future.bad_index <= current.bad_index + 1;
                end if;

            when FRAME_SERVICE =>
                future.data <= (others =>'0') ;
                future.data_valid <= '1' ;
                if( current.bytes_left = 0 ) then
                    future.fifo_re <= '1' ;
                    future.fsm <= FRAME_DATA ;
                    future.bytes_left <= to_integer(current.signal_field.length) - 1 ;
                    if( current.puncturing_nibble = '1' and current.extra_byte = '1' ) then
                       future.symbol_bytes_left <= current.symbol_bytes - 2 ;
                       future.extra_byte <= '0' ;
                    else
                       future.symbol_bytes_left <= current.symbol_bytes - 2 - 1 ;
                    end if ;
                else
                    future.bytes_left <= current.bytes_left - 1 ;
                end if ;

            when FRAME_DATA =>
                future.data_valid <= '1' ;
                if( current.bytes_left = 3 ) then
                    future.crc_index <= 3 ;
                elsif( current.bytes_left < 3 ) then
                    future.crc_index <= current.crc_index - 1 ;
                end if ;
                if( current.bytes_left <= 3 ) then
                    future.crc_mux <= '1' ;
                else
                    future.data <= fifo_data ;
                    future.crc_data_valid <= '1' ;
                    if( current.bytes_left > 4 ) then
                       future.fifo_re <= '1' ;
                    end if;
                end if ;
                if( current.bytes_left = 0 ) then
                    future.fsm <= IDLE ;
                    future.done <= '1' ;
                else
                    if( current.symbol_bytes_left = 0 ) then
                        future.fifo_re <= '0' ;
                        future.fsm <= WAIT_FOR_DATA_MODULATED ;
                    else
                        future.symbol_bytes_left <= current.symbol_bytes_left - 1 ;
                    end if ;
                    future.bytes_left <= current.bytes_left - 1 ;
                end if ;
            when WAIT_FOR_DATA_MODULATED =>
                if( mod_done = '1' ) then
                    if( current.puncturing_nibble = '1' ) then
                        if( current.extra_byte = '1' ) then
                           future.symbol_bytes_left <= current.symbol_bytes ;
                        else
                           future.symbol_bytes_left <= current.symbol_bytes - 1 ;
                        end if;
                        future.extra_byte <= not current.extra_byte ;
                    else
                        future.symbol_bytes_left <= current.symbol_bytes - 1 ;
                    end if;
                    if( buffer_room = '1' ) then
                        future.bad_index <= 0;
                        future.fsm <= FRAME_DATA ;
                        future.fifo_re <= '1' ;
                    else
                        future.fsm <= WAIT_FOR_BUFFER_ROOM ;
                    end if ;
                end if ;

            when WAIT_YY =>
                if( current.bad_index = 32 ) then
                    future.fsm <= FRAME_DATA ;
                    future.fifo_re <= '1' ;
                else
                    future.bad_index <= current.bad_index + 1;
                end if;

            when WAIT_FOR_BUFFER_ROOM =>
                if( buffer_room = '1' ) then
                    future.fifo_re <= '1' ;
                    future.fsm <= FRAME_DATA ;
                end if ;

            when others =>
                future.fsm <= IDLE ;
        end case ;
    end process ;

    U_crc : entity wlan.wlan_crc
      port map (
        clock     => clock,
        reset     => reset or current.crc_reset,

        in_data   => current.data,
        in_valid  => current.crc_data_valid,
        crc       => calculated_crc
      ) ;

end architecture ;

