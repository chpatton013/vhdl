--
-- Generic implementation of a UART TX entity with customizable baud rate,
-- data-bit width, and stop-bit width. This implementation does not use a parity
-- bit, so its use cannot be customized. In addition, this implementation
-- expects to receive little-endian data chunks (LSB-first), and for the idle
-- state on the serial line to be high.
--
-- Generics:
--
-- * g_clock_rate: The clock rate of the domain this entity operates in.
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
-- * i_clock: The unit's clock cycle signal.
-- * i_reset: Reset the state machine.
-- * i_valid: Initiate a byte transfer on `o_serial`.
-- * i_chunk: The data to transfer when `i_valid` goes high.
-- * o_serial: Provide framed data chunks as a series of timed bits.
-- * o_active: Driven high when we are transmitting a data frame.
--
-- Architecture:
--
-- This entity uses a state machine to control its transmission of serial data.
--
--  RESET ---> IDLE ---> START ---> DATA ---> STOP
--              ^                              |
--              '------------------------------'
--
-- RESET: The entity begins in this state. `o_serial` is unset (high impedance)
-- and `o_active` is driven low. If `i_serial` is high, the entity transitions
-- to the IDLE state.
--
-- IDLE: The entity begins in this state. `o_serial` is driven high and
-- `o_active` is driven low. In this state the entity waits for `i_valid`. The
-- entity then transitions to the START state.
--
-- START: In this state the entity sets `o_serial` low and `o_active` high. It
-- waits for the baud-period to pass, then transitions to the DATA state.
--
-- DATA: In this state the entity tracks which bit-index of data it is meant to
-- transfer by counting from `0` to `g_data_width - 1`. The entity reads a bit
-- from the current index of `i_chunk` and writes it to `o_serial`. The entity
-- then waits for the baud-period and increments the bit-index. When the
-- bit-index reaches the last bit in `i_chunk`, the entity transitions to the
-- stop state.
--
-- STOP: In this state the entity sets both `o_serial` and `o_active` high for
-- `g_stop_width` baud-periods, then transitions to the IDLE state.
--
-- Not pictured or described in the above state machine is the use of `i_reset`,
-- which, when driven high, will transition the entity to the RESET state.
--

library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
  generic (
    g_clock_rate: positive;
    g_baud_rate: positive := 9600;
    g_data_width: positive range 5 to 9 := 8;
    g_stop_width: positive range 1 to 2 := 1
  );
  port (
    i_clock: in std_logic := '0';
    i_reset: in std_logic := '0';
    i_valid: in std_logic := '0';
    i_chunk: in std_logic_vector(g_data_width - 1 downto 0) := (others => '0');
    o_serial: out std_logic := 'Z';
    o_active: out std_logic := '0'
  );
end uart_tx;

architecture rtl of uart_tx is
  type t_state is (
    state_reset,
    state_idle,
    state_start,
    state_data,
    state_stop
  );

  constant c_baud_cycles: positive := g_clock_rate / g_baud_rate;

  signal r_state: t_state := state_reset;
  signal r_clock_index: natural := 0;
  signal r_bit_index: natural := 0;
begin
  p_state_machine: process(i_clock)
  begin
    if rising_edge(i_clock) then
      -- Check for our reset input going high early so we can simplify the state
      -- machine implementation below.
      if i_reset = '1' then
        r_state <= state_reset;
      else
        case r_state is
          when state_reset =>
            -- "Clear" our serial output by not driving it at all.
            -- Set our active output low.

            o_serial <= 'Z';
            o_active <= '0';
            r_state <= state_idle;

          when state_idle =>
            -- Set our serial output high and our active output low.
            -- If valid input is high transition to the start state.

            o_serial <= '1';
            o_active <= '0';

            if i_valid = '1' then
              r_clock_index <= 0;
              r_state <= state_start;
            end if;

          when state_start =>
            -- Set our serial output low and our active output high.
            -- Wait until we have sent the start bit.
            -- Transition to the data state.

            o_serial <= '0';
            o_active <= '1';

            if r_clock_index < c_baud_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              r_clock_index <= 0;
              r_bit_index <= 0;
              r_state <= state_data;
            end if;

          when state_data =>
            -- Set our serial output to whatever this bit of the data chunk is.
            -- Set our active output high.
            -- Wait until we have sent this data bit.
            -- If we have send the last data bit, transition to the stop state.

            o_serial <= i_chunk(r_bit_index);
            o_active <= '1';

            if r_clock_index < c_baud_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              r_clock_index <= 0;

              if r_bit_index < g_data_width - 1 then
                r_bit_index <= r_bit_index + 1;
              else
                r_bit_index <= 0;
                r_state <= state_stop;
              end if;
            end if;

          when state_stop =>
            -- Set our serial and active outputs high.
            -- Wait until we have sent all stop bits.
            -- Transition to the idle state.

            o_serial <= '1';
            o_active <= '1';

            if r_clock_index < c_baud_cycles - 1 then
              r_clock_index <= r_clock_index + 1;
            else
              r_clock_index <= 0;

              if r_bit_index < g_stop_width - 1 then
                r_bit_index <= r_bit_index + 1;
              else
                r_bit_index <= 0;
                r_state <= state_idle;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture;
