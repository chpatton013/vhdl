--
-- Generic implementation of a UART RX/TX entity with customizable baud rate,
-- data-bit width, and stop-bit width. This implementation does not use a parity
-- bit, so its use cannot be customized. In addition, this implementation
-- expects to receive little-endian data chunks (LSB-first), and for the idle
-- state on the serial line to be high.
--
-- Generics:
--
-- * g_baud_rate: Standard baud rates are 110, 300, 600, 1200, 2400, 4800, 9600,
--   14400, 19200, 38400, 57600, 115200, 128000 and 256000 bits per second. By
--   default, 9600 is commonly chosen for low-speed applications. Higher speeds
--   may safely be used depending on the capabilities of your hardware.
-- * g_data_width: Data-bit widths from 5 to 9 are valid, however 8 is the
--   standard default.
-- * g_stop_width: Stop-bit widths may be 1 or 2, however 1 is the standard
--   default.
--
-- Ports:
--
-- * i_clock and i_reset: Shared between the RX and TX entity.
-- * i_rx_*: Inputs to the RX component.
-- * o_rx_*: Outputs of the RX component.
-- * i_tx_*: Inputs to the TX component.
-- * o_tx_*: Outputs of the TX component.
--
-- Refer to the RX and TX files for information about their implementations.
--

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
begin

  rx: entity work.uart_rx
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

  tx: entity work.uart_tx
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
