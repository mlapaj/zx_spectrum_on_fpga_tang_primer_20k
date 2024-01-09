library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library t80lib;
use t80lib.all;

use STD.textio.all;
use ieee.std_logic_textio.all;


entity z80system is
    port (
             -- Global control --
             clk_i       : in  std_logic; -- global clock, rising edge
             rstn_i      : in  std_logic; -- global reset, low-active, async
             zx_rstn_i   : in  std_logic;
             O_tmds_clk_p: out std_logic;
             O_tmds_clk_n: out std_logic;
             O_tmds_data_p: out std_logic_vector(2 downto 0);
             O_tmds_data_n: out std_logic_vector(2 downto 0);
             a_key_i   : in  std_logic;
             o_dbg_1   : out std_logic;
             o_dbg_2    : out std_logic;

             kb1_i     : in std_logic_vector(4 downto 0);
             kb2_o     : out std_logic_vector(7 downto 0)

         );
end entity;

architecture basic of z80system is
    signal wait_n : std_logic := '1';
    signal int_n : std_logic := '1';
    signal nmi_n : std_logic := '1';
    signal busrq_n : std_logic := '1';
    signal rfsh_n : std_logic;
    signal iorq_n  : std_logic;

    -- cpu mem interface
    signal cpu_addr : std_logic_vector(15 downto 0);
    signal cpu_mreq_n : std_logic;
    signal cpu_rd_n : std_logic;
    signal cpu_wr_n : std_logic;
    signal cpu_d_i : std_logic_vector(7 downto 0);
    signal cpu_d_o : std_logic_vector(7 downto 0);
    -- rom interface
    signal rom_addr_i : std_logic_vector(15 downto 0);
    signal rom_mreqn_i : std_logic;
    signal rom_rd_i : std_logic;
    signal rom_data_o : std_logic_vector(7 downto 0);
    -- ram interface
    signal ram_addr_i : std_logic_vector(15 downto 0);
    signal ram_mreqn_i : std_logic;
    signal ram_rd_i : std_logic;
    signal ram_wr_i : std_logic;
    signal ram_data_i : std_logic_vector(7 downto 0);
    signal ram_data_o : std_logic_vector(7 downto 0);
    -- vattrib ram
    signal ram_vattrib_addr_i : std_logic_vector(9 downto 0);
    signal ram_vattrib_mreqn_i : std_logic;
    signal ram_vattrib_rd_i : std_logic;
    signal ram_vattrib_wr_i : std_logic;
    signal ram_vattrib_data_i : std_logic_vector(7 downto 0);
    signal ram_vattrib_data_o : std_logic_vector(7 downto 0);

    -- vid
    signal vid_addr_o : std_logic_vector(15 downto 0);
    signal vid_rd_o : std_logic;
    signal vid_d_i : std_logic_vector(7 downto 0);
    -- vattrib
    signal vattrib_addr_o : std_logic_vector(9 downto 0);
    signal vattrib_rd_o : std_logic;
    signal vattrib_d_i : std_logic_vector(7 downto 0);

    --pll
    signal pll_out : std_logic;

    component T80s is
        generic(
                   Mode    : integer := 0; -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
                   T2Write : integer := 1; -- 0 => WR_n active in T3, /=0 => WR_n active in T2
                   IOWait  : integer := 1  -- 0 => Single cycle I/O, 1 => Std I/O cycle
               );
        port(
                RESET_n : in std_logic;
                CLK     : in std_logic;
                CEN     : in std_logic := '1';
                WAIT_n  : in std_logic := '1';
                INT_n     : in std_logic := '1';
                NMI_n     : in std_logic := '1';
                BUSRQ_n : in std_logic := '1';
                M1_n    : out std_logic;
                MREQ_n  : out std_logic;
                IORQ_n  : out std_logic;
                RD_n    : out std_logic;
                WR_n    : out std_logic;
                RFSH_n  : out std_logic;
                HALT_n  : out std_logic;
                BUSAK_n : out std_logic;
                OUT0    : in  std_logic := '0';  -- 0 => OUT(C),0, 1 => OUT(C),255
                A       : out std_logic_vector(15 downto 0);
                DI      : in std_logic_vector(7 downto 0);
                DO      : out std_logic_vector(7 downto 0)
            );
    end component;

  

  component z80system_ram_vattrib is
  port (
           rstn_i      : in  std_logic;
           clk_i       : in std_logic; -- global clock, rising edge
           mreqn_i     : in std_logic;
           rd_i        : in std_logic;
           wr_i        : in std_logic;
           addr_i      : in std_logic_vector(9 downto 0);
           data_i      : in std_logic_vector(7 downto 0);
           data_o      : out std_logic_vector(7 downto 0);
           -- video
           clk_video         : in std_logic;
           addr_i_vattrib      : in std_logic_vector(9 downto 0);
           data_o_vattrib      : out std_logic_vector(7 downto 0)
  );
end component;


    component z80system_rom is
        port (
           rstn_i      : in  std_logic;
           clk_i       : in std_logic; -- global clock, rising edge
           mreqn_i     : in std_logic;
           rd_i        : in std_logic;
           addr_i      : in std_logic_vector(15 downto 0);
           data_o      : out std_logic_vector(7 downto 0)
             );
    end component;

component z80system_ram is
  port (
           rstn_i      : in  std_logic;
           clk_i       : in std_logic; -- global clock, rising edge
           mreqn_i     : in std_logic;
           rd_i        : in std_logic;
           wr_i        : in std_logic;
           addr_i      : in std_logic_vector(15 downto 0);
           data_i      : in std_logic_vector(7 downto 0);
           data_o      : out std_logic_vector(7 downto 0);
           -- video
           addr_i_video      : in std_logic_vector(15 downto 0);
           data_o_video      : out std_logic_vector(7 downto 0);
           clk_video         : in std_logic
  );
end component;




    component hdmi is
        port (
                 -- Global control --
                 clk_i       : in  std_logic; -- global clock, rising edge
                 rdy_i       : in  std_logic; -- global clock, rising edge
                 rstn_i      : in  std_logic; -- global reset, low-active, async
                 tmds_clk_p_o: out std_logic;
                 tmds_clk_n_o: out std_logic;
                 tmds_data_p_o: out std_logic_vector(2 downto 0);
                 tmds_data_n_o: out std_logic_vector(2 downto 0);
                 -- ram access
                 rd_o        : out std_logic;
                 vid_addr_o      : out std_logic_vector(15 downto 0);
                 vid_data_i      : in std_logic_vector(7 downto 0);
                 vattrib_addr_o      : out std_logic_vector(9 downto 0);
                 vattrib_data_i      : in std_logic_vector(7 downto 0)

             );
    end component;

-- PLL component created by Gowin
    component Gowin_rPLL
        port (
                 clkout: out std_logic;
                 clkin: in std_logic
             );
    end component;

component clock_div is
port(
  clk_i         : in  std_logic;
  rstn_i         : in  std_logic;
  clk_div8_o    : out std_logic
);
end component;

signal clk_div8_o : std_logic;
signal io_out : std_logic_vector (7 downto 0);
-- fake interrupt
signal cnt_int : integer range 0 to 67501 := 0;


begin
    clkdiv: clock_div port map (clk_i => clk_i, rstn_i => rstn_i, clk_div8_o => clk_div8_o);
    pll0: Gowin_rPLL port map (clkout => pll_out,clkin => clk_i);

    cpu: T80s port map (
                           CLK     => clk_div8_o,
                           RESET_n => rstn_i and zx_rstn_i,
                           WAIT_n  => wait_n,
                           INT_n   => int_n,
                           NMI_n   => nmi_n,
                           BUSRQ_n => busrq_n,
                           RFSH_n  => rfsh_n,
                           A       => cpu_addr,
                           MREQ_n  => cpu_mreq_n,
                           DI      => cpu_d_i,
                           DO      => cpu_d_o,
                           RD_n    => cpu_rd_n,
                           WR_n    => cpu_wr_n,
                           IORQ_n  => iorq_n
                       );




    hdmi0: hdmi port map (
                 -- Global control --
                 clk_i  => pll_out,
                 rdy_i  => '1',
                 rstn_i => rstn_i,
                 tmds_clk_p_o => O_tmds_clk_p,
                 tmds_clk_n_o => O_tmds_clk_n,
                 tmds_data_p_o => O_tmds_data_p,
                 tmds_data_n_o => O_tmds_data_n,
                 -- ram access
                 rd_o   => vid_rd_o,
                 vid_addr_o => vid_addr_o,
                 vid_data_i => vid_d_i,
                 vattrib_data_i => vattrib_d_i,
                 vattrib_addr_o => vattrib_addr_o 
             );
    rom: z80system_rom port map (
                                    clk_i   => clk_div8_o,
                                    rstn_i  => rstn_i,
                                    addr_i  => rom_addr_i,
                                    mreqn_i => rom_mreqn_i,
                                    data_o  => rom_data_o,
                                    rd_i    => rom_rd_i
                                );
    ram: z80system_ram port map (
                                    clk_i   => clk_div8_o,
                                    rstn_i  => rstn_i and zx_rstn_i,
                                    addr_i  => ram_addr_i,
                                    mreqn_i => ram_mreqn_i,
                                    data_i  => ram_data_i,
                                    data_o  => ram_data_o,
                                    rd_i    => ram_rd_i,
                                    wr_i    => ram_wr_i,
                                    clk_video => pll_out,
                                    addr_i_video => vid_addr_o,
                                    data_o_video => vid_d_i
                                );

    ram_vattrib: z80system_ram_vattrib port map (
                                    clk_i   => clk_div8_o,
                                    rstn_i  => rstn_i and zx_rstn_i,
                                    addr_i  => ram_vattrib_addr_i,
                                    mreqn_i => ram_vattrib_mreqn_i,
                                    data_i  => ram_vattrib_data_i,
                                    data_o  => ram_vattrib_data_o,
                                    rd_i    => ram_vattrib_rd_i,
                                    wr_i    => ram_vattrib_wr_i,
                                    clk_video => pll_out,
                                    addr_i_vattrib => vattrib_addr_o,
                                    data_o_vattrib => vattrib_d_i
                                );

    process (clk_div8_o)
    begin
        if rising_edge(clk_div8_o) then
            if (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr(7 downto 0) = x"FE") then
                io_out <= "111" & not(kb1_i);
                --io_out <= "11111111";
            else
                io_out <= "00000000";
            end if;
--             0xfdfe read http://www.breakintoprogram.co.uk/hardware/computers/zx-spectrum/keyboard
--            if (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"FDFE") then
--                io_out <= "1111111" & a_key_i;
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"FEFE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"FBFE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"F7FE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"EFFE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"DFFE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"BFFE") then
--                io_out <= "11111111";
--            elsif (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr = x"7FFE") then
--                io_out <= "11111111";
--            else
--                io_out <= "00000000";
--            end if;
        end if;
    end process;

      kb2_o <= not(cpu_addr(15 downto 8)) when (iorq_n = '0' and cpu_rd_n = '0' and cpu_addr(7 downto 0) = x"FE") else "00000000";
      

    -- The Z80 interrupt on the Spectrum is triggered at the start of the vertical blank period of the screen refresh
    -- we will cheat here :-) for some time
    -- This interrupt is very similar to IM2 (Interrupt Mode 2) in that it is triggered 
    -- by the vertical blanking of the screen refresh that happens roughly 50 times a second.
    process (clk_div8_o)
    begin
        -- reset
        if rising_edge(clk_div8_o) then
            cnt_int <= cnt_int + 1;
            int_n <= '1';
            if (cnt_int > 67490) then
                int_n <= '0';
            end if;
            if (cnt_int = 67500) then
                cnt_int <= 0;
            end if;
            
        end if;
    end process;

    o_dbg_1 <= clk_div8_o;
    o_dbg_2 <= iorq_n;


    rom_addr_i <= cpu_addr when cpu_addr(15 downto 14) = "00" else "0000000000000000";
    ram_addr_i <= "00" & cpu_addr(13 downto 0) when cpu_addr(15 downto 14) = "01" else
                  "01" & cpu_addr(13 downto 0) when cpu_addr(15 downto 14) = "10" else
                  "10" & cpu_addr(13 downto 0) when cpu_addr(15 downto 14) = "11" else
                  "0000000000000000";

    -- vattrib will be stored in ram and ram_vattrib at once
    ram_vattrib_addr_i <= cpu_addr(9 downto 0) when cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10") else
                  "0000000000";

    
    rom_mreqn_i <= cpu_mreq_n when cpu_addr(15 downto 14) = "00" else '1';
    ram_mreqn_i <= cpu_mreq_n when cpu_addr(15 downto 14) /= "00" else '1';
    ram_vattrib_mreqn_i <= cpu_mreq_n when cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10") else '1';

    rom_rd_i <= cpu_rd_n when cpu_addr(15 downto 14) = "00" else '1';
    ram_rd_i <= cpu_rd_n when cpu_addr(15 downto 14) /= "00" else '1';
    ram_vattrib_rd_i <= cpu_rd_n when cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10") else '1';


    ram_wr_i <= cpu_wr_n when cpu_addr(15 downto 14) /= "00" else '1';
    ram_vattrib_wr_i <= cpu_wr_n when cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10") else '1';

    -- make it simplier
    ram_data_i <= cpu_d_o when (cpu_addr(15 downto 14) /= "00") and not (cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10")) else "00000000";
    ram_vattrib_data_i <= cpu_d_o when cpu_addr(15 downto 10) = "010110" 
                          and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                          or cpu_addr(9 downto 8) = "10") else "00000000";


    cpu_d_i <= io_out             when (iorq_n = '0' and cpu_rd_n = '0') else
               rom_data_o         when cpu_addr(15 downto 14) = "00" else 
               ram_vattrib_data_o when cpu_addr(15 downto 10) = "010110" 
                                        and (cpu_addr(9 downto 8) = "00" or  cpu_addr(9 downto 8) = "01"
                                        or cpu_addr(9 downto 8) = "10") else
               ram_data_o;

end architecture;
