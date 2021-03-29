library ieee;
use ieee.std_logic_1164.all;

entity uart is
  generic (
    g_clock_rate: positive;
    g_baud_rate: positive := 9600;
    g_data_width: positive range 5 to 9 := 8;
    g_stop_width: positive range 1 to 2 := 1
  );
  port (
    i_clock: in std_logic := '0';
    i_reset: in std_logic := '0';
    i_rx_serial: in std_logic := '0';
    o_rx_active: out std_logic := '0';
    o_rx_valid: out std_logic := '0';
    o_rx_error: out std_logic := '0';
    o_rx_chunk: out std_logic_vector(g_data_width - 1 downto 0) := (others => '0');
    i_tx_valid: in std_logic := '0';
    i_tx_chunk: in std_logic_vector(g_data_width - 1 downto 0) := (others => '0');
    o_tx_serial: out std_logic := '0';
    o_tx_active: out std_logic := '0'
  );
end uart;

architecture rtl of uart is

  component uart_rx is
    generic (
      g_clock_rate, g_baud_rate, g_data_width, g_stop_width: positive
    );
    port (
      i_clock, i_reset, i_serial: in std_logic := '0';
      o_active, o_valid, o_error: out std_logic := '0';
      o_chunk: out std_logic_vector(g_data_width - 1 downto 0) := (others => '0')
    );
  end component;

  component uart_tx is
    generic (
      g_clock_rate, g_baud_rate, g_data_width, g_stop_width: positive
    );
    port (
      i_clock, i_reset, i_valid: in std_logic := '0';
      i_chunk: in std_logic_vector(g_data_width - 1 downto 0) := (others => '0');
      o_serial, o_active: out std_logic := '0'
    );
  end component;

begin

  rx: uart_rx
    generic map (
      g_clock_rate => g_clock_rate,
      g_baud_rate => g_baud_rate,
      g_data_width => g_data_width,
      g_stop_width => g_stop_width
    )
    port map (
      i_clock => i_clock,
      i_reset => i_reset,
      i_serial => i_rx_serial,
      o_active => o_rx_active,
      o_valid => o_rx_valid,
      o_error => o_rx_error,
      o_chunk => o_rx_chunk
    );

  tx: uart_tx
    generic map (
      g_clock_rate => g_clock_rate,
      g_baud_rate => g_baud_rate,
      g_data_width => g_data_width,
      g_stop_width => g_stop_width
    )
    port map (
      i_clock => i_clock,
      i_reset => i_reset,
      i_valid => i_tx_valid,
      i_chunk => i_tx_chunk,
      o_serial => o_tx_serial,
      o_active => o_tx_active
    );

end architecture;
