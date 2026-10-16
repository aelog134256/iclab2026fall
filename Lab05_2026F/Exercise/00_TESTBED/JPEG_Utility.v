module JPEG_helper();

// DCT
parameter SIZE_OF_BLOCK = 8;
parameter INPUT_BITS = 8;
parameter COEFF_BITS = 8;
parameter COEFF_FACTOR = 2;
integer dct_coeff[0:SIZE_OF_BLOCK-1][0:SIZE_OF_BLOCK-1]
    = '{
        '{ 181, 181, 181, 181, 181, 181, 181, 181},
        '{ 251, 213, 142,  50, -50,-142,-213,-251},
        '{ 237,  98, -98,-237,-237, -98,  98, 237},
        '{ 213, -50,-251,-142, 142, 251,  50,-213},
        '{ 181,-181,-181, 181, 181,-181,-181, 181},
        '{ 142,-251,  50, 213,-213, -50, 251,-142},
        '{  98,-237, 237, -98, -98, 237,-237,  98},
        '{  50,-142, 213,-251, 251,-213, 142, -50}
    };

integer quant_coeff[0:SIZE_OF_BLOCK-1][0:SIZE_OF_BLOCK-1]
    = '{
        '{ 4, 3, 3, 4, 5, 5, 6, 6},
        '{ 4, 4, 4, 4, 5, 6, 6, 6},
        '{ 4, 4, 4, 5, 5, 6, 6, 6},
        '{ 4, 4, 4, 5, 6, 6, 6, 6},
        '{ 4, 4, 5, 6, 6, 7, 7, 6},
        '{ 5, 5, 6, 6, 6, 7, 7, 7},
        '{ 6, 6, 6, 6, 7, 7, 7, 7},
        '{ 6, 7, 7, 7, 7, 7, 7, 7}
    };

task mutmax1;
    input integer  a[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    input integer  b[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    output integer c[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];

    integer row, col, inner;
    integer temp;
begin
    for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
            temp = 0;
            for(inner=0 ; inner<SIZE_OF_BLOCK ; inner=inner+1) begin
                temp = temp + a[row][inner] * b[inner][col];
            end
            c[row][col] = temp;
        end
    end
end endtask

task mutmax_by_col;
    input integer  a[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    input integer  b[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    output integer c[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];

    integer row, col, inner;
    integer temp;
begin
    for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
            temp = 0;
            for(inner=0 ; inner<SIZE_OF_BLOCK ; inner=inner+1) begin
                temp = temp + a[row][inner] * b[col][inner];
            end
            c[row][col] = temp;
        end
    end
end endtask

task mutmax_by_row;
    input integer  a[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    input integer  b[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
    output integer c[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];

    integer row, col, inner;
    integer temp;
begin
    for(row=0 ; row<SIZE_OF_BLOCK ; row=row+1) begin
        for(col=0 ; col<SIZE_OF_BLOCK ; col=col+1) begin
            temp = 0;
            for(inner=0 ; inner<SIZE_OF_BLOCK ; inner=inner+1) begin
                temp = temp + a[inner][row] * b[inner][col];
            end
            c[row][col] = temp;
        end
    end
end endtask

function integer round_s;
    input integer in;
    input integer round_bits;

    integer pos_in;
begin
    pos_in = in > 0 ? in : -in;
    round_s = in > 0 ?
        (pos_in + 2 ** (round_bits-1)) >> round_bits :
        -((pos_in + 2 ** (round_bits-1)) >> round_bits);
end endfunction

function integer zigzag_index;
    input integer row;
    input integer col;

    integer i, j, s, k;
    integer q_to_z[SIZE_OF_BLOCK][SIZE_OF_BLOCK];
begin
     k = 0;
    for (s=0 ; s<2*SIZE_OF_BLOCK-1; s=s+1) begin
        if (s%2 == 0) begin
            // Even diagonal: bottom to top
            for (i=SIZE_OF_BLOCK-1; i>=0; i=i-1) begin
                j = s-i;

                if (j>=0 && j<SIZE_OF_BLOCK) begin
                    q_to_z[i][j] = k;
                    k = k + 1;
                end
            end
        end
        else begin
            // Odd diagonal: top to bottom
            for (i=0 ; i<SIZE_OF_BLOCK ; i=i+1) begin
                j = s-i;

                if (j>=0 && j<SIZE_OF_BLOCK) begin
                    q_to_z[i][j] = k;
                    k = k + 1;
                end
            end
        end
    end
    zigzag_index = q_to_z[row][col];
end endfunction


endmodule