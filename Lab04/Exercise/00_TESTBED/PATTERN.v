`timescale 1ns/1ps

`define CYCLE_TIME      50.0

`include "Utility.v"
`include "IP_common.v"


module PATTERN (
    clk,
    rst_n,
    in_valid,
    K,
    Q,
    V,
    out_weight,
    out_valid,
    out
);

//=====================================================================
//   PORT DECLARATION
//=====================================================================
output reg          clk;
output reg          rst_n;
output reg          in_valid;
output reg  [31:0]  K;
output reg  [31:0]  Q;
output reg  [31:0]  V;
output reg  [31:0]  out_weight;

input  wire         out_valid;
input  wire [31:0]  out;

//=====================================================================
// Simulation Configuration
//=====================================================================

// >>>>> User Configuration
// Parameters in this section can be modified by the user.

// Number of pattern cases to execute in total.
integer TOTAL_PATNUM = 1000;

// Number of simple pattern cases to execute.
integer SIMPLE_PATNUM = 100;

// Random seed used for pattern generation.
integer SEED = 5487;
parameter DEBUG = 1;

// Range of generated input values.
// Use decimal-point notation (e.g., 0.5) to avoid unintended
// integer arithmetic and invalid floating-point results.
real MIN_RANGE_OF_INPUT = -0.5;
real MAX_RANGE_OF_INPUT =  0.5;

real MIN_POS_OF_K = 0.5;
real MAX_POS_OF_K = 255;

// Input and output file names.
parameter INPUT_HEX_CSV   = "input_hex.csv";
parameter INPUT_FLOAT_CSV = "input_float.csv";
parameter OUTPUT_HEX_CSV  = "output_hex.csv";
parameter OUTPUT_FLOAT_CSV = "output_float.csv";

// <<<<< User Configuration


// >>>>> General Pattern Configuration

// Uncomment and adjust to control the magnitude of random exponents.
// parameter PRECISION_OF_RANDOM_EXPONENT = -5;

// Simulation cycle time, defined by the CYCLE_TIME macro.
parameter CYCLE = `CYCLE_TIME;
parameter MAX_EXECUTION_CYCLE = 1000;

// <<<<< General Pattern Configuration


// >>>>> DUT Configuration
// Configuration parameters for the instantiated design under test (DUT).

parameter inst_sig_width       = 23;
parameter inst_exp_width       = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type       = 0;
parameter inst_arch            = 0;

// <<<<< DUT Configuration


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
// Parameter
real RAND_DIVISOR = (2.0**32) - 1.0;
parameter SQUARE_ROOT_2 = 32'b00111111101101010000010011110011;

// Input 
// 16 x 4
parameter NUM_OF_TOKEN = 16;
parameter NUM_OF_DIM = 4;

parameter SIZE_OF_WEIGHT = 4;
// Q, K, V -> split into 2 heads for each tokens
// 16 x 2, 16 x 2 (Two heads)
// For each head -> 8 x (2 x 2)
parameter NUM_OF_HEAD = 2;
parameter DIM_OF_HEAD = 2;
parameter SIZE_OF_BLOCK = 2; // block = tile
parameter NUM_OF_BLOCK = NUM_OF_TOKEN / SIZE_OF_BLOCK; // 16 / 2 = 8

parameter NUM_OF_O_ACC_TILE = 8;
parameter NUM_OF_HEAD_TILE = 8;


// Output
// 4 x 4
parameter SIZE_OF_OUTPUT = 4;

//-------------------------------------------------------------------------------------------------------------------------------------

// Data
// Input
reg[inst_sig_width+inst_exp_width:0] _K[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg[inst_sig_width+inst_exp_width:0] _Q[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg[inst_sig_width+inst_exp_width:0] _V[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg[inst_sig_width+inst_exp_width:0] _weight[SIZE_OF_WEIGHT-1:0][SIZE_OF_WEIGHT-1:0];

// Results of each steps
reg[inst_sig_width+inst_exp_width:0] _K_transpose[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _multQK_T_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg[inst_sig_width+inst_exp_width:0] _multQK_T[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _score_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg[inst_sig_width+inst_exp_width:0] _score[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
 /*
    Update sequentially.
        For tile 0 row 0, only check the _score[1][0][0][0:1]
        For tile 0 row 1, only check the _score[1][0][1][0:1]
        For tile 1 row 0, only check the _score[1][0][0][0:1] and _score[1][1][0][0:1]
        For tile 1 row 1, only check the _score[1][0][1][0:1] and _score[1][1][1][0:1]
 */
wire[inst_sig_width+inst_exp_width:0] _runningMaxOfScore_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _runningMaxOfScore_w_temp[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][0:0];
reg [inst_sig_width+inst_exp_width:0] _runningMaxOfScore[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _runningSumOfScore_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _runningSumOfScore_w_temp[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][0:0];
reg [inst_sig_width+inst_exp_width:0] _runningSumOfScore[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _P_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg [inst_sig_width+inst_exp_width:0] _P[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _O_ACC_temp_w[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg [inst_sig_width+inst_exp_width:0] _O_ACC_temp[NUM_OF_HEAD:1][NUM_OF_BLOCK*NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _O_ACC_final_w[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg [inst_sig_width+inst_exp_width:0] _O_ACC_final[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _head_out_w[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
reg [inst_sig_width+inst_exp_width:0] _head_out[NUM_OF_HEAD:1][NUM_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
wire[inst_sig_width+inst_exp_width:0] _head_concate_w[NUM_OF_TOKEN-1:0][NUM_OF_DIM-1:0];
reg [inst_sig_width+inst_exp_width:0] _head_concate[NUM_OF_TOKEN-1:0][NUM_OF_DIM-1:0];
wire[inst_sig_width+inst_exp_width:0] _output_w[NUM_OF_TOKEN-1:0][NUM_OF_DIM-1:0];
reg [inst_sig_width+inst_exp_width:0] _output[NUM_OF_TOKEN-1:0][NUM_OF_DIM-1:0];



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
        generate_input_task;
        cal_task;
        input_task;
        wait_task;
        check_task;
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    K = 0;
    Q = 0;
    V = 0;
    out_weight = 0;

    void'($urandom(SEED));
    total_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if (out_valid !== 0 || out !== 0) begin
        display_helper.display_full_seperator;
        $display("      Output signal should be 0 at %-12d ps  ", $time*1000);
        display_helper.display_full_seperator;
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

task generate_input_task; begin
    clear_data;
    randomize_input;
    cal_task;
end endtask

task cal_task; begin
    @(posedge clk);
    store_score;
    store_L_of_score;
    store_P;
    store_O_Acc;
    store_head;
    store_output;
    
    if(DEBUG > 0) begin
        export_input_to_csv(0);
        export_input_to_csv(1);
        export_output_to_csv(0);
        export_output_to_csv(1);
    end
end endtask

task input_task;
    integer count;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    repeat(($urandom() % 3) + 2) @(negedge clk);

    count = 0;
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    in_valid = 'd1;
                    K = _K[head][block][row][col];
                    Q = _Q[head][block][row][col];
                    V = _V[head][block][row][col];

                    if (count < SIZE_OF_WEIGHT*SIZE_OF_WEIGHT) begin
                        out_weight = _weight[count/SIZE_OF_WEIGHT][count%SIZE_OF_WEIGHT];
                    end
                    else begin
                        out_weight = 'dx;
                    end

                    count = count + 1;
                    @(negedge clk);
                end
            end
        end
    end

    in_valid = 'd0;
    K = 'dx;
    Q = 'dx;
    V = 'dx;
    out_weight = 'dx;
end endtask

task wait_task; begin
    execution_lat = -1;
    while (out_valid !== 1) begin
        if (out !== 0) begin
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
    ;
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

// =========================================================================================================== //
// Input helper
task clear_data;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _K[head][block][row][col] = 'dx;
                    _Q[head][block][row][col] = 'dx;
                    _V[head][block][row][col] = 'dx;
                end
            end
        end
    end

    for(row=0 ; row<SIZE_OF_WEIGHT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_WEIGHT ; col=col+1) begin
            _weight[row][col] = 'dx;
        end
    end
end endtask

function[inst_sig_width+inst_exp_width:0] generate_rand_input_k;
    input integer is_simple;

    reg[inst_sig_width+inst_exp_width:0] min_float_bits;
    reg[inst_sig_width+inst_exp_width:0] max_float_bits;
    real range;
    reg[inst_sig_width+inst_exp_width:0] range_float_bits;
    real rand_out;

    reg[inst_exp_width-1:0] random_exponent;
    reg[inst_sig_width+inst_exp_width:0] pool[7:0];
begin
    // +- 0.5, 1, 2, 4
    pool[0] = 32'h3F00_0000;
    pool[1] = 32'hBF00_0000;
    pool[2] = 32'h3f80_0000;
    pool[3] = 32'hbf80_0000;
    pool[4] = 32'h4000_0000;
    pool[5] = 32'hc000_0000;
    pool[6] = 32'h4080_0000;
    pool[7] = 32'hc080_0000;
    generate_rand_input_k = 0;

    if(is_simple) begin
        generate_rand_input_k = 0;
        generate_rand_input_k = pool[$urandom() % 8];
    end
    else begin
        if(MIN_RANGE_OF_INPUT > MAX_RANGE_OF_INPUT) begin
            $display("[ERROR] [PARAMETER] MIN_RANGE_OF_INPUT can't be larger than MAX_RANGE_OF_INPUT");
            $finish;
        end
        if(!arithmetic_helper.is_valid_float_of_real(MIN_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The minimum of input exceeds the defined range of float");
            $finish;
        end
        if(!arithmetic_helper.is_valid_float_of_real(MAX_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The maximum of input exceeds the defined range of float");
            $finish;
        end

        rand_out = (real'($urandom()) / RAND_DIVISOR) * (MAX_POS_OF_K - MIN_POS_OF_K) + MIN_POS_OF_K;
        if($urandom() % 2) begin
            rand_out = -1;
        end
        generate_rand_input_k = arithmetic_helper.real_to_float_bits(rand_out);
    end
end
endfunction

function[inst_sig_width+inst_exp_width:0] generate_rand_input_other;
    input integer is_simple;

    reg[inst_sig_width+inst_exp_width:0] min_float_bits;
    reg[inst_sig_width+inst_exp_width:0] max_float_bits;
    real range;
    reg[inst_sig_width+inst_exp_width:0] range_float_bits;
    real rand_out;

    reg[inst_exp_width-1:0] random_exponent;
    reg[inst_sig_width+inst_exp_width:0] pool[7:0];
begin
    // +- 0, 0.5, 0.25, 0.125
    pool[0] = 32'h0000_0000;
    pool[1] = 32'h8000_0000;
    pool[2] = 32'h3F00_0000;
    pool[3] = 32'hBF00_0000;
    pool[4] = 32'h3E80_0000;
    pool[5] = 32'hBE80_0000;
    pool[6] = 32'h3E00_0000;
    pool[7] = 32'hBE00_0000;
    generate_rand_input_other = 0;

    if(is_simple) begin
        generate_rand_input_other = 0;
        generate_rand_input_other = pool[$urandom() % 8];
    end
    else begin
        if(MIN_RANGE_OF_INPUT > MAX_RANGE_OF_INPUT) begin
            $display("[ERROR] [PARAMETER] MIN_RANGE_OF_INPUT can't be larger than MAX_RANGE_OF_INPUT");
            $finish;
        end
        if(!arithmetic_helper.is_valid_float_of_real(MIN_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The minimum of input exceeds the defined range of float");
            $finish;
        end
        if(!arithmetic_helper.is_valid_float_of_real(MAX_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The maximum of input exceeds the defined range of float");
            $finish;
        end

        rand_out = (real'($urandom()) / RAND_DIVISOR) * (MAX_RANGE_OF_INPUT - MIN_RANGE_OF_INPUT) + MIN_RANGE_OF_INPUT;
        generate_rand_input_other = arithmetic_helper.real_to_float_bits(rand_out);
    end
end
endfunction

task randomize_input;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _K[head][block][row][col] = generate_rand_input_k(pat < SIMPLE_PATNUM);
                    _Q[head][block][row][col] = generate_rand_input_other(pat < SIMPLE_PATNUM);
                    _V[head][block][row][col] = generate_rand_input_other(pat < SIMPLE_PATNUM);

                    _K_transpose[head][block][col][row] = _K[head][block][row][col];
                end
            end
        end
    end

    for(row=0 ; row<SIZE_OF_WEIGHT ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_WEIGHT ; col=col+1) begin
            _weight[row][col] = generate_rand_input_other(pat < SIMPLE_PATNUM);
        end
    end
end endtask

// =========================================================================================================== //
// Generate module
generate
    // Q x K_T and Score
    for(genvar head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(genvar block_i=0 ; block_i<NUM_OF_BLOCK ; block_i=block_i+1) begin
            for(genvar block_j=0 ; block_j<NUM_OF_BLOCK ; block_j=block_j+1) begin
                matmul #( .m(SIZE_OF_BLOCK), .n(SIZE_OF_BLOCK), .k(SIZE_OF_BLOCK) )
                    mm(
                        .A(_Q[head][block_i]),
                        .B(_K_transpose[head][block_j]),
                        .C(_multQK_T_w[head][block_i*NUM_OF_BLOCK+block_j])
                    );
                for(genvar row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                    for(genvar col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                        DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, 0)
                            D_scale (
                                .a      (_multQK_T_w[head][block_i*NUM_OF_BLOCK+block_j][row][col]),
                                .b      (SQUARE_ROOT_2),
                                .rnd    (3'd0),
                                .z      (_score_w[head][block_i*NUM_OF_BLOCK+block_j][row][col]),
                                .status ()
                            );
                    end
                end
            end
        end
    end

    // Running max and sum
    for(genvar head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(genvar block_i=0 ; block_i<NUM_OF_BLOCK ; block_i=block_i+1) begin
            for(genvar block_j=0 ; block_j<NUM_OF_BLOCK ; block_j=block_j+1) begin
                localparam TILE_ID = block_i * NUM_OF_BLOCK + block_j;
                wire [inst_sig_width+inst_exp_width:0] _m_prev_tile [SIZE_OF_BLOCK-1:0];
                wire [inst_sig_width+inst_exp_width:0] _l_prev_tile [SIZE_OF_BLOCK-1:0];
                localparam [31:0] FP_NEG_INF = 32'hFF800000;
                localparam [31:0] FP_ZERO = 32'h00000000;

                for (genvar size=0 ; size<SIZE_OF_BLOCK ; size=size+1) begin
                    if (block_j == 0) begin : gen_init
                        assign _m_prev_tile[size] = FP_NEG_INF;
                        assign _l_prev_tile[size] = FP_ZERO;
                    end
                    else begin
                        assign _m_prev_tile[size] = _runningMaxOfScore_w[head][TILE_ID-1][size];

                        assign _l_prev_tile[size] = _runningSumOfScore_w[head][TILE_ID-1][size];
                    end
                end

                runningMax #(
                    .inst_sig_width(inst_sig_width),
                    .inst_exp_width(inst_exp_width),
                    .inst_ieee_compliance(inst_ieee_compliance),
                    .inst_arch(inst_arch),
                    .row(SIZE_OF_BLOCK),
                    .col(SIZE_OF_BLOCK)
                ) RM (
                    .m_prev(_m_prev_tile),
                    .in(_score_w[head][TILE_ID]),
                    .m_next(_runningMaxOfScore_w[head][TILE_ID])
                );

                runningSum #(
                    .inst_sig_width(inst_sig_width),
                    .inst_exp_width(inst_exp_width),
                    .inst_ieee_compliance(inst_ieee_compliance),
                    .inst_arch(inst_arch),
                    .row(SIZE_OF_BLOCK),
                    .col(SIZE_OF_BLOCK)
                ) RS (
                    .m_prev(_m_prev_tile),
                    .m_next(_runningMaxOfScore_w[head][TILE_ID]),
                    .l_prev(_l_prev_tile),
                    .in(_score_w[head][TILE_ID]),
                    .l_next(_runningSumOfScore_w[head][TILE_ID])
                );

                for(genvar size=0 ; size<SIZE_OF_BLOCK ; size=size+1) begin
                    assign _runningMaxOfScore_w_temp[head][TILE_ID][size][0] = _runningMaxOfScore_w[head][TILE_ID][size];
                    assign _runningSumOfScore_w_temp[head][TILE_ID][size][0] = _runningSumOfScore_w[head][TILE_ID][size];
                end

                calculatePMatrix #(
                    .inst_sig_width(inst_sig_width),
                    .inst_exp_width(inst_exp_width),
                    .inst_ieee_compliance(inst_ieee_compliance),
                    .inst_arch(inst_arch),
                    .row(SIZE_OF_BLOCK),
                    .col(SIZE_OF_BLOCK)
                ) CPM (
                    _runningMaxOfScore_w[head][TILE_ID],
                    _runningSumOfScore_w[head][TILE_ID],
                    _score_w[head][TILE_ID],
                    _P_w[head][TILE_ID]
                );
            end
        end
    end
endgenerate

task store_score;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK*NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _multQK_T[head][block][row][col] = _multQK_T_w[head][block][row][col];
                    _score[head][block][row][col] = _score_w[head][block][row][col];
                end
            end
        end
    end
end endtask;

task store_L_of_score;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK*NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                _runningMaxOfScore[head][block][row] = _runningMaxOfScore_w[head][block][row];
                _runningSumOfScore[head][block][row] = _runningSumOfScore_w[head][block][row];
            end
        end
    end
end endtask;

task store_P;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK*NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _P[head][block][row][col] = _P_w[head][block][row][col];
                end
            end
        end
    end
end endtask;

task store_O_Acc;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK*NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _O_ACC_temp[head][block][row][col] = _O_ACC_temp_w[head][block][row][col];
                    _O_ACC_final[head][block][row][col] = _O_ACC_final_w[head][block][row][col];
                end
            end
        end
    end
end endtask;

task store_head;
    integer head;
    integer block;
    integer row;
    integer col;
begin
    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        for(block=0 ; block<NUM_OF_BLOCK*NUM_OF_BLOCK ; block=block+1) begin
            for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
                for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
                    _head_out[head][block][row][col] = _head_out_w[head][block][row][col];
                end
            end
        end
    end
end endtask;

task store_output;
    integer token;
    integer dim;
begin
    for(token=0 ; token<NUM_OF_TOKEN ; token=token+1) begin
        for(dim=0 ; dim<NUM_OF_DIM ; dim=dim+1) begin
            _head_concate[token][dim] = _head_concate_w[token][dim];
            _output[token][dim] = _output_w[token][dim];
        end
    end
end endtask;


// =========================================================================================================== //
// Dumper
matrix_3d_csv_dumper #(
    NUM_OF_BLOCK-1, SIZE_OF_BLOCK-1, SIZE_OF_BLOCK-1,
    0,0,0,
    inst_sig_width,inst_exp_width,"block") block_dumper();

matrix_3d_csv_dumper #(
    NUM_OF_BLOCK-1, SIZE_OF_BLOCK-1, SIZE_OF_BLOCK-1,
    0,0,0,
    inst_sig_width,inst_exp_width,"-") tile_dumper();

matrix_3d_csv_dumper #(
    NUM_OF_BLOCK-1, SIZE_OF_BLOCK-1, 0,
    0,0,0,
    inst_sig_width,inst_exp_width,"-") running_dumper();

// matrix_3d_csv_dumper #(
//     NUM_OF_BLOCK*NUM_OF_BLOCK-1, SIZE_OF_BLOCK-1, SIZE_OF_BLOCK-1,
//     0,0,0,
//     inst_sig_width,inst_exp_width,"tile") tile_dumper();

matrix_2d_csv_dumper #(
    SIZE_OF_WEIGHT-1, SIZE_OF_WEIGHT-1,
    0,0,
    inst_sig_width,inst_exp_width) weight_dumper();

task export_input_to_csv;
    input integer is_hex;

    integer file;
    integer head;
begin
    if(is_hex === 1) file = $fopen(INPUT_HEX_CSV, "w");
    else file = $fopen(INPUT_FLOAT_CSV, "w");

    $fdisplay(file, "Pattern,%-d,", pat);
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "Head,%-2d,", head);
        $fdisplay(file, "K");
        block_dumper.dump(file, is_hex, _K[head]);
        $fwrite(file, "\n");

        $fdisplay(file, "K_T");
        block_dumper.dump(file, is_hex, _K_transpose[head]);
        $fwrite(file, "\n");

        $fdisplay(file, "Q");
        block_dumper.dump(file, is_hex, _Q[head]);
        $fwrite(file, "\n");

        $fdisplay(file, "V");
        block_dumper.dump(file, is_hex, _V[head]);
        $fwrite(file, "\n");
    end
    $fwrite(file, "\n");

    $fwrite(file, "Weight");
    weight_dumper.dump(file, is_hex, _weight);
    $fwrite(file, "\n");

    $fclose(file);
end endtask

task export_output_to_csv;
    input integer is_hex;

    integer file;
    integer head;
    integer tile;
    integer size;

begin
    if(is_hex === 1) file = $fopen(OUTPUT_HEX_CSV, "w");
    else file = $fopen(OUTPUT_FLOAT_CSV, "w");

    $fdisplay(file, "Pattern,%-d,", pat);
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "Q x K_T,%-2d,", head);
        for(tile=0 ; tile<NUM_OF_BLOCK ; tile=tile+1) begin
            $fdisplay(file, "Block : %2d ~ %-2d", tile*NUM_OF_BLOCK, (tile+1)*NUM_OF_BLOCK-1);
            tile_dumper.dump(file, is_hex, _multQK_T[head][tile*NUM_OF_BLOCK+:NUM_OF_BLOCK]);
            $fwrite(file, "\n");
        end
    end
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "Score,%-2d,", head);
        for(tile=0 ; tile<NUM_OF_BLOCK ; tile=tile+1) begin
            $fdisplay(file, "Block : %2d ~ %-2d", tile*NUM_OF_BLOCK, (tile+1)*NUM_OF_BLOCK-1);
            tile_dumper.dump(file, is_hex, _score[head][tile*NUM_OF_BLOCK+:NUM_OF_BLOCK]);
            $fwrite(file, "\n");
        end
    end
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "Running Max,%-2d,", head);
        for(tile=0 ; tile<NUM_OF_BLOCK ; tile=tile+1) begin
            $fdisplay(file, "Block : %2d ~ %-2d", tile*NUM_OF_BLOCK, (tile+1)*NUM_OF_BLOCK-1);
            running_dumper.dump(file, is_hex, _runningMaxOfScore_w_temp[head][tile*NUM_OF_BLOCK+:NUM_OF_BLOCK]);
            $fwrite(file, "\n");
        end
    end
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "Running Sum,%-2d,", head);
        for(tile=0 ; tile<NUM_OF_BLOCK ; tile=tile+1) begin
            $fdisplay(file, "Block : %2d ~ %-2d", tile*NUM_OF_BLOCK, (tile+1)*NUM_OF_BLOCK-1);
            running_dumper.dump(file, is_hex, _runningSumOfScore_w_temp[head][tile*NUM_OF_BLOCK+:NUM_OF_BLOCK]);
            $fwrite(file, "\n");
        end
    end
    $fwrite(file, "\n");

    for(head=1 ; head<=NUM_OF_HEAD ; head=head+1) begin
        $fdisplay(file, "P,%-2d,", head);
        for(tile=0 ; tile<NUM_OF_BLOCK ; tile=tile+1) begin
            $fdisplay(file, "Block : %2d ~ %-2d", tile*NUM_OF_BLOCK, (tile+1)*NUM_OF_BLOCK-1);
            tile_dumper.dump(file, is_hex, _P[head][tile*NUM_OF_BLOCK+:NUM_OF_BLOCK]);
            $fwrite(file, "\n");
        end
    end
    $fwrite(file, "\n");

    $fclose(file);
end endtask

endmodule

