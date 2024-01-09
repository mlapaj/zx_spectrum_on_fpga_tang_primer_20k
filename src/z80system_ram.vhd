library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- to speedup

entity z80system_ram is
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
           clk_video         : in std_logic;
           addr_i_video      : in std_logic_vector(15 downto 0);
           data_o_video      : out std_logic_vector(7 downto 0)
  );
end entity;

architecture basic of z80system_ram is
    component Gowin_DPB
        port (
                 douta: out std_logic_vector(7 downto 0);
                 doutb: out std_logic_vector(7 downto 0);
                 clka: in std_logic;
                 ocea: in std_logic;
                 cea: in std_logic;
                 reseta: in std_logic;
                 wrea: in std_logic;
                 clkb: in std_logic;
                 oceb: in std_logic;
                 ceb: in std_logic;
                 resetb: in std_logic;
                 wreb: in std_logic;
                 ada: in std_logic_vector(15 downto 0);
                 dina: in std_logic_vector(7 downto 0);
                 adb: in std_logic_vector(15 downto 0);
                 dinb: in std_logic_vector(7 downto 0)
             );
    end component;

begin
    mem0: Gowin_DPB
    port map (
                 douta => data_o,
                 doutb => data_o_video,
                 clka => clk_i,
                 ocea => '0',
                 cea => '1', -- clock enable
                 reseta => not rstn_i,
                 wrea => (not mreqn_i) and (not wr_i),
                 clkb => clk_video,
                 oceb => '0',
                 ceb => '1',
                 resetb => not rstn_i,
                 wreb => '0',
                 ada => addr_i,
                 dina => data_i,
                 adb => addr_i_video,
                 dinb => "00000000"
             );


end architecture;
