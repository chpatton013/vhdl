library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_rx_test is end uart_rx_test;

architecture test of uart_rx_test is

  constant c_baud_rate: positive := 9600;
  constant c_baud_period: time := 1 sec / c_baud_rate;
  constant c_data_width: positive := 8;
  constant c_stop_width: positive := 1;

  signal r_clock, r_reset, r_serial: std_logic := '0';
  signal r_active, r_valid, r_error: std_logic := '0';
  signal r_chunk: std_logic_vector(c_data_width - 1 downto 0) := (others => '0');

  procedure test_state
    parameter (
      signal o_serial: out std_logic
    ) is
  begin
    -- Idle
    o_serial <= '1';
    wait until rising_edge(r_clock);

    -- Start bit
    assert r_active = '0' report "Active bit is not off before start bit" severity error;
    assert r_valid = '0' report "Valid bit is not off before start bit" severity error;
    assert r_error = '0' report "Error bit is not off before start bit" severity error;
    o_serial <= '0';

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      assert r_active = '1' report "Active bit is not on before data bit" severity error;
      assert r_valid = '0' report "Valid bit is not off before data bit" severity error;
      assert r_error = '0' report "Error bit is not off before data bit" severity error;
      o_serial <= '0';
    end loop;

    -- Stop bits
    for index in 0 to c_stop_width - 1 loop
      wait for c_baud_period;
      assert r_active = '1' report "Active bit is not on before stop bit" severity error;
      assert r_valid = '0' report "Valid bit is not off before stop bit" severity error;
      assert r_error = '0' report "Error bit is not off before stop bit" severity error;
      o_serial <= '1';
    end loop;

    -- Flush
    wait until rising_edge(r_valid);
    assert r_active = '0' report "Active bit is not off during flush" severity error;
    assert r_valid = '1' report "Valid bit is not on during flush" severity error;
    assert r_error = '0' report "Error bit is not off during flush" severity error;

    -- Return to idle
    wait until falling_edge(r_valid);
    wait until rising_edge(r_clock);
  end procedure;

  procedure test_reset
    parameter (
      signal o_reset, o_serial: out std_logic
    ) is
  begin
    -- Transition to idle
    o_serial <= '1';
    wait until rising_edge(r_clock);

    -- Start bit
    o_serial <= '0';

    -- Data bits
    for index in 0 to c_data_width / 2 - 1 loop
      wait for c_baud_period;
      o_serial <= '1';
    end loop;

    wait for c_baud_period;
    assert r_chunk = "00001111"
      report "Actual data does not match expected: 00001111"
           & " vs " & to_string(r_chunk)
      severity error;

    -- Trigger reset
    o_reset <= '1';
    wait until rising_edge(r_clock);
    o_reset <= '0';
    wait until rising_edge(r_clock);

    -- Transition to reset
    wait until rising_edge(r_clock);
    assert r_chunk = "00000000"
      report "Actual data does not match expected: 00000000"
           & " vs " & to_string(r_chunk)
      severity error;

    -- Return to idle
    wait until rising_edge(r_clock);
  end procedure;

  procedure test_valid
    parameter (
      signal o_serial: out std_logic;
      i_expected: in std_logic_vector(c_data_width - 1 downto 0)
    ) is
  begin
    -- Idle
    o_serial <= '1';
    wait until rising_edge(r_clock);

    -- Start bit
    o_serial <= '0';

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      o_serial <= i_expected(index);
    end loop;

    -- Stop bits
    for index in 0 to c_stop_width - 1 loop
      wait for c_baud_period;
      o_serial <= '1';
    end loop;

    -- Flush
    wait until rising_edge(r_valid);
    assert i_expected = r_chunk
      report "Actual data does not match expected: "
           & to_string(i_expected) & " vs " & to_string(r_chunk)
      severity error;

    -- Return to idle
    wait until falling_edge(r_valid);
    wait until rising_edge(r_clock);
  end procedure;

  procedure test_error
    parameter (
      signal o_serial: out std_logic;
      i_expected: in std_logic_vector(c_data_width - 1 downto 0)
    ) is
  begin
    -- Idle
    o_serial <= '1';
    wait until rising_edge(r_clock);

    -- Start bit
    o_serial <= '0';

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      o_serial <= i_expected(index);
    end loop;

    -- Stop bit
    wait for c_baud_period;
    o_serial <= '0';

    -- Error
    wait until rising_edge(r_error);
    assert i_expected = r_chunk
      report "Actual data does not match expected: "
           & to_string(i_expected) & " vs " & to_string(r_chunk)
      severity error;

    -- Return to reset
    wait until falling_edge(r_error);
    wait until rising_edge(r_clock);
  end procedure;

begin
  uart_rx_0: entity work.uart_rx
    generic map (
      g_clock_rate => c_clock_rate,
      g_baud_rate => c_baud_rate,
      g_data_width => c_data_width,
      g_stop_width => c_stop_width
    )
    port map (
      i_clock => r_clock,
      i_reset => r_reset,
      i_serial => r_serial,
      o_active => r_active,
      o_valid => r_valid,
      o_error => r_error,
      o_chunk => r_chunk
    );

  r_clock <= not r_clock after c_clock_period / 2;

  process is
  begin
    test_state(r_serial);

    test_reset(r_reset, r_serial);

    test_valid(r_serial, "11111111");
    test_valid(r_serial, "11110000");
    test_valid(r_serial, "00111100");
    test_valid(r_serial, "00001111");
    test_valid(r_serial, "10101010");
    test_valid(r_serial, "01010101");
    test_valid(r_serial, "00000000");

    test_error(r_serial, "01010101");

    std.env.finish;
  end process;

end architecture;
