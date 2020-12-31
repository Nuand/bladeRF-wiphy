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
    use work.wlan_interleaver_p.all ;
    use work.wlan_rx_p.all ;

entity wlan_demodulator is
  port (
    clock            :   in  std_logic ;
    reset            :   in  std_logic ;

    init             :   in  std_logic ;

    params           :   in  wlan_rx_params_t ;
    params_valid     :   in  std_logic ;

    in_sample        :   in  wlan_sample_t ;
    in_done          :   in  std_logic ;

    dfe_sample       :  out  wlan_sample_t ;

    out_mod          :  out  wlan_modulation_t ;
    out_data         :  out  bsd_array_t( 287 downto 0 ) ;
    out_valid        :  out  std_logic
  ) ;
end entity ;

architecture arch of wlan_demodulator is

    type fsm_t is (IDLE, DEMODULATING) ;
    type bsd_fsm_t is (IDLE, DEMODULATING) ;

    type state_t is record
        fsm             :   fsm_t ;
        bsds            :   bsd_array_t(287 downto 0) ;
        index           :   natural range 0 to 70 ;
        modulation      :   wlan_modulation_t ;
        dfe             :   wlan_sample_t ;
        valid           :   std_logic ;
        pilot_polarity  :   std_logic ;
        lfsr_advance    :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.bsds := (others =>( others => '0' )) ;
        rv.index := 0 ;
        rv.modulation := WLAN_BPSK ;
        rv.valid := '0' ;
        rv.pilot_polarity := '1' ;
        rv.lfsr_advance := '0' ;
        return rv ;
    end function ;

    -- TODO: Add in the pilot polarity LFSR

    function reorder_bsds( x : bsd_array_t(287 downto 0) ; modulation : wlan_modulation_t ) return bsd_array_t is
        variable rv     : bsd_array_t(287 downto 0) ;
    begin
        rv := ( others => (others => '0' ) );
        -- Positions 24 -> 47 come first (positive frequencies)
        -- Positions 0 -> 23 are reversed and come afterwards (negative frequencies)
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
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;
    signal out_sample       :   wlan_sample_t ;
    signal clamped : wlan_sample_t ;

    signal lfsr_data    :   std_logic_vector( 0 downto 0 ) ;
    signal lfsr_advance :   std_logic ;
    signal bsdd_bsds :   wlan_bsds_t ;
begin

    dfe_sample.i <= resize( shift_left(clamped.i, 0), 16 ) ;
    dfe_sample.q <= resize( shift_left(clamped.q, 0), 16 ) ;
    dfe_sample.valid <= '0' ; --clamped.valid ;

    u_bsd : entity work.wlan_bsd
        port map(
            clock         => clock,
            reset         => reset,

            modulation    => params.modulation,

            in_sample     => in_sample,
            out_sample    => out_sample,

            bsds          => bsdd_bsds
        );

    u_clampler : entity work.wlan_clamper
        port map(
            clock         => clock,
            reset         => reset,

            in_mod        => params.modulation,
            in_ssd        => in_sample,

            out_ssd       => open,
            out_clamped   => clamped,
            out_error     => open
        );

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
            if( current.fsm /= IDLE and init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    out_mod   <= current.modulation ;
    out_data  <= current.bsds ;
    out_valid <= current.valid ;

    comb : process(all)
        variable tmp_bsds : bsd_array_t(287 downto 0) ;
    begin
        future <= current ;
        future.valid <= '0' ;
        future.lfsr_advance <= '0' ;

        if( params_valid = '1' ) then
            future.modulation <= params.modulation ;
        end if ;
        future.pilot_polarity <= lfsr_data(0);

        case current.fsm is
            when IDLE =>
                future.modulation <= WLAN_BPSK ;
                future.fsm <= DEMODULATING ;
            when DEMODULATING =>

                if( bsdd_bsds.valid = '1' ) then
                    case current.index is
                        -- Check for DC null
                        when 0 =>

                        -- Check for outside nulls
                        when 27 to 37 =>

                        -- Check for 3 positive pilots
                        when 7|43|57 =>

                        -- Check for 1 negative pilot
                        when 21 =>

                        -- Otherwise data
                        when others =>
                            case current.modulation is
                                when WLAN_BPSK =>
                                    future.bsds <= current.bsds(287 downto 48) & bsdd_bsds.bsds(0) & current.bsds(47 downto 1);
                                when WLAN_QPSK =>
                                    future.bsds <= current.bsds(287 downto 96) & bsdd_bsds.bsds(1 downto 0) & current.bsds(95 downto 2);
                                when WLAN_16QAM =>
                                    future.bsds <= current.bsds(287 downto 192) & bsdd_bsds.bsds(3 downto 0) & current.bsds(191 downto 4);
                                when WLAN_64QAM =>
                                    future.bsds <= bsdd_bsds.bsds( 5 downto 0) & current.bsds(287 downto 6);
                                when others =>
                            end case ;

                    end case ;

                    -- Check if we've reached a full symbol length
                    if( current.index < 64 ) then
                        future.index <= current.index + 1 ;
                    end if ;
                end if ;
                if( current.index = 64) then
                    future.lfsr_advance <= '1' ;
                    future.index <= 0 ;
                    future.bsds <= reorder_bsds(current.bsds, current.modulation) ;
                    future.valid <= '1' ;
                end if ;
        end case ;
    end process ;

end architecture ;


