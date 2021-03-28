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
-- * i_serial: Provide framed data chunks as a series of timed bits.
-- * o_active: Driven high when we are receiving data.
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
-- RESET: The entity begins in this state. `o_active`, `o_valid`, and `o_chunk`
-- are all driven low. If `i_reset` is low and `i_serial` are high, the entity
-- transitions to the IDLE state.
--
-- IDLE: `o_active`, `o_valid` and `o_chunk` are all driven low. In this state
-- the entity waits for the start bit, which is indicated by `i_serial` being
-- driven low. The entity then transitions to the START state.
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
-- FLUSH: `o_active` is driven low and `o_valid` is driven high. The entity then
-- transitions to the IDLE state.
--
-- ERROR: `o_active` and `o_valid` are driven low and `o_error` is driven high.
-- The entity then waits for `g_error_intervals` multiples of the baud-period,
-- then transitions to the RESET state.
--
-- Not pictured or described in the above state machine is the use of `i_reset`,
-- which, when driven high, will transition the entity to the RESET state.
--

library ieee;
use ieee.std_logic_1164.all;

use work.common.all;

entity uart_rx is
  generic (
    g_baud_rate: positive := 9600;
    g_buffer_depth: positive range 2 to 3 := 2;
    g_data_width: positive range 5 to 9 := 8;
    g_stop_width: positive range 1 to 2 := 1;
    g_error_intervals: natural := 4
  );
  port (
    i_clock: in std_logic := '0';
    i_reset: in std_logic := '0';
    i_serial: in std_logic := '0';
    o_active: out std_logic := '0';
    o_valid: out std_logic := '0';
    o_error: out std_logic := '0';
    o_chunk: out std_logic_vector(g_data_width - 1 downto 0) := (others => '0')
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

  constant c_baud_cycles: positive := c_clock_rate / g_baud_rate;
  constant c_start_cycles: positive := c_baud_cycles / 2;
  constant c_error_cycles: positive := c_baud_cycles * g_error_intervals;

  signal r_state: t_state := state_reset;
  signal r_serial: std_logic_vector(g_buffer_depth - 1 downto 0) := (others => '0');
  signal r_clock_index: natural := 0;
  signal r_bit_index: natural := 0;

  procedure do_reset
    parameter (
      signal o_active, o_valid, o_error: out std_logic;
      signal o_chunk: out std_logic_vector(g_data_width - 1 downto 0);
      signal r_state: out t_state;
      signal r_clock_index, r_bit_index: out natural
    ) is
  begin
    o_active <= '0';
    o_valid <= '0';
    o_error <= '0';
    o_chunk <= (others => '0');

    r_state <= state_reset;
    r_clock_index <= 0;
    r_bit_index <= 0;
  end procedure;
begin
  -- Buffer incoming serial signals through a series of dff's to allow
  -- metastability events to resolve.
  p_stabilize_serial: process(i_clock)
  begin
    if rising_edge(i_clock) then
      r_serial(g_buffer_depth - 2 downto 0) <= r_serial(g_buffer_depth - 1 downto 1);
      r_serial(g_buffer_depth - 1) <= i_serial;
      -- report to_string(r_serial);
    end if;
  end process;

  -- Use incoming serial data to progress through the entity state machine.
  p_state_machine: process(i_clock)
  begin
    if rising_edge(i_clock) then
      -- Check for our reset input going high early so we can simplify the state
      -- machine implementation below.
      if i_reset = '1' then
        report "RESET";
        do_reset(
          o_active, o_valid, o_error, o_chunk,
          r_state, r_clock_index, r_bit_index
        );
        r_serial <= (others => '0');
      else
        case r_state is
          when state_reset =>
            -- Reset all outputs and registers.
            -- Transition to the idle state if the serial line is high.

            do_reset(
              o_active, o_valid, o_error, o_chunk,
              r_state, r_clock_index, r_bit_index
            );

            if r_serial(0) = '1' then
              r_state <= state_idle;
              report "RESET -> IDLE";
            end if;

          when state_idle =>
            -- Set our active, valid, and error outputs low.
            -- If our serial input has gone low we may have a start bit incoming.
            -- Transition to the start state to find out.

            o_active <= '0';
            o_valid <= '0';
            o_error <= '0';

            if r_serial(0) = '0' then
              r_clock_index <= 0;
              r_state <= state_start;
              report "IDLE -> START";
            end if;

          when state_start =>
            -- Set our active output high.
            -- Set our valid and error outputs low.
            -- Walk forward to the middle of the start bit.
            -- If the serial line is still showing the start bit we are ready to
            -- start reading data.
            -- Otherwise, it was just noise and we should return to the idle
            -- state.

            o_active <= '1';
            o_valid <= '0';
            o_error <= '0';

            if r_clock_index < c_start_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              if r_serial(0) = '0' then
                r_clock_index <= 0;
                r_bit_index <= 0;
                r_state <= state_data;
                report "START -> DATA";
              else
                r_state <= state_idle;
                report "START -> IDLE";
              end if;
            end if;

          when state_data =>
            -- Set our active output high.
            -- Set our valid and error outputs low.
            -- Walk forward to the middle of the next data bit.
            -- Record the value on the serial input in the appropriate bit of the chunk output.
            -- If we have recorded the last data bit transition to the stop state.

            o_active <= '1';
            o_valid <= '0';
            o_error <= '0';

            if r_clock_index < c_baud_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              o_chunk(r_bit_index) <= r_serial(0);

              if r_bit_index < g_data_width - 1 then
                r_bit_index <= r_bit_index + 1;
              else
                r_clock_index <= 0;
                r_bit_index <= 0;
                r_state <= state_stop;
                report "DATA -> STOP";
              end if;
            end if;

          when state_stop =>
            -- Set our active output high.
            -- Set our valid and error outputs low.
            -- Walk forward to the middle of the next stop bit.
            -- Sample the value on the serial input. If the value is not low for
            -- any stop bit, transition to the stop state. If we have sampled the
            -- last stop bit transition to the flush state.

            o_active <= '1';
            o_valid <= '0';
            o_error <= '0';

            if r_clock_index < c_baud_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              r_clock_index <= 0;

              if r_serial(0) /= '1' then
                r_clock_index <= 0;
                r_state <= state_error;
                report "STOP -> ERROR";
              else
                if r_bit_index < g_stop_width - 1 then
                  r_bit_index <= r_bit_index + 1;
                else
                  r_state <= state_flush;
                  report "STOP -> FLUSH";
                end if;
              end if;
            end if;

          when state_flush =>
            -- Set our active output low, but our valid output high.
            -- Transition to the idle state.

            o_active <= '0';
            o_valid <= '1';
            o_error <= '0';
            r_state <= state_idle;
            report "FLUSH -> IDLE";

          when state_error =>
            -- Set our active and valid outputs low.
            -- Set our error bit high.
            -- Walk forward to the end of error period, then transition to the
            -- idle state.

            o_active <= '0';
            o_valid <= '0';
            o_error <= '1';

            if r_clock_index < c_error_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              r_serial <= (others => '0');
              r_state <= state_reset;
              report "ERROR -> RESET";
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture;
