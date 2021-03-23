ENTITY adder IS
  PORT (
    lhs: IN BIT;
    rhs: IN BIT;
    carry_in: IN BIT;
    sum: OUT BIT;
    carry_out: OUT BIT
  );
END adder;

ARCHITECTURE impl OF adder IS
BEGIN
  sum <= lhs xor rhs xor carry_in;
  carry_out <= (lhs AND rhs) or (lhs AND carry_in) or (rhs AND carry_in);
END ARCHITECTURE impl;
