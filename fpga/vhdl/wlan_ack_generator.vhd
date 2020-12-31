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

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

entity wlan_ack_generator is
  port (
    wclock              :   in  std_logic ;
    wreset              :   in  std_logic ;

    ack_mac             :   in  std_logic_vector( 47 downto 0 );
    ack_valid           :   in  std_logic ;

    rclock              :   in  std_logic ;
    rreset              :   in  std_logic ;

    fifo_data           :   out std_logic_vector( 7 downto 0 );
    fifo_re             :   in  std_logic ;
    done_tx             :   in  std_logic ;

    ack_ready           :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_ack_generator is
    signal   wfull      :   std_logic ;
    signal   rempty     :   std_logic ;
    signal   rread      :   std_logic ;

    type fsm_t is (IDLE, READ, DONE);

    type state_t is record
        fsm             :  fsm_t;
        payload         :  std_logic_vector( 79 downto 0 );
        rread           :  std_logic ;
        byte_idx        :  natural range 0 to 10 ;
    end record ;

    signal current_state  : state_t;
    signal future_state   : state_t;

    function NULL_STATE return state_t is
        variable rv : state_t;
    begin
        rv.fsm        := IDLE ;
        rv.payload    := (others => '0' ) ;
        rv.rread      := '0' ;
        rv.byte_idx   := 0 ;

        return rv ;
    end function ;

    signal mac_address : std_logic_vector( 47 downto 0 );
begin

    U_mac_dc_fifo: dcfifo
      generic map (
        lpm_width       =>  48,
        lpm_widthu      =>  4,
        lpm_numwords    =>  16,
        lpm_showahead   =>  "ON"
      )
      port map (
        aclr            => wreset or rreset,

        wrclk           => wclock,
        wrreq           => ack_valid and not wfull,
        data            => ack_mac,

        wrfull          => wfull,
        wrempty         => open,
        wrusedw         => open,

        rdclk           => rclock,
        rdreq           => rread,
        q               => mac_address,

        rdfull          => open,
        rdempty         => rempty,
        rdusedw         => open
      ) ;

    ack_ready <= not rempty;
    fifo_data <= current_state.payload(79 downto 72);
    rread     <= current_state.rread;

    process(all)
    begin
        future_state <= current_state ;

        future_state.rread <= '0';

        case current_state.fsm is

            when IDLE =>
                future_state.payload <= x"D400" & x"0000" & mac_address;
                if( fifo_re = '1' and rempty = '0' ) then
                    future_state.fsm      <= READ ;
                    future_state.byte_idx <= 0 ;
                    future_state.rread    <= '1' ;
                    future_state.payload <= current_state.payload(71 downto 0) & x"00";
                else
                    future_state.payload <= x"D400" & x"0000" & mac_address;
                end if;

            when READ =>
                if( fifo_re = '1' ) then
                    future_state.byte_idx <= current_state.byte_idx + 1;
                    future_state.payload <= current_state.payload(71 downto 0) & x"00";
                    if( current_state.byte_idx = 9 ) then
                        future_state.fsm <= DONE ;
                    end if;
                end if;

            when DONE =>
                if (done_tx = '1') then
                   future_state.fsm      <= IDLE ;
                end if ;
                future_state.byte_idx <= 0 ;

            when others =>
                future_state <= NULL_STATE ;

        end case;

    end process;

    process(rclock, rreset)
    begin
        if( rreset = '1' ) then
            current_state <= NULL_STATE ;
        elsif( rising_edge( rclock ) ) then
            current_state <= future_state ;
        end if;
    end process;

end architecture ;

