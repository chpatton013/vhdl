--
-- Generic implementation of a UART RX entity with customizable baud rate,
-- data-bit width, stop-bit width, and number of baud intervals to wait in the
-- event of a framing error. This implementation does not use a parity bit, so
-- its use cannot be customized. In addition, this implementation expects to
-- receive little-endian data chunks (LSB-first), and for the idle state on the
-- serial line to be high.
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
-- * g_error_intervals: Number of baud-periods to wait after a data framing
--   error before accepting new data. The standard default is 4.
--
-- Ports:
--
-- * i_clock: The unit's clock cycle signal.
-- * i_reset: Reset the state machine and clear the serial buffer.
-- * i_ready: Notify the sender that we are ready to receive data.
-- * i_serial: Provide framed data chunks as a series of timed bits.
-- * o_ready: Driven high when we are ready to receive data.
-- * o_valid: Driven high for one cycle when o_chunk is populated.
-- * o_chunk: Contains data extracted from the serial frame.
--
-- Architecture:
--
-- This entity uses a state machine to control its consumption of serial data.
--
--  RESET ---> IDLE ---> START ---> DATA ---> STOP ---> ERROR
--    ^         ^                              |          |
--    |         '----------- FLUSH <-----------'          |
--    '---------------------------------------------------'
--
-- RESET: The entity begins in this state. `o_ready`, `o_valid`, and `o_chunk`
-- are all driven low. If `i_reset` is low and `i_serial` are high, the entity
-- transitions to the IDLE state.
--
-- IDLE: `o_valid` and `o_chunk` are all driven low. If `i_ready` is high then
-- `o_ready` is driven high; otherwise it is driven low. In this state the
-- entity waits for the start bit, which is indicated by `i_serial` being driven
-- low. The entity then transitions to the START state.
--
-- START: In this state the entity waits for the baud-period/2 time, then
-- re-samples `i_serial`. If `i_serial` is still low, transition to the DATA
-- state. Otherwise, transition back to the IDLE state.
--
-- DATA: In this state the entity waits for the baud-period before sampling
-- `i_serial` for `g_data_width` iterations. The value of `i_serial` at each of
-- these intervals is written to sequential elements of `o_chunk`. After the
-- last data bit has been read the entity transitions to the STOP state.
--
-- STOP: In this state the entity waits for the baud-period before sampling
-- `i_serial` for `g_stop_width` iterations. The value of `i_serial` at each of
-- these intervals is expected to be low. If it is low for all of the expected
-- stop bits the entity transitions to the FLUSH state. If it is not low for all
-- of the expected stop bits the entity transitions to the ERROR state.
--
-- FLUSH: `o_ready` is driven low and `o_valid` is driven high. The entity then
-- transitions to the IDLE state.
--
-- ERROR: `o_ready` and `o_valid` are driven low. The entity then waits for
-- `g_error_intervals` multiples of the baud-period, then transitions to the
-- RESET state.
--
-- Not pictured or described in the above state machine is the use of `i_reset`,
-- which, when driven high, will transition the entity to the RESET state.
--

library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_rx is
  generic (
    g_baud_rate: natural := 9600;
    g_data_width: natural range 5 to 9 := 8;
    g_stop_width: natural range 1 to 2 := 1;
    g_error_intervals: natural := 4
  );
  port (
    i_clock: in std_logic;
    i_reset: in std_logic;
    i_ready: in std_logic;
    i_serial: in std_logic;
    o_ready: out std_logic;
    o_valid: out std_logic;
    o_chunk: out std_logic_vector(7 downto 0)
  );
end uart_rx;

architecture rtl of uart_rx is
  type t_state is (
    state_reset,
    state_idle,
    state_start,
    state_data,
    state_stop,
    state_flush,
    state_error
  );

  constant c_baud_cycles: natural := c_clock_rate / g_baud_rate;
  constant c_start_cycles: natural := c_baud_cycles / 2;
  constant c_error_cycles: natural := c_baud_cycles * g_error_intervals;

  signal r_state: t_state := state_reset;
  signal r_start_clock_index: natural range 0 to c_start_cycles - 1 := 0;
  signal r_baud_clock_index: natural range 0 to c_baud_cycles - 1 := 0;
  signal r_error_clock_index: natural range 0 to c_error_cycles - 1 := 0;
  signal r_data_bit_index: natural range 0 to g_data_width - 1 := 0;
  signal r_stop_bit_index: natural range 0 to g_stop_width - 1 := 0;
begin
  p_state_machine: process(i_clock)
    variable v_state: t_state := r_state;
  begin
    if rising_edge(i_clock) then
      -- Check for our reset input going high early so we can simplify the state
      -- machine implementation below.
      if i_reset = '1' then
        v_state := state_reset;
      end if;

      case v_state is
        when state_reset =>
          -- Zero all of our outputs and registers.
          -- Transition to the idle state if our reset input is low and our
          -- serial input is high.

          o_ready <= '0';
          o_valid <= '0';
          o_chunk <= (others => '0');

          r_start_clock_index <= 0;
          r_baud_clock_index <= 0;
          r_error_clock_index <= 0;
          r_data_bit_index <= 0;
          r_stop_bit_index <= 0;

          if i_reset /= '1' and i_serial = '1' then
            v_state := state_idle;
          end if;

        when state_idle =>
          -- Set our ready output and zero our valid and chunk outputs.
          -- If our serial input has gone low we may have a start bit incoming.
          -- Transition to the start state to find out.

          o_ready <= i_ready;
          o_valid <= '0';
          o_chunk <= (others => '0');

          if i_serial = '0' then
            v_state := state_start;
          end if;

        when state_start =>
          -- Set our ready output high.
          -- Walk forward to the middle of the start bit.
          -- If the serial line is still showing the start bit we are ready to
          -- start reading data.
          -- Otherwise, it was just noise and we should return to the idle
          -- state.

          o_ready <= '1';

          if r_start_clock_index < c_start_cycles - 1 then
            r_start_clock_index <= r_start_clock_index + 1;
          else
            if i_serial = '0' then
              r_start_clock_index <= 0;
              r_data_bit_index <= 0;
              v_state := state_data;
            else
              v_state := state_idle;
            end if;
          end if;

        when state_data =>
          -- Set our ready output high.
          -- Walk forward to the middle of the next data bit.
          -- Record the value on the serial input in the appropriate bit of the chunk output.
          -- If we have recorded the last data bit transition to the stop state.

          o_ready <= '1';

          if r_baud_clock_index < c_baud_cycles - 1 then
            r_baud_clock_index <= r_baud_clock_index + 1;
          else
            r_baud_clock_index <= 0;
            o_chunk(r_data_bit_index) <= i_serial;

            if r_data_bit_index < g_data_width - 1 then
              r_data_bit_index <= r_data_bit_index + 1;
            else
              r_data_bit_index <= 0;
              v_state := state_stop;
            end if;
          end if;

        when state_stop =>
          -- Set our ready output high.
          -- Walk forward to the middle of the next stop bit.
          -- Sample the value on the serial input. If the value is not low for
          -- any stop bit, transition to the stop state. If we have sampled the
          -- last stop bit transition to the flush state.

          o_ready <= '1';

          if r_baud_clock_index < c_baud_cycles - 1 then
            r_baud_clock_index <= r_baud_clock_index + 1;
          else
            r_baud_clock_index <= 0;

            if i_serial /= '1' then
              v_state := state_error;
            else
              if r_stop_bit_index < g_stop_width - 1 then
                r_stop_bit_index <= r_stop_bit_index + 1;
              else
                r_stop_bit_index <= 0;
                v_state := state_flush;
              end if;
            end if;
          end if;

        when state_flush =>
          -- Set our ready output low, but our valid output high.
          -- Transition to the idle state.

          o_ready <= '0';
          o_valid <= '1';
          v_state := state_idle;

        when state_error =>
          -- Set our ready and valid outputs low.
          -- Walk forward to the end of error period, then transition to the
          -- idle state.

          o_ready <= '0';
          o_valid <= '0';

          if r_error_clock_index < c_error_cycles - 1 then
            r_error_clock_index <= r_error_clock_index + 1;
          else
            r_error_clock_index <= 0;
            v_state := state_reset;
          end if;

      end case;

      r_state <= v_state;
    end if;
  end process p_state_machine;
end architecture rtl;
