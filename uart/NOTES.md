[UART for Dummies](https://learn.sparkfun.com/tutorials/serial-communication/all)

Choosing the number of stop bits
* [tl;dr: default to 1](https://electronics.stackexchange.com/a/335699)
* [2 might be chosen for some reasons](https://electronics.stackexchange.com/a/29954)
  * intentionally slow-down data transfer rate to prevent the need to drop to next-lowest baud rate
  * inconsistent clock-rates can be accounted for by setting TX to 2 and RX to 1
  * similarly, long cable runs induce odd rise/fall times, so TX 2 and RX 1 can mitigate

Verifying data
* parity isn't really used any more because it can't find an even-number of bit flips
* instead people use CRC or [Fletcher-16/32/64](https://en.wikipedia.org/wiki/Fletcher%27s_checksum)

Variables
* baud rate (9600, 19200, 38400, 57600, and 115200) [115200]
* chunk width (5 - 9) [8]
* parity bit (Y/N) [N]
* stop bit count (1, 2) [1]
* endianness (LE/BE) [LE]

LE assumed, protocols described as "${BAUD} ${WIDTH}${PARITY}${STOP}"
* Examples: 9600 8N1, 115200 8N1



If we ignore parity completely then we can boil the hardware down to a generic interface:
* `clock_rate`
* `baud_rate`
* `data_width`
* `stop_width`

We also want to do some data verification when we receive data and encode checksums when we send
data.

Ribbon Cable:
  0: chassis ground
  1: signal ground
  2: TX data
  3: TX ready
  4: RX data
  5: RX ready
This will require [2:3] and [4:5] to crossover, or for some sort of auto-negotiation policy based on
if the lines are already high when you start listening.

State Machine:
* Inactive -> Negotiating
* Negotiating -> Inactive
* Negotiating -> Listening
* Listening -> Listening

Probably just going to do a crossover. And not sure that I want to worry about ready wires.

Need to decide on a message protocol:
* Ready for next message heartbeat [00000000]
* Resend last message              [01010101]
* Data message                     [10000000|LLLLLLLL|D..L..D|CCCCCCCC|CCCCCCCC]
  * Use LSB to signal that there's real data here
  * Use next byte to describe the payload length in bytes
  * Use next L bytes for payload
  * Use next 2 bytes for Fletcher-16 checksum

Receiver -- rx[0:7] --> Message[Length|Data|Checksum]
               \                               |
                \                              v
                 \-----> Checksum ----------> XOR -- !0x00 --> TX request resend
                                               |
                                              0x00
                                               |
                                               V
                                       Add to Message Buffer
                                               |
                                               V
                            Message Ready + Buffer Index + Message Size
