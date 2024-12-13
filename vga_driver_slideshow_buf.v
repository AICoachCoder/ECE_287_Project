module vga_driver_slideshow_buf (
    input CLOCK_50,
    input [3:0] KEY,
    input [9:0] SW,
    output [9:0] LEDR,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,
    output VGA_HS,
    output VGA_VS,
    output VGA_CLK,
    output VGA_SYNC_N,
    output VGA_BLANK_N
);

// Parameters
parameter NUM_IMAGES = 4;  // Number of images in the slideshow
parameter H_VISIBLE_AREA = 640;
parameter H_FRONT_PORCH = 16;
parameter H_SYNC_PULSE = 96;
parameter H_BACK_PORCH = 48;
parameter H_TOTAL = H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

parameter V_VISIBLE_AREA = 480;
parameter V_FRONT_PORCH = 10;
parameter V_SYNC_PULSE = 2;
parameter V_BACK_PORCH = 33;
parameter V_TOTAL = V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

// Registers and Wires
reg [1:0] current_image = 0;  // Tracks the current image index
reg [9:0] pixel_data;         // Pixel data to VGA
reg [9:0] image_buffers[NUM_IMAGES-1:0]; // Frame buffers for images
reg [9:0] h_counter = 0;
reg [9:0] v_counter = 0;
reg pixel_clock = 0;
reg [19:0] debounce_counter = 0;
reg button_debounced = 0;

// Initialization logic for image buffers
initial begin
    image_buffers[0] = 10'h3FF; // Image 1: white
    image_buffers[1] = 10'h0C0; // Image 2: green
    image_buffers[2] = 10'h00F; // Image 3: blue
    image_buffers[3] = 10'h300; // Image 4: red
end

// Generate pixel clock (25 MHz)
always @(posedge CLOCK_50) begin
    pixel_clock <= ~pixel_clock;
end

// Horizontal and Vertical Counters
always @(posedge pixel_clock) begin
    if (h_counter == H_TOTAL - 1) begin
        h_counter <= 0;
        if (v_counter == V_TOTAL - 1)
            v_counter <= 0;
        else
            v_counter <= v_counter + 1;
    end else begin
        h_counter <= h_counter + 1;
    end
end

// Sync signals
assign VGA_HS = ~(h_counter >= H_VISIBLE_AREA + H_FRONT_PORCH && h_counter < H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE);
assign VGA_VS = ~(v_counter >= V_VISIBLE_AREA + V_FRONT_PORCH && v_counter < V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE);

// Display active area
wire display_active = (h_counter < H_VISIBLE_AREA) && (v_counter < V_VISIBLE_AREA);

// Button debounce logic
always @(posedge CLOCK_50) begin
    if (!KEY[1] || !KEY[2]) begin
        if (debounce_counter < 20'd1000000) begin // Debounce period (~20 ms at 50 MHz)
            debounce_counter <= debounce_counter + 1;
        end else begin
            button_debounced <= 1;
        end
    end else begin
        debounce_counter <= 0;
        button_debounced <= 0;
    end
end

// Update current image index based on debounced button presses
always @(posedge CLOCK_50) begin
    if (button_debounced && !KEY[1]) begin
        // Next image
        if (current_image < NUM_IMAGES - 1)
            current_image <= current_image + 1;
        else
            current_image <= 0; // Loop back to the first image
    end else if (button_debounced && !KEY[2]) begin
        // Previous image
        if (current_image > 0)
            current_image <= current_image - 1;
        else
            current_image <= NUM_IMAGES - 1; // Loop back to the last image
    end
end

// Output the current image to VGA
always @(posedge CLOCK_50) begin
    pixel_data <= image_buffers[current_image];
end

// VGA output logic
assign VGA_R = display_active ? {pixel_data[9:8], 6'b0} : 8'b0;
assign VGA_G = display_active ? {pixel_data[7:6], 6'b0} : 8'b0;
assign VGA_B = display_active ? {pixel_data[5:4], 6'b0} : 8'b0;
assign VGA_CLK = pixel_clock;
assign VGA_SYNC_N = 1'b0;
assign VGA_BLANK_N = display_active;

endmodule

