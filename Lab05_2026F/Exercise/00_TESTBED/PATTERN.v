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
parameter INPUT_HEX_CSV =  "input.csv";
parameter OUTPUT_HEX_CSV = "output.csv";

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
parameter SIZE_OF_INPUT = 128;
parameter SIZE_OF_BLOCK = 16;

integer _input[SIZE_OF_INPUT-1:0][SIZE_OF_INPUT-1:0];

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

task check_task; begin
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


//======================================
//           DISPLAY TASK
//======================================
task export_debug_files;
    reg[1023:0] cmd;
begin
    $sformat(cmd, "mkdir -p %0s", DEBUG_FOLDER);
    $display("Execute command: %0s", cmd);
    $system(cmd);

    export_input_to_csv;
    export_output_to_csv;
end endtask

task export_input_to_csv; begin
    
end endtask

task export_output_to_csv; begin
    
end endtask



endmodule
