library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity stabilized_signal_test is end stabilized_signal_test;

architecture test of stabilized_signal_test is

  constant c_buffer_depth: positive := 2;

  signal r_clock, r_reset, r_async_signal, r_sync_signal: std_logic := '0';

  procedure test_reset
    parameter (
      signal o_reset, o_async_signal: out std_logic
    ) is
  begin
    -- Load in our expected signal, feeding '0' behind it.
    o_async_signal <= '1';
    wait until rising_edge(r_clock);
    o_async_signal <= '0';

    -- Cycle the expected value through the buffer.
    for index in 0 to c_buffer_depth - 1 loop
      wait until rising_edge(r_clock);
    end loop;

    -- Activate a reset, clearing the signal buffer.
    o_reset <= '1';
    wait until rising_edge(r_clock);
    o_reset <= '0';

    -- Confirm that the buffer is cleared.
    assert r_sync_signal = '0'
      report "Output signal unchanged after reset: "
           & "0 vs " & to_string(r_sync_signal)
      severity error;
  end procedure;

  procedure test_state
    parameter (
      signal o_async_signal: out std_logic
    ) is
  begin
    -- Load in our expected signal, feeding '0' behind it.
    o_async_signal <= '1';
    wait until rising_edge(r_clock);
    o_async_signal <= '0';

    -- Cycle the expected value through the buffer.
    for index in 0 to c_buffer_depth - 1 loop
      assert r_sync_signal = '0'
        report "Output signal changed before buffer filled: "
             & "0 vs " & to_string(r_sync_signal)
        severity error;
      wait until rising_edge(r_clock);
    end loop;

    -- Skip over our expected signal.
    wait until rising_edge(r_clock);

    -- Confirm that we have reverted to '0'.
    wait until rising_edge(r_clock);
    assert r_sync_signal = '0'
      report "Output signal unchanged after buffer emptied: "
           & "0 vs " & to_string(r_sync_signal)
      severity error;
  end procedure;

  procedure test_valid
    parameter (
      signal o_async_signal: out std_logic;
      i_expected: in std_logic
    ) is
  begin
    -- Load in our expected signal, feeding '0' behind it.
    o_async_signal <= i_expected;
    wait until rising_edge(r_clock);
    o_async_signal <= '0';

    -- Cycle the expected value through the buffer.
    for index in 0 to c_buffer_depth - 1 loop
      wait until rising_edge(r_clock);
    end loop;

    -- Confirm that our expected signal is exposed.
    wait until rising_edge(r_clock);
    assert r_sync_signal = i_expected
      report "Output signal unchanged after buffer filled: "
           & to_string(i_expected) & " vs " & to_string(r_sync_signal)
      severity error;

    -- Confirm that we have reverted to '0'.
    wait until rising_edge(r_clock);
  end procedure;

begin
  stabilized_signal_0: entity work.stabilized_signal
    generic map (
      g_buffer_depth => c_buffer_depth
    )
    port map (
      i_clock => r_clock,
      i_reset => r_reset,
      i_signal => r_async_signal,
      o_signal => r_sync_signal
    );

  r_clock <= not r_clock after c_clock_period / 2;

  process is
  begin
    test_state(r_async_signal);

    test_reset(r_async_signal, r_reset);

    test_valid(r_async_signal, 'U');
    test_valid(r_async_signal, 'X');
    test_valid(r_async_signal, '0');
    test_valid(r_async_signal, '1');
    test_valid(r_async_signal, 'Z');
    test_valid(r_async_signal, 'W');
    test_valid(r_async_signal, 'H');
    test_valid(r_async_signal, 'L');

    std.env.finish;
  end process;

end architecture;
