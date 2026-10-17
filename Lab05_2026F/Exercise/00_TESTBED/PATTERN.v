//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2026 Fall
//   Lab05 Exercise		: JPEG-Like image compression ENCorder (JPEGLENC)
//   Author     		: Yu-Yang Tang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : PATTERN.v
//   Module Name : PATTERN
//   Release version : V1.0 (Release Date: 2026-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
`timescale 1ns/10ps

`ifdef RTL
    `define CYCLE_TIME 20
`endif
`ifdef GATE
    `define CYCLE_TIME 20
`endif
`ifdef POST
    `define CYCLE_TIME 20
`endif

`include "Utility.v"
`include "JPEG_Utility.v"

module PATTERN(
    // output signals
    clk,
    rst_n,
    in_valid,
    in_data,

    // input signals
    out_valid,
    out_data
);

// ===============================================================
// I/O declaration
// ===============================================================
output reg          clk;
output reg          rst_n;
output reg          in_valid;
output reg  [7:0]   in_data;

input               out_valid;
input       [7:0]   out_data;

//=====================================================================
// Simulation Configuration
//=====================================================================

// >>>>> User Configuration
// Parameters in this section can be modified by the user.

// Number of pattern cases to execute in total.
integer TOTAL_PATNUM = 1000;

// Number of simple pattern cases to execute.
integer SIMPLE_PATNUM = 100;
parameter SIMPLE_INPUT_MIN = 0;
parameter SIMPLE_INPUT_MAX = 10;

// Random seed used for pattern generation.
integer SEED = 5487;
parameter DEBUG = 1;

// Range of simple pattern generated input values.
real MIN_RANGE_OF_INPUT = -0.5;
real MAX_RANGE_OF_INPUT =  0.5;

// Input and output file names.
parameter DEBUG_FOLDER = "debug_files";
parameter INPUT_CSV =  "input.csv";
parameter OUTPUT1_CSV = "output_level_shift_to_zigzag.csv";
parameter OUTPUT2_CSV = "output_dc_ac.csv";
parameter OUTPUT3_CSV = "output_bitstream.csv";

// <<<<< User Configuration


// >>>>> General Pattern Configuration

// Uncomment and adjust to control the magnitude of random exponents.
// parameter PRECISION_OF_RANDOM_EXPONENT = -5;

// Simulation cycle time, defined by the CYCLE_TIME macro.
parameter CYCLE = `CYCLE_TIME;
parameter INPUT_NEG_CYCLE_START = 3;
parameter INPUT_NEG_CYCLE_END = 6;
parameter MAX_EXECUTION_CYCLE = 50000;

// <<<<< General Pattern Configuration


// >>>>> Pattern Control
// Internal variables used to track pattern execution and latency.

integer pat;
integer execution_lat;
integer total_lat;

// <<<<< Pattern Control


// >>>>> Terminal Color Configuration
// ANSI escape sequences for terminal text and background colors.
// Use %0s when displaying these strings to avoid trailing padding.

reg [9*8:1]  reset_color        = "\033[1;0m";

reg [10*8:1] txt_black_prefix   = "\033[1;30m";
reg [10*8:1] txt_red_prefix     = "\033[1;31m";
reg [10*8:1] txt_green_prefix   = "\033[1;32m";
reg [10*8:1] txt_yellow_prefix  = "\033[1;33m";
reg [10*8:1] txt_blue_prefix    = "\033[1;34m";

reg [10*8:1] bkg_black_prefix   = "\033[40;1m";
reg [10*8:1] bkg_red_prefix     = "\033[41;1m";
reg [10*8:1] bkg_green_prefix   = "\033[42;1m";
reg [10*8:1] bkg_yellow_prefix  = "\033[43;1m";
reg [10*8:1] bkg_blue_prefix    = "\033[44;1m";
reg [10*8:1] bkg_white_prefix   = "\033[47;1m";

// <<<<< Terminal Color Configuration


//=====================================================================
//      DATA MODEL
//=====================================================================
parameter INPUT_BITS = 8;
parameter BITS_MASK = 8'hFF;
parameter SIZE_OF_INPUT = 128;
parameter SIZE_OF_BLOCK = 8;
parameter NUM_OF_BLOCK = ((SIZE_OF_INPUT/SIZE_OF_BLOCK) ** 2);
parameter LEVEL_SHIFT_OFFSET = 128;
parameter ROUND_BITS_DCT = 8 + 8 + 2;
parameter MAX_ENTROPY_BYTES = SIZE_OF_INPUT * SIZE_OF_INPUT * 8;
integer TOTAL_OUTPUT_BYTES = 0;

integer _input[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];
integer _level_shift[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];

integer _dct_inter[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];
integer _dct_mult[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];
integer _dct_round[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];

integer _quantization[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];
integer _zigzag[NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];

integer _dc_delta[NUM_OF_BLOCK-1:0];
integer _dc_category[NUM_OF_BLOCK-1:0];
integer _dc_amplitudde[NUM_OF_BLOCK-1:0];
integer _dc_huffman_code[NUM_OF_BLOCK-1:0];
integer _dc_huffman_length[NUM_OF_BLOCK-1:0];

 // SYMBOL = RUN<<4 | SIZE
 //     RUN : how many zero before non AC coeff
 //     SIZE : how many bits of non AC coeff
integer _ac_symbol_array[NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];
integer _ac_amplitude_array[NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];
integer _ac_length[NUM_OF_BLOCK-1:0];
integer _ac_huffman_code[NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];
integer _ac_huffman_length[NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];

integer _output_bytes[MAX_ENTROPY_BYTES-1:0];
integer _remain_bits;
integer _remain_buffer;

//=====================================================================
//  CLOCK
//=====================================================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//=====================================================================
//  SIMULATION
//=====================================================================
initial exe_task;

task exe_task; begin
    reset_task;
    for (pat=0 ; pat<TOTAL_PATNUM ; pat=pat+1) begin
        clear_jpeg_data;
        input_task;
        cal_task;
        wait_task;
        check_task;
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    in_data = 'dx;

    void'($urandom(SEED));
    total_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if (out_valid !== 0 || out_data !== 0) begin
        display_helper.display_full_seperator;
        $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
        display_helper.display_full_seperator;
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

task clear_jpeg_data;
    integer row, col;
begin
    //=============================================================
    // Input and Level Shift
    //=============================================================
    for (row = 0; row < SIZE_OF_INPUT; row = row + 1) begin
        for (col = 0; col < SIZE_OF_INPUT; col = col + 1) begin
            _input[row][col]       = 'dx;
            _level_shift[row][col] = 'dx;

            _dct_inter[row][col]   = 'dx;
            _dct_mult[row][col]    = 'dx;
            _dct_round[row][col]   = 'dx;

            _quantization[row][col] = 'dx;
        end
    end

    //=============================================================
    // Zigzag and AC
    //=============================================================
    for (row = 0; row < NUM_OF_BLOCK; row = row + 1) begin
        for (col = 0; col < SIZE_OF_BLOCK * SIZE_OF_BLOCK; col = col + 1) begin
            _zigzag[row][col]            = 'dx;

            _ac_symbol_array[row][col]   = 'dx;
            _ac_amplitude_array[row][col] = 'dx;
            _ac_huffman_code[row][col]    = 'dx;
            _ac_huffman_length[row][col]  = 'dx;
        end
    end

    //=============================================================
    // DC
    //=============================================================
    for (row = 0; row < NUM_OF_BLOCK; row = row + 1) begin
        _dc_delta[row]          = 'dx;
        _dc_category[row]       = 'dx;
        _dc_amplitudde[row]     = 'dx;
        _dc_huffman_code[row]   = 'dx;
        _dc_huffman_length[row] = 'dx;

        _ac_length[row]         = 'dx;
    end

    //=============================================================
    // Output Bytes
    //=============================================================
    TOTAL_OUTPUT_BYTES = 0;
    for (row = 0; row < MAX_ENTROPY_BYTES; row = row + 1) begin
        _output_bytes[row] = 'dx;
    end
    _remain_bits = 0;
    _remain_buffer = 0;
end endtask

task input_task;
    integer row;
    integer col;
begin
    repeat(($urandom() % (INPUT_NEG_CYCLE_END - INPUT_NEG_CYCLE_START + 1)) + INPUT_NEG_CYCLE_START) @(negedge clk);
    for(row=0 ; row<SIZE_OF_INPUT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_INPUT ; col=col+1) begin
            _input[row][col] = pat < SIMPLE_PATNUM
                            ? ($urandom() % (SIMPLE_INPUT_MAX - SIMPLE_INPUT_MIN + 1) + SIMPLE_INPUT_MIN)
                            : $urandom();
            in_valid = 1;
            in_data = _input[row][col];
            @(negedge clk);
        end
    end
    in_valid = 0;
    in_data = 'dx;
    @(negedge clk);
end endtask

task cal_task; begin
    level_shift_task;
    dct_task;
    quantization_task;
    zigzag_task;
    dc_task;
    ac_task;
    bitstream_pack_task;

    if (DEBUG) begin
        export_debug_files;
    end
end endtask

task wait_task; begin
    execution_lat = -1;
    while (out_valid !== 1) begin
        if (out_data !== 0) begin
            display_helper.display_full_seperator;
            $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
            display_helper.display_full_seperator;
            repeat(5) @(negedge clk);
            $finish;
        end
        if (execution_lat == MAX_EXECUTION_CYCLE) begin
            display_helper.display_full_seperator;
            $display("      The execution latency at %-12d ps is over %5d cycles  ", $time*1000, MAX_EXECUTION_CYCLE);
            display_helper.display_full_seperator;
            repeat(5) @(negedge clk);
            $finish; 
        end
        execution_lat = execution_lat + 1;
        @(negedge clk);
    end
end endtask

task check_task;
    integer output_count;
begin
    output_count = 0;

    // Check every output cycle, including the first valid cycle.
    while (output_count < TOTAL_OUTPUT_BYTES) begin

        // Check output data when invalid
        if (out_valid !== 1'b1) begin
            if (out_data !== 0) begin
                display_helper.display_full_seperator;
                $display("Output signal should be 0 at %-12d ps", $time * 1000);
                display_helper.display_full_seperator;
                repeat(5) @(negedge clk);
                $finish;
            end
        end
        else begin
            // Check output data when valid
            if (out_data !== _output_bytes[output_count]) begin
                display_helper.display_full_seperator;
                $display("Output data mismatch at output_count=%0d, time=%0d ps", output_count, $time * 1000);
                $display("Expected: %02h, Got: %02h", _output_bytes[output_count], out_data);
                $display("[INFO] Dump the debug files under the folder %0s", DEBUG_FOLDER);
                display_helper.display_full_seperator;
                export_debug_files;
                repeat(5) @(negedge clk);
                $finish;
            end

            // Count valid output
            output_count = output_count + 1;
        end

        // Stop after the final valid output
        if (output_count < TOTAL_OUTPUT_BYTES) begin
            execution_lat = execution_lat + 1;

            if (execution_lat >= MAX_EXECUTION_CYCLE) begin
                display_helper.display_full_seperator;
                $display("The execution latency at %-12d ps is over %5d cycles", $time * 1000, MAX_EXECUTION_CYCLE);
                display_helper.display_full_seperator;
                repeat(5) @(negedge clk);
                $finish;
            end

            @(negedge clk);
        end
    end

    total_lat = total_lat + execution_lat;
end endtask

task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", total_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask


task level_shift_task;
    integer row;
    integer col;
begin
    for(row=0 ; row<SIZE_OF_INPUT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_INPUT ; col=col+1) begin
            _level_shift[row][col] = _input[row][col] - LEVEL_SHIFT_OFFSET;
        end
    end
end endtask


task dct_task;
    integer row_b;
    integer row;
    integer col_b;
    integer col;

    integer coeff[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    integer matrix_in[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    integer matrix_out[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
begin
    for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
            coeff[row][col] = helper.dct_coeff[row][col];
        end
    end

    for(row_b=0 ; row_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; row_b=row_b+1) begin
        for(col_b=0 ; col_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; col_b=col_b+1) begin
            // prepare matrix
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    matrix_in[row][col] = _level_shift[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col];
                end
            end
            helper.mutmax1(matrix_in, coeff, matrix_out);
            // assign output matrix
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _dct_inter[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col] = matrix_out[row][col];
                end
            end
        end
    end

    for(row_b=0 ; row_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; row_b=row_b+1) begin
        for(col_b=0 ; col_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; col_b=col_b+1) begin
            // prepare matrix
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    matrix_in[row][col] = _dct_inter[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col];
                end
            end
            helper.mutmax_by_row(coeff, matrix_in, matrix_out);
            // assign output matrix
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _dct_mult[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col] = matrix_out[row][col];
                end
            end
        end
    end

    for(row=0 ; row<SIZE_OF_INPUT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_INPUT ; col=col+1) begin
            _dct_round[row][col] = helper.round_s(_dct_mult[row][col], ROUND_BITS_DCT);
        end
    end
end endtask

task quantization_task;
    integer row_b;
    integer row;
    integer col_b;
    integer col;
begin
    for(row_b=0 ; row_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; row_b=row_b+1) begin
        for(col_b=0 ; col_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; col_b=col_b+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _quantization[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col] =
                        helper.round_s(_dct_round[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col], helper.quant_coeff[row][col]);
                end
            end
        end
    end
end endtask

task zigzag_task;
    integer row_b;
    integer row;
    integer col_b;
    integer col;
    integer z_index;
begin
    for(row=0 ; row<SIZE_OF_INPUT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_INPUT ; col=col+1) begin
        end
    end

    for(row_b=0 ; row_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; row_b=row_b+1) begin
        for(col_b=0 ; col_b<SIZE_OF_INPUT/SIZE_OF_BLOCK ; col_b=col_b+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    z_index = helper.zigzag_index(row, col);
                    _zigzag[row_b*(SIZE_OF_INPUT/SIZE_OF_BLOCK)+col_b][z_index] = _quantization[row_b*SIZE_OF_BLOCK+row][col_b*SIZE_OF_BLOCK+col];
                end
            end
        end
    end
end endtask

task dc_task;
    integer block_idx;

    integer previous_dc;
    integer current_dc;
    integer delta;

    integer category;
    integer amplitude;
    integer huffman_code;
    integer huffman_length;
begin
    // Reset predictor at the beginning of each image
    previous_dc = 0;

    for (block_idx=0 ; block_idx<NUM_OF_BLOCK ; block_idx=block_idx+1) begin
        current_dc = _zigzag[block_idx][0];

        // DC differential coding
        delta = current_dc - previous_dc;
        previous_dc = current_dc;
        _dc_delta[block_idx] = delta;

        // Calculate CATEGORY = SIZE of delta
        // Simulate the log process
        category = arithmetic_helper.calc_num_bits(delta);
        _dc_category[block_idx] = category;

        // Calculate JPEG amplitude
        amplitude = delta >= 0
            ? delta
            : ((1 << category) - 1) + delta;

        _dc_amplitudde[block_idx] = amplitude;

        // Lookup DC Huffman table
        if (category >= helper.NUM_DC_HUFFMAN) begin
            $display("[ERROR] Invalid DC category: %0d, block=%0d", category, block_idx);
            $finish;
        end

        _dc_huffman_code[block_idx] = helper.dc_huffman_code[category];
        _dc_huffman_length[block_idx] = helper.dc_huffman_length[category];

        if (huffman_length <= 0) begin
            $display("[ERROR] Invalid DC Huffman length: category=%0d", category);
            $finish;
        end
    end
end endtask

task ac_task;
    integer block_idx;
    integer zigzag_idx;
    integer output_idx;

    integer coeff;
    integer run;
    integer size;
    integer symbol;
    integer amplitude;
begin
    for (block_idx=0 ; block_idx<NUM_OF_BLOCK ; block_idx=block_idx+1) begin

        run = 0;
        output_idx = 0;

        _ac_length[block_idx] = 0;

        // AC coefficients: Z[1] ~ Z[63]
        for (zigzag_idx=1 ; zigzag_idx<SIZE_OF_BLOCK * SIZE_OF_BLOCK ; zigzag_idx=zigzag_idx+1) begin

            coeff = _zigzag[block_idx][zigzag_idx];

            if (coeff == 0) begin
                run = run + 1;
            end
            else begin
                // Emit ZRL for each 16 zeros before
                // this non-zero coefficient.
                while (run >= helper.NUM_OF_ZRL) begin
                    symbol = helper.SYMBOL_OF_ZRL;

                    if (helper.ac_huffman_valid[symbol] == 0) begin
                        $display("[ERROR] Missing AC ZRL Huffman code.");
                        $finish;
                    end

                    _ac_huffman_code[block_idx][output_idx] = helper.ac_huffman_code[symbol];
                    _ac_huffman_length[block_idx][output_idx] = helper.ac_huffman_length[symbol];

                    // ZRL has SIZE=0, so no amplitude bits.
                    _ac_symbol_array[block_idx][output_idx] = symbol;
                    _ac_amplitude_array[block_idx][output_idx] = 0;

                    output_idx = output_idx + 1;
                    run = run - 16;
                end

                // Calculate SIZE of non-zero coefficient
                size = arithmetic_helper.calc_num_bits(coeff);

                // Baseline JPEG AC SIZE must fit in 4 bits.
                if (size > 15) begin
                    $display("[ERROR] AC SIZE too large: %0d", size);
                    $finish;
                end

                // SYMBOL = (RUN << 4) | SIZE
                symbol = (run << 4) | size;

                // Calculate JPEG amplitude
                amplitude = coeff > 0
                        ? coeff
                        : ((1 << size) - 1) + coeff;

                if (helper.ac_huffman_valid[symbol] == 0) begin
                    $display("[ERROR] Missing AC Huffman symbol=%02h, block=%0d", symbol, block_idx);
                    $finish;
                end

                _ac_huffman_code[block_idx][output_idx] = helper.ac_huffman_code[symbol];
                _ac_huffman_length[block_idx][output_idx] = helper.ac_huffman_length[symbol];

                if (_ac_huffman_length[block_idx][output_idx] <= 0) begin
                    $display("[ERROR] Invalid AC Huffman length: symbol=%02h", symbol);
                    $finish;
                end

                _ac_symbol_array[block_idx][output_idx] = symbol;
                _ac_amplitude_array[block_idx][output_idx] = amplitude;

                output_idx = output_idx + 1;

                // Reset run after encoding a non-zero coefficient
                run = 0;
            end
        end

        // Trailing zeros: emit EOB only.
        // Do NOT emit ZRL for trailing zeros.
        if (run > 0) begin
            symbol = 8'h00;

            if (helper.ac_huffman_valid[symbol] == 0) begin
                $display("[ERROR] Missing AC EOB Huffman code.");
                $finish;
            end

            _ac_huffman_code[block_idx][output_idx] = helper.ac_huffman_code[symbol];
            _ac_huffman_length[block_idx][output_idx] = helper.ac_huffman_length[symbol];

            _ac_symbol_array[block_idx][output_idx] = symbol;
            _ac_amplitude_array[block_idx][output_idx] = 0;

            output_idx = output_idx + 1;
        end

        _ac_length[block_idx] = output_idx;
    end
end endtask

task bitstream_pack_task;
    integer bit_buffer;
    integer bit_count;

    integer block_idx = 0;

    integer pack_code = 0;
    integer pack_length = 0;

    integer pack_bit_idx = 0;
    integer pack_bit = 0;

    integer ac_pack_idx = 0;
    integer pack_size = 0;
    
begin
    // Initialize bitstream state
    bit_buffer = 0;
    bit_count = 0;
    TOTAL_OUTPUT_BYTES = 0;

    // Process all blocks in raster order
    for (block_idx = 0 ; block_idx < NUM_OF_BLOCK; block_idx = block_idx + 1) begin

        //--------------------------------------------------
        // 1. DC Huffman code
        //--------------------------------------------------
        pack_code = _dc_huffman_code[block_idx];
        pack_length = _dc_huffman_length[block_idx];

        for (pack_bit_idx = pack_length - 1; pack_bit_idx >= 0; pack_bit_idx = pack_bit_idx - 1) begin

            pack_bit = (pack_code >> pack_bit_idx) & 1;

            bit_buffer = (bit_buffer << 1) | pack_bit;
            bit_count = bit_count + 1;

            if (bit_count == INPUT_BITS) begin
                _output_bytes[TOTAL_OUTPUT_BYTES] = bit_buffer & BITS_MASK;
                TOTAL_OUTPUT_BYTES = TOTAL_OUTPUT_BYTES + 1;

                bit_buffer = 0;
                bit_count = 0;
            end
        end

        //--------------------------------------------------
        // 2. DC amplitude bits
        //--------------------------------------------------
        pack_code = _dc_amplitudde[block_idx];
        pack_length = _dc_category[block_idx];

        for (pack_bit_idx = pack_length - 1; pack_bit_idx >= 0; pack_bit_idx = pack_bit_idx - 1) begin

            pack_bit = (pack_code >> pack_bit_idx) & 1;

            bit_buffer = (bit_buffer << 1) | pack_bit;
            bit_count = bit_count + 1;

            if (bit_count == INPUT_BITS) begin
                _output_bytes[TOTAL_OUTPUT_BYTES] = bit_buffer & BITS_MASK;
                TOTAL_OUTPUT_BYTES = TOTAL_OUTPUT_BYTES + 1;

                bit_buffer = 0;
                bit_count = 0;
            end
        end

        //--------------------------------------------------
        // 3. AC Huffman code and amplitude bits
        //--------------------------------------------------
        for (ac_pack_idx = 0; ac_pack_idx < _ac_length[block_idx]; ac_pack_idx = ac_pack_idx + 1) begin

            // AC Huffman code
            pack_code = _ac_huffman_code[block_idx][ac_pack_idx];
            pack_length = _ac_huffman_length[block_idx][ac_pack_idx];

            for (pack_bit_idx = pack_length - 1; pack_bit_idx >= 0; pack_bit_idx = pack_bit_idx - 1) begin

                pack_bit = (pack_code >> pack_bit_idx) & 1;

                bit_buffer = (bit_buffer << 1) | pack_bit;
                bit_count = bit_count + 1;

                if (bit_count == INPUT_BITS) begin
                    _output_bytes[TOTAL_OUTPUT_BYTES] =
                        bit_buffer & BITS_MASK;

                    TOTAL_OUTPUT_BYTES = TOTAL_OUTPUT_BYTES + 1;

                    bit_buffer = 0;
                    bit_count = 0;
                end
            end

            // AC amplitude bits:
            // SIZE is the low nibble of SYMBOL.
            pack_size = _ac_symbol_array[block_idx][ac_pack_idx] & 4'hF;

            if (pack_size > 0) begin
                pack_code = _ac_amplitude_array[block_idx][ac_pack_idx];
                pack_length = pack_size;

                for (pack_bit_idx = pack_length - 1; pack_bit_idx >= 0; pack_bit_idx = pack_bit_idx - 1) begin

                    pack_bit = (pack_code >> pack_bit_idx) & 1;

                    bit_buffer = (bit_buffer << 1) | pack_bit;
                    bit_count = bit_count + 1;

                    if (bit_count == INPUT_BITS) begin
                        _output_bytes[TOTAL_OUTPUT_BYTES] =
                            bit_buffer & BITS_MASK;

                        TOTAL_OUTPUT_BYTES = TOTAL_OUTPUT_BYTES + 1;

                        bit_buffer = 0;
                        bit_count = 0;
                    end
                end
            end
        end
    end

    if (bit_count > 0) begin
        while (bit_count < INPUT_BITS) begin
            bit_buffer = (bit_buffer << 1) | 1;
            bit_count = bit_count + 1;
        end

        _output_bytes[TOTAL_OUTPUT_BYTES] = bit_buffer & BITS_MASK;

        TOTAL_OUTPUT_BYTES = TOTAL_OUTPUT_BYTES + 1;

        bit_buffer = 0;
        bit_count = 0;
    end

    _remain_bits = bit_count; // Should zero
    _remain_buffer = bit_buffer; // Should zero
end endtask

//======================================
//           DISPLAY TASK
//======================================

matrix_int_2d_csv_dumper #(
    SIZE_OF_INPUT-1,SIZE_OF_INPUT-1,0,0,
    SIZE_OF_BLOCK,SIZE_OF_BLOCK,"#","","#","") dumper1();

matrix_int_2d_csv_dumper #(
    SIZE_OF_BLOCK-1,SIZE_OF_BLOCK-1,0,0,
    0,0,"#","","#","") dumper2();

matrix_int_2d_csv_dumper #(
    ((SIZE_OF_INPUT/SIZE_OF_BLOCK) ** 2)-1,SIZE_OF_BLOCK*SIZE_OF_BLOCK-1,0,0,
    1,0,"#","","#","") dumper3();

matrix_int_1d_csv_dumper #(
    NUM_OF_BLOCK-1, 0
) dumper4(); 

JPEG_helper helper();

task export_debug_files;
    reg[1023:0] cmd;
begin
    $sformat(cmd, "mkdir -p %0s", DEBUG_FOLDER);
    $display("[INFO] Execute command: %0s", cmd);
    $system(cmd);

    export_input_to_csv;
    export_output_to_csv;
end endtask

task export_input_to_csv;
    integer file;

    integer row;
    integer col;
    integer matrix[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
begin
    file = $fopen({DEBUG_FOLDER, "/", INPUT_CSV}, "w");

    $fdisplay(file, "Input,");
    dumper1.dump(file, _input);
    $fdisplay(file, "");

    $fdisplay(file, "Coefficient,");
    for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
            matrix[row][col] = helper.dct_coeff[row][col];
        end
    end
    dumper2.dump(file, matrix);
    $fdisplay(file, "");

    $fclose(file);
end endtask

task export_output_to_csv;
    integer file1;
    integer file2;
    integer file3;

    integer idx;
    integer flag;
begin
    file1 = $fopen({DEBUG_FOLDER, "/", OUTPUT1_CSV}, "w");
    file2 = $fopen({DEBUG_FOLDER, "/", OUTPUT2_CSV}, "w");
    file3 = $fopen({DEBUG_FOLDER, "/", OUTPUT3_CSV}, "w");

    // File 1
    $fdisplay(file1, "Level Shift,");
    dumper1.dump(file1, _level_shift);
    $fdisplay(file1, "");

    $fdisplay(file1, "DCT Intermediate");
    dumper1.dump(file1, _dct_inter);
    $fdisplay(file1, "DCT Multiplication");
    dumper1.dump(file1, _dct_mult);
    $fdisplay(file1, "DCT Round");
    dumper1.dump(file1, _dct_round);
    $fdisplay(file1, "");

    $fdisplay(file1, "Quantization");
    dumper1.dump(file1, _quantization);
    $fdisplay(file1, "");

    $fdisplay(file1, "Zigzag");
    dumper3.dump(file1, _zigzag);
    $fdisplay(file1, "");

    // File 2
    $fdisplay(file2, "DC Delta");
    dumper4.dump(file2, _dc_delta);
    $fdisplay(file2, "");
    $fdisplay(file2, "DC Category");
    dumper4.dump(file2, _dc_category);
    $fdisplay(file2, "");
    $fdisplay(file2, "DC Amplitude");
    dumper4.dump(file2, _dc_amplitudde);
    $fdisplay(file2, "");
    $fdisplay(file2, "DC Huffman Code");
    dumper4.dump(file2, _dc_huffman_code);
    $fdisplay(file2, "");
    $fdisplay(file2, "DC Huffman Length");
    dumper4.dump(file2, _dc_huffman_length);
    $fdisplay(file2, "");

    $fdisplay(file2, "AC Symbol");
    dumper3.dump(file2, _ac_symbol_array);
    $fdisplay(file2, "");
    $fdisplay(file2, "AC Amplitude");
    dumper3.dump(file2, _ac_amplitude_array);
    $fdisplay(file2, "");
    $fdisplay(file2, "AC Length");
    dumper4.dump(file2, _ac_length);
    $fdisplay(file2, "");
    $fdisplay(file2, "AC Huffman Code");
    dumper3.dump(file2, _ac_huffman_code);
    $fdisplay(file2, "");
    $fdisplay(file2, "AC Huffman Length");
    dumper3.dump(file2, _ac_huffman_length);
    $fdisplay(file2, "");

    // File 3
    $fdisplay(file3, "Output Bytes,%6d", TOTAL_OUTPUT_BYTES);
    for(idx=0 ; idx<TOTAL_OUTPUT_BYTES ; idx=idx+1) begin
        $fwrite(file3, "%3d,", _output_bytes[idx]);
    end
    $fwrite(file3, "\n");
    $fdisplay(file3, "Remain bit (Should be zero),%3d", _remain_bits);
    $fdisplay(file3, "Remain buffer (Should be zero),%3d", _remain_buffer);

    flag = 0;
    for(idx=TOTAL_OUTPUT_BYTES ; idx<MAX_ENTROPY_BYTES ; idx=idx+1) begin
        if(_output_bytes[idx] != 'dx)
            flag = 1;
    end
    if(flag == 1)
        $fdisplay(file3, "Non complete bitstream");

    $fclose(file1);
    $fclose(file2);
    $fclose(file3);
end endtask



endmodule
