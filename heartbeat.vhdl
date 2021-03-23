library IEEE;
use IEEE.std_logic_1164.all;

entity heartbeat is
  port ( clk: out std_logic );
end heartbeat;

architecture behaviour of heartbeat is
  constant clk_period : time := 1000 ms;
begin
  -- Clock process definition
  clk_process: process
  begin
    clk <= '0';
    wait for clk_period / 2;
    clk <= '1';
    wait for clk_period / 2;
  end process;
end behaviour;
