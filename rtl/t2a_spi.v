/*
eYRC26-27: Logic Quest
Task 2A: SPI Master Module
Description : Parameterizable SPI master controller supporting all 4 SPI
              modes (via CPOL/CPHA), configurable bit order (MSB/LSB
              first), and configurable word length. Derives SCLK by
              dividing down the 50MHz input clock (HALF_PERIOD sets the
              divide ratio). On `start`, shifts tx_data out on MOSI while
              simultaneously shifting MISO into rx_data; `busy` is high
              for the duration and `cs_out` is driven low for the transfer.
Parameters:
  CPOL             - Clock polarity (0: idle low, 1: idle high)        [default: 0]
  CPHA             - Clock phase (0: sample leading edge,
                      1: sample trailing edge)                        [default: 0]
  LSB_FIRST        - Bit order (0: MSB first, 1: LSB first)           [default: 0]
  SPI_WORD_LENGTH  - Number of bits per transfer                      [default: 8]
  HALF_PERIOD      - clk_50MHz cycles per SCLK half-period.
                      SCLK freq = 50MHz / (2 x HALF_PERIOD)           [default: 25 -> 1MHz]
Ports:
  clk_50MHz    (in )  1 bit               - System clock (50MHz)
  rst_n        (in )  1 bit               - Active-low async reset
  start        (in )  1 bit               - Pulse high (sampled in IDLE) to begin transfer
  tx_data      (in )  SPI_WORD_LENGTH     - Data word to transmit on MOSI
  miso_input   (in )  1 bit               - Serial data in from SPI slave
  sclk_out     (out)  1 bit               - SPI serial clock, idles at CPOL
  cs_out       (out)  1 bit               - Chip select, active-low during transfer
  mosi_output  (out)  1 bit               - Serial data out to SPI slave
  rx_data      (out)  SPI_WORD_LENGTH     - Data received from MISO (valid once busy=0)
  busy         (out)  1 bit               - High for the duration of an active transfer
*/

module t2a_spi
#(
    parameter CPOL             = 1'b0,
    parameter CPHA             = 1'b0,
    parameter LSB_FIRST        = 1'b0,
    parameter SPI_WORD_LENGTH  = 8,
    parameter HALF_PERIOD      = 25   // clk_50MHz cycles per half sclk period
)
(
    input wire clk_50MHz,
    input wire rst_n,

    input wire start,
    input wire [SPI_WORD_LENGTH-1:0] tx_data,
    input wire miso_input,

    output reg sclk_out,
    output reg cs_out,
    output reg mosi_output,

    output reg [SPI_WORD_LENGTH-1:0] rx_data,
    output reg busy
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

//try

localparam integer CYCLE_WIDTH =
                    (HALF_PERIOD <= 1) ? 1 : $clog2(HALF_PERIOD + 1);

localparam integer BIT_WIDTH =
                    (SPI_WORD_LENGTH <= 1) ? 1 : $clog2(SPI_WORD_LENGTH);




reg [CYCLE_WIDTH-1:0] cycle_count;

reg [BIT_WIDTH-1:0] bit_count;

reg [SPI_WORD_LENGTH-1:0] tx_shift;
reg [SPI_WORD_LENGTH-1:0] rx_shift;

reg state;

// Indicates that we are waiting for the FIRST SCLK edge.
// The first edge must occur at H+1 because SCLK is registered.
reg first_half;

localparam IDLE     = 1'b0;
localparam TRANSFER = 1'b1;




always @(posedge clk_50MHz or negedge rst_n) begin

    if (!rst_n) begin

        sclk_out    <= CPOL;
        cs_out      <= 1'b1;
        mosi_output <= 1'b0;
        rx_data     <= {SPI_WORD_LENGTH{1'b0}};
        busy        <= 1'b0;

        cycle_count <= {CYCLE_WIDTH{1'b0}};
        bit_count   <= {BIT_WIDTH{1'b0}};

        tx_shift    <= {SPI_WORD_LENGTH{1'b0}};
        rx_shift    <= {SPI_WORD_LENGTH{1'b0}};

        first_half  <= 1'b0;

        state       <= IDLE;

    end

    else begin

        case (state)



            IDLE: begin

                sclk_out    <= CPOL;
                cs_out      <= 1'b1;
                busy        <= 1'b0;

                cycle_count <= {CYCLE_WIDTH{1'b0}};
                bit_count   <= {BIT_WIDTH{1'b0}};

                if (start) begin



                    tx_shift <= tx_data;

                    // Clear receive shift register
                    rx_shift <= {SPI_WORD_LENGTH{1'b0}};


                    cs_out <= 1'b0;
                    busy   <= 1'b1;



                    if (LSB_FIRST)
                        mosi_output <= tx_data[0];
                    else
                        mosi_output <= tx_data[SPI_WORD_LENGTH-1];



                    cycle_count <= {CYCLE_WIDTH{1'b0}};
                    bit_count   <= {BIT_WIDTH{1'b0}};

                    first_half  <= 1'b1;

                    state <= TRANSFER;

                end

            end




            TRANSFER: begin



                if (first_half) begin

                    if (cycle_count == HALF_PERIOD) begin

                        cycle_count <= {CYCLE_WIDTH{1'b0}};

                        first_half <= 1'b0;

                        // Toggle SCLK
                        sclk_out <= ~sclk_out;

                        // For Mode 0 with CPOL=0 this is rising edge
                        if (sclk_out == CPOL) begin

                            // Sample MISO
                            if (LSB_FIRST) begin

                                rx_shift <= {
                                    miso_input,
                                    rx_shift[SPI_WORD_LENGTH-1:1]
                                };

                            end

                            else begin

                                rx_shift <= {
                                    rx_shift[SPI_WORD_LENGTH-2:0],
                                    miso_input
                                };

                            end

                        end

                    end

                    else begin

                        cycle_count <= cycle_count + 1'b1;

                    end

                end




                else begin

                    if (cycle_count == HALF_PERIOD-1) begin

                        cycle_count <= {CYCLE_WIDTH{1'b0}};

                        // Toggle SCLK
                        sclk_out <= ~sclk_out;



                        if (sclk_out == CPOL) begin

                            // Sample MISO on rising edge
                            if (LSB_FIRST) begin

                                rx_shift <= {
                                    miso_input,
                                    rx_shift[SPI_WORD_LENGTH-1:1]
                                };

                            end

                            else begin

                                rx_shift <= {
                                    rx_shift[SPI_WORD_LENGTH-2:0],
                                    miso_input
                                };

                            end

                        end




                        else begin



                            if (bit_count == SPI_WORD_LENGTH-1) begin

                                // Return clock to idle
                                sclk_out <= CPOL;

                                // End transfer
                                cs_out <= 1'b1;
                                busy   <= 1'b0;

                                // rx_shift already contains the
                                // complete received word
                                rx_data <= rx_shift;

                                cycle_count <= {CYCLE_WIDTH{1'b0}};
                                bit_count   <= {BIT_WIDTH{1'b0}};

                                state <= IDLE;

                            end

                            else begin



                                bit_count <= bit_count + 1'b1;

                                if (LSB_FIRST) begin

                                    tx_shift <= {
                                        1'b0,
                                        tx_shift[SPI_WORD_LENGTH-1:1]
                                    };

                                    mosi_output <= tx_shift[1];

                                end

                                else begin

                                    tx_shift <= {
                                        tx_shift[SPI_WORD_LENGTH-2:0],
                                        1'b0
                                    };

                                    mosi_output <=
                                        tx_shift[SPI_WORD_LENGTH-2];

                                end

                            end

                        end

                    end

                    else begin

                        cycle_count <= cycle_count + 1'b1;

                    end

                end

            end




            default: begin

                state <= IDLE;

            end

        endcase

    end

end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule