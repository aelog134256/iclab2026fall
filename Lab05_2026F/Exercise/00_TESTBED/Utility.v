`timescale 1ns/10ps

//=====================================================================
// Display Utitlity
//=====================================================================

module display_helper();

task display_full_seperator; begin
    // Full
    $system("printf '%*s\\n' `tput cols` '' | tr ' ' '='");
    // Half
    // $system("cols=`tput cols`; half=$((cols/2-6)); printf '%*s\\n' $half ''");
end endtask
endmodule

//=====================================================================
// Arithmetic
//=====================================================================

module arithmetic_helper
#(
    parameter inst_sig_width = 23,
    parameter inst_exp_width = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch_type = 0,
    parameter inst_arch = 0,
    parameter real_sig_width = 52, // verilog real (double)
    parameter real_exp_width = 11  // verilog real (double)
)();

function is_valid_float_of_real;
    input real in;

    reg[real_sig_width+real_exp_width:0] real_bits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    is_valid_float_of_real = 1;
    real_bits = $realtobits(in);
    if(real_bits[real_sig_width+:real_exp_width]+double_shift-float_shift > ((2**inst_exp_width)-1))begin
        $display("[WARNING] [FUNCTION] Exponent of real exceeds the defined range of float ( %d )", real_bits[real_sig_width+:real_exp_width]);
        is_valid_float_of_real = 0;
    end
end endfunction

function [inst_sig_width+inst_exp_width:0] real_to_float_bits;
    input real in;

    reg[real_sig_width+real_exp_width:0] real_bits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    real_bits = $realtobits(in);
    if(!is_valid_float_of_real(in))begin
        $display("[ERROR] [FUNCTION] Exponent of real exceeds the defined range of float");
        $finish;
    end
    // sign
    real_to_float_bits[inst_sig_width+inst_exp_width]  = real_bits[real_sig_width+real_exp_width];
    // exponent
    real_to_float_bits[inst_sig_width+:inst_exp_width] = real_bits[real_sig_width+:real_exp_width]+double_shift-float_shift;
    // mantissa(fraction)
    real_to_float_bits[0+:inst_sig_width]              = real_bits[(real_sig_width-1)-:inst_sig_width];
end endfunction

function real float_bits_to_real;
    input reg[inst_sig_width+inst_exp_width:0] in;

    reg[real_sig_width+real_exp_width:0] real_bits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    real_bits = 0;
    // sign
    real_bits[real_sig_width+real_exp_width] = in[inst_sig_width+inst_exp_width];
    // exponent
    real_bits[real_sig_width+:real_exp_width] = in[inst_sig_width+:inst_exp_width]+float_shift-double_shift;
    // mantissa(fraction)
    real_bits[(real_sig_width-1)-:inst_sig_width] = in[0+:inst_sig_width];

    float_bits_to_real = (in === 'dx) ? 0.0/0.0 : $bitstoreal(real_bits);

end endfunction

endmodule

//=====================================================================
// Dumper
//=====================================================================

module matrix_hex_1d_csv_dumper
#(
    parameter end1 = 0,
    parameter start1 = 0,
    parameter inst_sig_width = 23,
    parameter inst_exp_width = 8,
    parameter name = ""
)();

parameter real_sig_width = 52; // verilog real (double)
parameter real_exp_width = 11; // verilog real (double)
integer idx1;

task dump; 
    input integer file;
    input is_hex;
    input [inst_sig_width+inst_exp_width:0] in[end1:start1];
begin
    $fwrite(file, ",");
    for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
        $fwrite(file, "%2d,", idx1);
    end
    $fwrite(file, "\n");
    $fwrite(file, "%0s,", name);
    for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
        if(is_hex === 1) $fwrite(file, "%8h,", in[idx1]);
        else $fwrite(file, "%f,", arithmetic_helper.float_bits_to_real(in[idx1]));
    end
    $fwrite(file, "\n");
end endtask;

endmodule

module matrix_hex_2d_csv_dumper
#(
    parameter end1 = 0,
    parameter end2 = 0,
    parameter start1 = 0,
    parameter start2 = 0,
    parameter inst_sig_width = 23,
    parameter inst_exp_width = 8,
    parameter prefix_col = "",
    parameter postfix_col = "",
    parameter prefix_row = "",
    parameter postfix_row = ""
)();

parameter real_sig_width = 52; // verilog real (double)
parameter real_exp_width = 11; // verilog real (double)
integer idx1,idx2;

task dump; 
    input integer file;
    input is_hex;
    input [inst_sig_width+inst_exp_width:0] in[end1:start1][end2:start2];
begin
    $fwrite(file, ",");
    for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
        $fwrite(file, "%0s%2d%0s,", prefix_col, idx1, postfix_col);
    end
    $fwrite(file, "\n");
    for(idx2=start2 ; idx2<=end2 ; idx2=idx2+1) begin
        $fwrite(file, "%0s%2d%0s,", prefix_row, idx2, postfix_row);
        for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
            if(is_hex === 1) $fwrite(file, "%8h,", in[idx1][idx2]);
            else $fwrite(file, "%f,", arithmetic_helper.float_bits_to_real(in[idx1][idx2]));
        end
        $fwrite(file, "\n");
    end
end endtask;

endmodule

module matrix_int_2d_csv_dumper
#(
    parameter end1 = 0,
    parameter end2 = 0,
    parameter start1 = 0,
    parameter start2 = 0,
    parameter space_per_row = 0,
    parameter space_per_col = 0,
    parameter prefix_col = "",
    parameter postfix_col = "",
    parameter prefix_row = "",
    parameter postfix_row = ""
)();

integer idx1,idx2;

task dump; 
    input integer file;
    input integer in[end1:start1][end2:start2];

    integer count1;
    integer count2;
begin
    count1 = 0;
    $fwrite(file, ",");
    for(idx2=start2 ; idx2<=end2 ; idx2=idx2+1) begin
        $fwrite(file, "%0s%3d%0s,", prefix_col, idx2, postfix_col);
        count1 = count1 + 1;
        if(count1 % space_per_col == 0 && count1 != 0 && space_per_col != 0)
            $fwrite(file, ",");
    end
    count1 = 0;
    $fwrite(file, "\n");
    for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
        $fwrite(file, "%0s%4d%0s,", prefix_row, idx1, postfix_row);
        count2 = 0;
        for(idx2=start2 ; idx2<=end2 ; idx2=idx2+1) begin
            $fwrite(file, "%4d,", in[idx1][idx2]);
            count2 = count2 + 1;
            if(count2 % space_per_col == 0  && count2 != 0 && space_per_col != 0)
                $fwrite(file, ",");
        end
        $fwrite(file, "\n");

        count1 = count1 + 1;
        if(count1 % space_per_row == 0  && count1 != 0 && space_per_row != 0)
            $fwrite(file, "\n");
    end
end endtask;

endmodule

module matrix_hex_3d_csv_dumper
#(
    parameter end1 = 0,
    parameter end2 = 0,
    parameter end3 = 0,
    parameter start1 = 0,
    parameter start2 = 0,
    parameter start3 = 0,
    parameter inst_sig_width = 23,
    parameter inst_exp_width = 8,
    parameter prefix = ""
)();

parameter real_sig_width = 52; // verilog real (double)
parameter real_exp_width = 11; // verilog real (double)
integer idx1,idx2,idx3;

task dump; 
    input integer file;
    input is_hex;
    input [inst_sig_width+inst_exp_width:0] in[end1:start1][end2:start2][end3:start3];
begin
    for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
        $fwrite(file, "[%0s%2d],", prefix, idx1);
        // idx1 index
        for(idx3=start3 ; idx3<=end3 ; idx3=idx3+1) begin
            $fwrite(file, "%2d,", idx3);
        end
        $fwrite(file, ",");
    end
    $fwrite(file, "\n");
    for(idx2=start2 ; idx2<=end2 ; idx2=idx2+1) begin
        for(idx1=start1 ; idx1<=end1 ; idx1=idx1+1) begin
            // idx2 index and value
            $fwrite(file, "%2d,", idx2);
            for(idx3=start3 ; idx3<=end3 ; idx3=idx3+1) begin
                if(is_hex === 1) $fwrite(file, "%8h,", in[idx1][idx2][idx3]);
                else $fwrite(file, "%f,", arithmetic_helper.float_bits_to_real(in[idx1][idx2][idx3]));
            end
            $fwrite(file, ",");
        end
        $fwrite(file, "\n");
    end
end endtask;

endmodule