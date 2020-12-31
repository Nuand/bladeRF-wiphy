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

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

library wlan;
entity wlan_acquisition_tb is
end entity ;

architecture arch of wlan_acquisition_tb is

    signal clock    :   std_logic := '0' ;
    signal sample   :   wlan_sample_t ;
    signal fopen    :   std_logic;
    signal reset    :   std_logic;

    signal i_sum    :   signed(63 downto 0);
    signal q_sum    :   signed(63 downto 0);
    signal sum      :   signed(127 downto 0);

    signal acquired_packet  :   std_logic ;
    signal p_mag            :   signed(23 downto 0) ;

    type SAMPLE_ARRAY is array (integer range <>) of wlan_sample_t;
    signal samples : SAMPLE_ARRAY(0 to 159);

begin

    clock <= not clock after 10 ns;
    reset <= '1', '0' after 50 ns ;
    fopen <= '0', '1' after 100 ns;

    U_sample_loader: entity wlan.wlan_sample_loader
      generic map (
        FILENAME    => "tx"
      ) port map (
        clock       => clock,
        fopen       => fopen,
        sample      => sample
      );

    U_csma : entity wlan.wlan_csma
      port map (
        clock       =>  clock,
        reset       =>  reset,

        in_sample   =>  sample,
        quiet       =>  open
    ) ;
    U_acquisition : entity wlan.wlan_acquisition
      port map (
        clock       =>  clock,
        reset       =>  reset,

        in_sample   =>  sample,
        acquired    =>  acquired_packet,
        p_mag       =>  p_mag,

        quiet       =>  '0',
        burst       =>  '0',

        out_sample  =>  open
      );

    tb : process(clock)
        variable tsum : signed(127 downto 0);
        variable isum : signed(63 downto 0);
        variable qsum : signed(63 downto 0);
    begin
        if( rising_edge( clock ) ) then
            if( sample.valid = '1' ) then
                for i in 0 to samples'high - 1 loop
                    samples(i+1) <= samples(i);
                end loop ;
                samples(0) <= sample;

                isum := (others => '0');
                qsum := (others => '0');
                for i in 0 to 79 loop
                    isum := isum + samples(i).i * samples(i + 80).i + samples(i).q * samples(i + 80).q;
                    qsum := qsum - samples(i).i * samples(i + 80).q + samples(i).q * samples(i + 80).i;
                end loop ;
                i_sum <= isum;
                q_sum <= qsum;
                tsum := isum * isum + qsum * qsum;
                sum <= tsum;
            end if;
        end if ;
    end process ;

end architecture ;

