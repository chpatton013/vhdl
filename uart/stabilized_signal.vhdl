--
-- Generic implementation of a signal stabilizer with customizable metastability
-- buffer-depth. This implementation cannot guarantee that all metastability
-- events have resolved by the time the signal passed through the buffer, but it
-- can drastically reduce the likelihood that the output is still unstable.
--
-- Generics:
--
-- * g_buffer_depth: The number of flip-flops to buffer signals through while
--   waiting for metastability events to resolve.
--
-- Ports:
--
-- * i_clock: The unit's clock cycle signal.
-- * i_reset: Reset the buffer values.
-- * i_signal: The asynchronous and unstable input data.
-- * o_signal: The synchronous and stable output data.
--

library ieee;
use ieee.std_logic_1164.all;

entity stabilized_signal is
  generic (
    g_buffer_depth: positive range 2 to 3 := 2
  );
  port (
    i_clock, i_reset, i_signal: in std_logic := '0';
    o_signal: out std_logic := '0'
  );
end stabilized_signal;

architecture rtl of stabilized_signal is
  signal r_signal: std_logic_vector(g_buffer_depth - 1 downto 0) := (others => '0');
begin
  process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' then
        r_signal <= (others => '0');
        o_signal <= '0';
      else
        r_signal(g_buffer_depth - 2 downto 0) <= r_signal(g_buffer_depth - 1 downto 1);
        r_signal(g_buffer_depth - 1) <= i_signal;
        o_signal <= r_signal(0);
      end if;
    end if;
  end process;
end architecture;
