library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_test is end uart_test;

architecture test of uart_test is

  constant c_baud_rate: positive := 9600;
  constant c_baud_period: time := 1 sec / c_baud_rate;
  constant c_data_width: positive := 8;
  constant c_stop_width: positive := 1;
  constant c_buffer_depth: positive := 2;

  signal r_clock, r_reset, r_serial: std_logic := '0';
  signal r_rx_active, r_rx_valid, r_rx_error: std_logic := '0';
  signal r_tx_active, r_tx_valid: std_logic := '0';
  signal r_rx_chunk, r_tx_chunk: std_logic_vector(c_data_width - 1 downto 0) := (others => '0');

begin
  uart_0: entity work.uart
    generic map (
      g_clock_rate => c_clock_rate,
      g_baud_rate => c_baud_rate,
      g_data_width => c_data_width,
      g_stop_width => c_stop_width,
      g_buffer_depth => c_buffer_depth
    )
    port map (
      i_clock => r_clock,
      i_reset => r_reset,
      i_rx_serial => r_serial,
      o_rx_active => r_rx_active,
      o_rx_valid => r_rx_valid,
      o_rx_error => r_rx_error,
      o_rx_chunk => r_rx_chunk,
      i_tx_valid => r_tx_valid,
      i_tx_chunk => r_tx_chunk,
      o_tx_serial => r_serial,
      o_tx_active => r_tx_active
    );

  r_clock <= not r_clock after c_clock_period / 2;

  process is
  begin
    -- Wait for tx to enter the IDLE state.
    while (r_serial /= '1') loop
      wait until rising_edge(r_clock);
    end loop;
    -- Wait for rx to enter the IDLE state.
    wait until rising_edge(r_clock);

    -- Load data into tx.
    r_tx_chunk <= "01010101";
    r_tx_valid <= '1';
    wait until rising_edge(r_clock);
    r_tx_valid <= '0';

    -- Wait for rx to yield the received data.
    wait until rising_edge(r_rx_valid);
    assert r_rx_chunk = r_tx_chunk
      report "Received chunk does not match transmitted chunk: "
           & to_string(r_rx_chunk) & " vs " & to_string(r_tx_chunk)
      severity error;

    std.env.finish;
  end process;

end architecture;
