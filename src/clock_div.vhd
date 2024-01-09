library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
entity clock_div is
port(
  clk_i         : in  std_logic;
  rstn_i         : in  std_logic;
  clk_div8_o    : out std_logic
);
end entity;

architecture basic of clock_div is
signal clk_cnt        : unsigned(2 downto 0);
begin

process(rstn_i,clk_i)
begin
  if(rstn_i='0') then
    clk_cnt   <= (others=>'0');
  elsif(rising_edge(clk_i)) then
    clk_cnt   <= clk_cnt + 1;
  end if;
end process;
clk_div8_o    <= clk_cnt(2);
end architecture;
