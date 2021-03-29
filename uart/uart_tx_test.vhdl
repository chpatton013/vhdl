library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_tx_test is end uart_tx_test;

architecture test of uart_tx_test is

  constant c_baud_rate: positive := 9600;
  constant c_baud_period: time := 1 sec / c_baud_rate;
  constant c_data_width: positive := 8;
  constant c_stop_width: positive := 1;

  signal r_clock, r_reset, r_valid: std_logic := '0';
  signal r_chunk: std_logic_vector(c_data_width - 1 downto 0) := (others => '0');
  signal r_serial, r_active: std_logic := '0';

  procedure test_state
    parameter (
      signal o_valid: out std_logic
    ) is
  begin
    -- Reset
    assert r_serial = 'Z' report "Serial output is not high-Z for reset state" severity error;
    assert r_active = '0' report "Active output is not off for reset" severity error;
    wait until rising_edge(r_clock);
    wait until rising_edge(r_clock);
    wait until rising_edge(r_clock);

    -- Idle
    assert r_active = '0' report "Active output is not off during idle" severity error;
    o_valid <= '1';
    wait until rising_edge(r_active);
    o_valid <= '0';

    -- Start bit
    assert r_active = '1' report "Active output is not on during transmit" severity error;

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      assert r_active = '1' report "Active output is not on during transmit" severity error;
    end loop;

    -- Stop bits
    for index in 0 to c_stop_width - 1 loop
      wait for c_baud_period;
      assert r_active = '1' report "Active output is not on during transmit" severity error;
    end loop;

    -- Transition to idle
    wait for c_baud_period;
    assert r_active = '0' report "Active output is not off during idle" severity error;
  end procedure;

  procedure test_valid
    parameter (
      signal o_valid: out std_logic;
      signal o_chunk: out std_logic_vector(c_data_width - 1 downto 0);
      i_expected: in std_logic_vector(c_data_width - 1 downto 0)
    ) is
  begin
    -- Idle
    o_chunk <= i_expected;
    assert r_serial = '1' report "Serial output is not on during idle" severity error;

    -- Transition to start
    o_valid <= '1';
    wait until rising_edge(r_active);
    o_valid <= '0';

    -- Start bit
    assert r_serial = '0' report "Serial output is not off for start bit" severity error;

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      assert r_serial = i_expected(index) report "Serial output does not match data bit" severity error;
    end loop;

    -- Stop bits
    for index in 0 to c_stop_width - 1 loop
      wait for c_baud_period;
      assert r_serial = '1' report "Serial output is not on for stop bit" severity error;
    end loop;

    -- Transition to idle
    wait for c_baud_period;
    assert r_serial = '1' report "Serial output is not on for idle state" severity error;
  end procedure;

begin
  uart_tx_0: entity work.uart_tx
    generic map (
      g_clock_rate => c_clock_rate,
      g_baud_rate => c_baud_rate,
      g_data_width => c_data_width,
      g_stop_width => c_stop_width
    )
    port map (
      i_clock => r_clock,
      i_reset => r_reset,
      i_valid => r_valid,
      i_chunk => r_chunk,
      o_serial => r_serial,
      o_active => r_active
    );

  r_clock <= not r_clock after c_clock_period / 2;

  process is
  begin
    test_state(r_valid);

    test_valid(r_valid, r_chunk, "11111111");
    test_valid(r_valid, r_chunk, "11110000");
    test_valid(r_valid, r_chunk, "00111100");
    test_valid(r_valid, r_chunk, "00001111");
    test_valid(r_valid, r_chunk, "10101010");
    test_valid(r_valid, r_chunk, "01010101");
    test_valid(r_valid, r_chunk, "00000000");

    std.env.finish;
  end process;

end architecture;
