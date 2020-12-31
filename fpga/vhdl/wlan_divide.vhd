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

library lpm ;
    use lpm.lpm_components.all ;

entity wlan_divide is
  generic (
    SAMPLE_WIDTH    :   natural ;
    DENOM_WIDTH     :   natural ;
    NUM_PIPELINE    :   natural
  ) ;
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;

    in_i        :   in  signed(SAMPLE_WIDTH-1 downto 0) ;
    in_q        :   in  signed(SAMPLE_WIDTH-1 downto 0) ;
    in_denom    :   in  unsigned(DENOM_WIDTH-1 downto 0) ;
    in_valid    :   in  std_logic ;
    in_done     :   in  std_logic ;

    out_i       :   out signed(SAMPLE_WIDTH-1 downto 0) ;
    out_q       :   out signed(SAMPLE_WIDTH-1 downto 0) ;
    out_valid   :   out std_logic ;
    out_done    :   out std_logic
  ) ;
end entity ;

architecture altera of wlan_divide is

    signal done : std_logic_vector(NUM_PIPELINE-1 downto 0) ;
    signal valid : std_logic_vector(NUM_PIPELINE-1 downto 0) ;

begin

    register_valids_and_done : process(clock, reset)
    begin
        if( reset = '1' ) then
            done <= (others =>'0') ;
            valid <= (others =>'0') ;
        elsif( rising_edge(clock) ) then
            done <= done(done'high-1 downto 0) & in_done ;
            valid <= valid(valid'high-1 downto 0) & in_valid ;
        end if ;
    end process ;

    out_done <= done(done'high) ;
    out_valid <= valid(valid'high) ;

    div_i : lpm_divide
      generic map (
        lpm_nrepresentation => "SIGNED",
        lpm_drepresentation => "UNSIGNED",
        lpm_hint            => "LPM_REMAINDERPOSITIVE=TRUE",
        lpm_pipeline        => NUM_PIPELINE,
        lpm_type            => "LPM_DIVIDE",
        lpm_widthd          => DENOM_WIDTH,
        lpm_widthn          => SAMPLE_WIDTH
      ) port map (
        clock               =>  clock,
        aclr                =>  reset,
        numer               =>  std_logic_vector(in_i),
        denom               =>  std_logic_vector(in_denom),
        remain              =>  open,
        signed(quotient)    =>  out_i
      ) ;

    div_q : lpm_divide
      generic map (
        lpm_nrepresentation => "SIGNED",
        lpm_drepresentation => "UNSIGNED",
        lpm_hint            => "LPM_REMAINDERPOSITIVE=TRUE",
        lpm_pipeline        => NUM_PIPELINE,
        lpm_type            => "LPM_DIVIDE",
        lpm_widthd          => DENOM_WIDTH,
        lpm_widthn          => SAMPLE_WIDTH
      ) port map (
        clock               =>  clock,
        aclr                =>  reset,
        numer               =>  std_logic_vector(in_q),
        denom               =>  std_logic_vector(in_denom),
        remain              =>  open,
        signed(quotient)    =>  out_q
      ) ;

end architecture ;
