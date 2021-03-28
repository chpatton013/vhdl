library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_rx_test is end uart_rx_test;

architecture test of uart_rx_test is

  component uart_rx is
    generic (
      g_baud_rate: positive := 9600;
      g_buffer_depth: positive range 2 to 3 := 2;
      g_data_width: positive range 5 to 9 := 8;
      g_stop_width: positive range 1 to 2 := 1;
      g_error_intervals: natural := 4
    );
    port (
      i_clock, i_reset, i_serial: in std_logic;
      o_active, o_valid, o_error: out std_logic;
      o_chunk: out std_logic_vector(g_data_width - 1 downto 0)
    );
  end component;

  constant c_baud_rate: positive := 9600;
  constant c_baud_period: time := 1 sec / c_baud_rate;
  constant c_data_width: positive := 8;
  constant c_stop_width: positive := 1;

  signal r_clock, r_reset, r_serial: std_logic := '0';
  signal r_active, r_valid, r_error: std_logic := '0';
  signal r_chunk: std_logic_vector(c_data_width - 1 downto 0) := (others => '0');

  procedure transmit_valid
    parameter (
      signal o_serial: out std_logic;
      signal i_active, i_valid, i_error: in std_logic;
      signal i_actual_chunk: in std_logic_vector(c_data_width - 1 downto 0);
      i_expected_chunk: in std_logic_vector(c_data_width - 1 downto 0)
    ) is
  begin
    -- Start bit
    assert i_active = '0' report "Active bit is not off before start bit" severity error;
    assert i_valid = '0' report "Valid bit is not off before start bit" severity error;
    assert i_error = '0' report "Error bit is not off before start bit" severity error;
    o_serial <= '0';

    -- Data bits
    for index in 0 to c_data_width - 1 loop
      wait for c_baud_period;
      assert i_active = '1' report "Active bit is not on before data bit" severity error;
      assert i_valid = '0' report "Valid bit is not off before data bit" severity error;
      assert i_error = '0' report "Error bit is not off before data bit" severity error;
      o_serial <= i_expected_chunk(index);
    end loop;

    -- Stop bits
    for index in 0 to c_stop_width - 1 loop
      wait for c_baud_period;
      assert i_active = '1' report "Active bit is not on before stop bit" severity error;
      assert i_valid = '0' report "Valid bit is not off before stop bit" severity error;
      assert i_error = '0' report "Error bit is not off before stop bit" severity error;
      o_serial <= '1';
    end loop;

    -- Flush
    wait until rising_edge(i_valid);
    assert i_active = '0' report "Active bit is not off during flush" severity error;
    assert i_valid = '1' report "Valid bit is not on during flush" severity error;
    assert i_error = '0' report "Error bit is not off during flush" severity error;
    assert i_expected_chunk = i_actual_chunk
      report "Actual data does not match expected: "
           & to_string(i_expected_chunk) & " vs " & to_string(i_actual_chunk)
      severity error;

    -- Return to idle
    wait until falling_edge(i_valid);
    wait until rising_edge(r_clock);
  end procedure;

begin
  uart_rx_0: uart_rx
    generic map (
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

  -- TODO: add some framing error test cases as well
  -- TODO: add some reset test cases as well
  process is
  begin
    r_serial <= '1';
    wait for c_baud_period;

    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "00000000");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "11111111");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "01010101");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "10101010");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "00001111");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "00111100");
    transmit_valid(r_serial, r_active, r_valid, r_error, r_chunk, "11110000");

    std.env.finish;
  end process;

end architecture;
