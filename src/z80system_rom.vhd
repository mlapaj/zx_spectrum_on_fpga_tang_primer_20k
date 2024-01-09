library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- to speedup

entity z80system_rom is
  port (
           rstn_i      : in  std_logic;
           clk_i       : in std_logic; -- global clock, rising edge
           mreqn_i     : in std_logic;
           rd_i        : in std_logic;
           addr_i      : in std_logic_vector(15 downto 0);
           data_o      : out std_logic_vector(7 downto 0)
  );
end entity;

architecture basic of z80system_rom is

component Gowin_pROM
    port (
        dout: out std_logic_vector(7 downto 0);
        clk: in std_logic;
        oce: in std_logic;
        ce: in std_logic;
        reset: in std_logic;
        ad: in std_logic_vector(13 downto 0)
    );
end component;

begin

rom: Gowin_pROM
    port map (
        dout => data_o,
        clk => clk_i,
        oce => '1',
        ce => '1',
        reset => not rstn_i,
        ad => addr_i(13 downto 0)
    );

end architecture;
