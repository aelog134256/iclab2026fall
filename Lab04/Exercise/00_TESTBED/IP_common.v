// Matrix multiplication
module matmul
#(
    parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,

    parameter m = 2,
    parameter n = 3,
    parameter k = 2
)
(
    input  [inst_sig_width+inst_exp_width:0] A [m-1:0][n-1:0],
    input  [inst_sig_width+inst_exp_width:0] B [n-1:0][k-1:0],
    output wire [inst_sig_width+inst_exp_width:0] C [m-1:0][k-1:0]
);

    initial begin
        if (m < 1 || n < 1 || k < 1) begin
            $display("[ERROR] [Parameter] Matrix dimensions must be positive");
            $finish;
        end
    end

    genvar i, j, t;

    generate
        for (i = 0; i < m; i = i + 1) begin : gen_row
            for (j = 0; j < k; j = j + 1) begin : gen_col

                // Products for A[i][t] * B[t][j]
                wire [inst_sig_width+inst_exp_width:0]
                    _mult [n-1:0];

                // Accumulation chain
                wire [inst_sig_width+inst_exp_width:0]
                    _sum [n-1:0];

                for (t = 0; t < n; t = t + 1) begin : gen_mult
                    DW_fp_mult
                    #(
                        inst_sig_width,
                        inst_exp_width,
                        inst_ieee_compliance
                    )
                    M0 (
                        .a   (A[i][t]),
                        .b   (B[t][j]),
                        .rnd (3'd0),
                        .z   (_mult[t]),
                        .status()
                    );
                end

                // First product initializes the sum
                assign _sum[0] = _mult[0];

                for (t = 1; t < n; t = t + 1) begin : gen_add
                    DW_fp_addsub
                    #(
                        inst_sig_width,
                        inst_exp_width,
                        inst_ieee_compliance
                    )
                    A0 (
                        .a   (_sum[t-1]),
                        .b   (_mult[t]),
                        .op  (1'd0),
                        .rnd (3'd0),
                        .z   (_sum[t]),
                        .status()
                    );
                end

                assign C[i][j] = _sum[n-1];

            end
        end
    endgenerate

endmodule

// Dot product
module mac
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 9
)
(
    input  [inst_sig_width+inst_exp_width:0] in1[num_of_input-1:0],
    input  [inst_sig_width+inst_exp_width:0] in2[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] out
);
    initial begin
        if(num_of_input < 2) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 2");
            $finish;
        end
    end
    genvar i;
    generate
        for(i=0 ; i<num_of_input ; i=i+1) begin : gen_conv_mult
            wire [inst_sig_width+inst_exp_width:0] _mult;
            DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                M0 (.a(in1[i]), .b(in2[i]), .rnd(3'd0), .z(_mult), .status());
        end
    endgenerate
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_conv_add
            wire [inst_sig_width+inst_exp_width:0] _add;
            if(i==1) begin
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_conv_mult[0]._mult), .b(gen_conv_mult[1]._mult),
                        .op(1'd0), .rnd(3'd0), .z(_add), .status());
            end
            else begin
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_conv_add[i-1]._add), .b(gen_conv_mult[i]._mult),
                        .op(1'd0), .rnd(3'd0), .z(_add), .status());
            end
        end
        assign out = gen_conv_add[num_of_input-1]._add;
    endgenerate
endmodule


module calculatePMatrix
#(
    parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter row                  = 2,
    parameter col                  = 2
)
(
    input  [inst_sig_width+inst_exp_width:0] rowMax [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] rowSum [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] in [row-1:0][col-1:0],
    output wire [inst_sig_width+inst_exp_width:0] out [row-1:0][col-1:0]
);

    initial begin
        if (row < 1 || col < 1) begin
            $display("[ERROR] [Parameter] row and col must be positive");
            $finish;
        end
    end

    genvar i, j;
    generate
        for (i = 0; i < row; i = i + 1) begin : gen_row
            for (j = 0; j < col; j = j + 1) begin : gen_scale
                // Step 1: Subtract row max
                wire [inst_sig_width+inst_exp_width:0] shifted;
                wire [inst_sig_width+inst_exp_width:0] exp;
                DW_fp_addsub
                #(inst_sig_width, inst_exp_width, inst_ieee_compliance, 0)
                    A_sub (
                        .a      (in[i][j]),
                        .b      (rowMax[i]),
                        .op     (1'd1),
                        .rnd    (3'd0),
                        .z      (shifted),
                        .status ()
                    );

                DW_fp_exp 
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
                    E0 (.a(shifted), .z(exp), .status());

                DW_fp_div
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
                    D0 (.a(exp), .b(rowSum[i]), .rnd(3'd0), .z(out[i][j]), .status());
            end

        end
    endgenerate

endmodule

// Running maximum update
module runningMax
#(
    parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,

    parameter row = 2,
    parameter col = 2
)
(
    input  [inst_sig_width+inst_exp_width:0] m_prev [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] in [row-1:0][col-1:0],
    output wire [inst_sig_width+inst_exp_width:0] m_next [row-1:0]
);

    initial begin
        if (row < 1 || col < 1) begin
            $display("[ERROR] [Parameter] row and col must be positive");
            $finish;
        end
    end

    genvar i, j;

    generate
        for (i = 0; i < row; i = i + 1) begin : gen_row

            // Maximum value within the current Score tile row
            wire [inst_sig_width+inst_exp_width:0] _tile_max [col-1:0];

            // First element initializes the tile maximum
            assign _tile_max[0] = in[i][0];

            // Find maximum among the current tile elements
            for (j = 1; j < col; j = j + 1) begin : gen_tile_max

                wire _agtb;

                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    C0 (
                        .a       (_tile_max[j-1]),
                        .b       (in[i][j]),
                        .agtb    (_agtb),
                        .zctr    (1'd0)
                    );

                assign _tile_max[j] =
                    _agtb ? _tile_max[j-1] : in[i][j];

            end

            // Update running maximum
            wire _prev_gt_tile;

            DW_fp_cmp
            #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                C_update (
                    .a       (m_prev[i]),
                    .b       (_tile_max[col-1]),
                    .agtb    (_prev_gt_tile),
                    .zctr    (1'd0)
                );

            assign m_next[i] =
                _prev_gt_tile ? m_prev[i] : _tile_max[col-1];

        end
    endgenerate

endmodule

// Running sum update
module runningSum
#(
    parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,

    parameter row = 2,
    parameter col = 2
)
(
    input  [inst_sig_width+inst_exp_width:0] m_prev [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] m_next [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] l_prev [row-1:0],
    input  [inst_sig_width+inst_exp_width:0] in [row-1:0][col-1:0],
    output wire [inst_sig_width+inst_exp_width:0] l_next [row-1:0]
);

    initial begin
        if (row < 1 || col < 1) begin
            $display("[ERROR] [Parameter] row and col must be positive");
            $finish;
        end
    end

    genvar i, j;

    generate
        for (i = 0; i < row; i = i + 1) begin : gen_row

            wire [inst_sig_width+inst_exp_width:0] _delta_old;
            wire [inst_sig_width+inst_exp_width:0] _alpha;
            wire [inst_sig_width+inst_exp_width:0] _old_sum;

            wire [inst_sig_width+inst_exp_width:0] _delta [col-1:0];
            wire [inst_sig_width+inst_exp_width:0] _exp_score [col-1:0];
            wire [inst_sig_width+inst_exp_width:0] _score_sum [col-1:0];

            // delta_old = m_prev - m_next
            DW_fp_addsub
            #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                A_sub_old (
                    .a      (m_prev[i]),
                    .b      (m_next[i]),
                    .op     (1'd1),
                    .rnd    (3'd0),
                    .z      (_delta_old),
                    .status ()
                );

            // alpha = exp(m_prev - m_next)
            DW_fp_exp
            #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                E_alpha (
                    .a      (_delta_old),
                    .z      (_alpha),
                    .status ()
                );

            // old_sum = alpha * l_prev
            DW_fp_mult
            #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                M_old_sum (
                    .a      (_alpha),
                    .b      (l_prev[i]),
                    .rnd    (3'd0),
                    .z      (_old_sum),
                    .status ()
                );

            // exp(in[i][j] - m_next[i])
            for (j = 0; j < col; j = j + 1) begin : gen_exp

                DW_fp_addsub
                #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    A_sub_score (
                        .a      (in[i][j]),
                        .b      (m_next[i]),
                        .op     (1'd1),
                        .rnd    (3'd0),
                        .z      (_delta[j]),
                        .status ()
                    );

                DW_fp_exp
                #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    E_score (
                        .a      (_delta[j]),
                        .z      (_exp_score[j]),
                        .status ()
                    );

            end

            // Sum exponentials within the current tile row
            assign _score_sum[0] = _exp_score[0];

            for (j = 1; j < col; j = j + 1) begin : gen_sum

                DW_fp_addsub
                #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    A_sum (
                        .a      (_score_sum[j-1]),
                        .b      (_exp_score[j]),
                        .op     (1'd0),
                        .rnd    (3'd0),
                        .z      (_score_sum[j]),
                        .status ()
                    );

            end

            // l_next = alpha * l_prev + sum(exp(score - m_next))
            DW_fp_addsub
            #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                A_update (
                    .a      (_old_sum),
                    .b      (_score_sum[col-1]),
                    .op     (1'd0),
                    .rnd    (3'd0),
                    .z      (l_next[i]),
                    .status ()
                );

        end
    endgenerate

endmodule

module findMinAndMax
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 4
)
(
    input  [inst_sig_width+inst_exp_width:0] in[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] min, max
);
    initial begin
        if(num_of_input < 2) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 2");
            $finish;
        end
    end
    genvar i;
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_comp
            wire [inst_sig_width+inst_exp_width:0] _min, _max;
            if(i===1) begin
                wire flag;
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    C0 (.a(in[i-1]), .b(in[i]), .agtb(flag), .zctr(1'd0));

                assign _min = flag==1 ? in[i] : in[i-1];
                assign _max = flag==1 ? in[i-1] : in[i];
            end
            else begin
                wire flagMin, flagMax;
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    Cmin (.a(gen_comp[i-1]._min), .b(in[i]), .agtb(flagMin), .zctr(1'd0));
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    Cmax (.a(gen_comp[i-1]._max), .b(in[i]), .agtb(flagMax), .zctr(1'd0));

                assign _min = flagMin==1 ? in[i] : gen_comp[i-1]._min;
                assign _max = flagMax==1 ? gen_comp[i-1]._max : in[i];
            end
        end
        assign min = gen_comp[num_of_input-1]._min;
        assign max = gen_comp[num_of_input-1]._max;
    endgenerate

endmodule

module sigmoid
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg), .status());
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp), .status());
    
    DW_fp_addsub // 1+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp), .op(1'd0), .rnd(3'd0), .z(deno), .status());
    
    DW_fp_div // 1 / [1+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(float_gain1), .b(deno), .rnd(3'd0), .z(out), .status());
endmodule

module swish
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg), .status());
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp), .status());
    
    DW_fp_addsub // 1+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp), .op(1'd0), .rnd(3'd0), .z(deno), .status());
    
    DW_fp_div // 1 / [1+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(in), .b(deno), .rnd(3'd0), .z(out), .status());
endmodule

module tanh
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp_pos;
    wire [inst_sig_width+inst_exp_width:0] exp_neg;
    wire [inst_sig_width+inst_exp_width:0] nume;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg), .status());
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp_neg), .status());

    DW_fp_exp // exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E1 (.a(in), .z(exp_pos), .status());

    //

    DW_fp_addsub // exp(x)-exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(exp_pos), .b(exp_neg), .op(1'd1), .rnd(3'd0), .z(nume), .status());

    DW_fp_addsub // exp(x)+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A1 (.a(exp_pos), .b(exp_neg), .op(1'd0), .rnd(3'd0), .z(deno), .status());

    DW_fp_div // [exp(x)-exp(-x)] / [exp(x)+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(nume), .b(deno), .rnd(3'd0), .z(out), .status());

endmodule

module softmax
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 3
)
(
    input  [inst_sig_width+inst_exp_width:0] in_z,
    input  [inst_sig_width+inst_exp_width:0] in[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] out
);
    initial begin
        if(num_of_input < 1) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 1");
            $finish;
        end
    end
    genvar i;
    // exp(x)
    generate
        for(i=0 ; i<num_of_input ; i=i+1) begin : gen_exp
            wire[inst_sig_width+inst_exp_width:0] exp_pos;
            DW_fp_exp 
            #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
                E0 (.a(in[i]), .z(exp_pos), .status());
        end
    endgenerate
    // sigma(exp(x))
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_exp_sum
            wire[inst_sig_width+inst_exp_width:0] exp_sum;
            if(i===1) begin
                DW_fp_addsub
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_exp[i-1].exp_pos), .b(gen_exp[i].exp_pos), .op(1'd0), .rnd(3'd0), .z(exp_sum), .status());
            end
            else begin
                DW_fp_addsub 
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_exp_sum[i-1].exp_sum), .b(gen_exp[i].exp_pos), .op(1'd0), .rnd(3'd0), .z(exp_sum), .status());
            end
        end
    endgenerate
    // exp(in_z) / sigma(exp(x))
    wire[inst_sig_width+inst_exp_width:0] exp_pos_z;
    wire[inst_sig_width+inst_exp_width:0] res;
    DW_fp_exp 
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(in_z), .z(exp_pos_z), .status());
    DW_fp_div
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(exp_pos_z), .b(gen_exp_sum[num_of_input-1].exp_sum), .rnd(3'd0), .z(res), .status());
    assign out = res;
endmodule

module softplus
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] exp_pos;
    wire [inst_sig_width+inst_exp_width:0] plus;
    wire [7:0] status;
    
    DW_fp_exp // exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E1 (.a(in), .z(exp_pos), .status());

    DW_fp_addsub // 1+exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp_pos), .op(1'd0), .rnd(3'd0), .z(plus), .status());

    DW_fp_ln // ln(1+exp(x))
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0, inst_arch)
        L0 (.a(plus), .status(status), .z(out));

endmodule

module relu
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    assign out = in[inst_sig_width+inst_exp_width] ? 0 : in;
endmodule

module leakyRelu
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] one_percent_factor = 32'h3c23d70a; // 0.01
    wire [inst_sig_width+inst_exp_width:0] one_percent_of_value;

    DW_fp_mult // x*0.01
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(one_percent_factor), .rnd(3'd0), .z(one_percent_of_value), .status());

    assign out = in[inst_sig_width+inst_exp_width] ? one_percent_of_value : in;
endmodule