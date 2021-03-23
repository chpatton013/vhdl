ENTITY adder_tb IS END adder_tb;

ARCHITECTURE impl OF adder_tb IS
  COMPONENT adder
    PORT (
      lhs: IN BIT;
      rhs: IN BIT;
      carry_in: IN BIT;
      sum: OUT BIT;
      carry_out: OUT BIT
    );
  END COMPONENT;

  FOR adder_0: adder USE ENTITY work.adder;
  SIGNAL lhs, rhs, carry_in, sum, carry_out: BIT;
BEGIN
  adder_0: adder PORT MAP (
    lhs => lhs,
    rhs => rhs,
    carry_in => carry_in,
    sum => sum,
    carry_out => carry_out
  );

  PROCESS
    TYPE pattern_type IS RECORD
      lhs, rhs, carry_in: BIT;
      sum, carry_out: BIT;
    END RECORD;

    TYPE pattern_array IS ARRAY (NATURAL RANGE <>) OF pattern_type;
    CONSTANT patterns: pattern_array := (
      ('0', '0', '0', '0', '0'),
      ('0', '0', '1', '1', '0'),
      ('0', '1', '0', '1', '0'),
      ('0', '1', '1', '0', '1'),
      ('1', '0', '0', '1', '0'),
      ('1', '0', '1', '0', '1'),
      ('1', '1', '0', '0', '1'),
      ('1', '1', '1', '1', '1')
    );
  BEGIN
    FOR index in patterns'RANGE LOOP
      lhs <= patterns(index).lhs;
      rhs <= patterns(index).rhs;
      carry_in <= patterns(index).carry_in;

      WAIT FOR 1 ns;

      ASSERT sum = patterns(index).sum
        REPORT "bad sum value" SEVERITY ERROR;
      ASSERT carry_out = patterns(index).carry_out
        REPORT "bad carry out value" SEVERITY ERROR;
    END LOOP;

    ASSERT false REPORT "end of test" SEVERITY NOTE;
    WAIT;
  END PROCESS;
END ARCHITECTURE Impl;
