
// Top-level module that doesn't do anything useful
module test (clk, led, scl, sda);
	input clk;
	output led;
	input scl;
	inout sda;
	wire [15:0] brightness;

	pwm16 led_pwm(clk, brightness, led);
	i2c_slave led_i2c(clk, scl, sda, brightness);
endmodule

// A simple 16-bit pulse width modulation module
module pwm16 (clk, duty_cycle, out);
	input clk;
	input [15:0] duty_cycle;
	output out;
	reg out;
	reg [16:0] pwmreg;
	
	always @(posedge clk)
		if (pwmreg < 17'h10000)
			pwmreg <= pwmreg + 1;
		else
			pwmreg <= 0;

	always @(posedge clk)
		out <= ( {1'b0, duty_cycle} < pwmreg );		
endmodule	

// A state machine implementing a simple I2C slave, that responds
// to one address and stores writes to an output register.
module i2c_slave (clk, scl, sda, out);
	parameter OUT_BYTES   = 2;
	parameter I2C_ADDRESS = 7'h42; 

	input clk;
	input scl;
	inout sda;
	output [OUT_BYTES*8-1:0] out;

	reg [OUT_BYTES*8-1:0] out;
	reg [(OUT_BYTES+1)*8-1:0] shifter;	// Space for output plus our address
	reg [3:0] bit_count;			// The bit within one byte. 8==ACK
	reg [1:0] byte_count;

endmodule

// Convert I2C to a parallel protocol consisting of strobed 8-bit bytes,
// and separate signals indicating start and stop conditions
module i2c_slave_serializer (clk, scl, sda, start, stop, write_data, wr);
	input clk;
	input scl;
	inout sda;
	
	// All outputs are registered
	output [7:0] write_data;
	reg [7:0] write_data;
	output wr;
	reg wr;
	output start;
	reg start;
	output stop;
	reg stop;

	reg [3:0] bit_count;
	
	// Imply an open-collector driver for SDA
	reg sda_out;
	assign sda = sda_out ? 1'bz : 1'b0;	

	// States, one-hot encoding
	reg [2:0] state;
	parameter
		S_WAIT_FOR_START = 0,
		S_WAIT_FOR_SCL_LOW = 1,
		S_WAIT_FOR_SCL_HIGH = 2;
	
	// SDA edge detection
	reg prev_sda;
	always @(posedge clk)
		prev_sda <= sda;
	
	always @(posedge clk) case (state)

		S_WAIT_FOR_START: begin
			// Ignore SCL. If SDA falls, we're in a start condition.
			sda_out <= 1;
			write_data <= 0;
			wr <= 0;
			stop <= 0;
			bit_count <= 0;

			if ((!sda) && prev_sda) begin
				// A start condition. Note it and wait for SCL to go low
				state <= S_WAIT_FOR_SCL_LOW;
				start <= 1;
			end
			else begin
				// No start condition yet...
				start <= 0;
			end
		end
		
		S_WAIT_FOR_SCL_LOW: begin
			// SCL is high. If we see it fall, time for another bit.
			// If SDA goes high, this is a stop condition and we go back
			// to S_WAIT_FOR_START after latching the latest data.
			wr <= 0;
			start <= 0;
			
			if (!scl) begin
				// Another data bit
				state <= S_WAIT_FOR_SCL_HIGH;
				stop <= 0;	
			end
			else if (sda && (!prev_sda)) begin
				// Stop condition
				stop <= 1;
				state <= S_WAIT_FOR_START;
			end
		end
		
		S_WAIT_FOR_SCL_HIGH: begin
			// SCL is low. When it goes high, another data bit will have been
			// clocked in. If it's a normal bit, store it- if it's an ACK,
			// pull SDA low.
			if (scl) begin
				// Is this an ACK bit (bit 8) or a normal bit?
				if (bit_count == 8) begin
					// ACK byte. Strobe the data byte we just received.
					bit_count <= 0;
					sda_out <= 0;
					wr <= 1;
				end
				else begin
					// Normal bit
					bit_count <= bit_count + 1;
					sda_out <= 1;
					wr <= 0;
					
					// Sample a bit from SDA into our big shift register
					write_data <= { write_data[6:0], sda };
				end
				state <= S_WAIT_FOR_SCL_LOW;
			end
			else begin
				sda_out <= 1;
				wr <= 0;
			end
		end
		
	endcase	
endmodule
	
	
