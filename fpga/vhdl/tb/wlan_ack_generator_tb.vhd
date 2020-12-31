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

entity wlan_ack_generator_tb is
end entity ;

architecture arch of wlan_ack_generator_tb is

    signal wclock        :   std_logic         := '1' ;
    signal wreset        :   std_logic         := '1' ;

    signal rclock        :   std_logic         := '1' ;
    signal rreset        :   std_logic         := '1' ;

    signal ack_valid     :   std_logic         := '0' ;

    signal fifo_re       :   std_logic         := '0' ;

begin

    wclock <= not wclock after 5 ns ;
    wreset <= '1', '0' after 55 ns ;

    rclock <= not rclock after 6 ns ;
    rreset <= '1', '0' after 55 ns ;

    ack_valid <= '0', '1' after 72 ns, '0' after 82 ns ;

    fifo_re   <= '0', '1' after 400 ns, '0' after 412 ns ;
    U_ack_gen : entity wlan.wlan_ack_generator
      port map (
        wclock     => wclock,
        wreset     => wreset,

        ack_mac    => x"1234567890ab",
        ack_valid  => ack_valid,

        rclock     => rclock,
        rreset     => rreset,

        fifo_data  => open,
        fifo_re    => fifo_re,
        done_tx    => '1',

        ack_ready  => open
      ) ;

end architecture ;
