module JPEG_helper();

// DCT
parameter SIZE_OF_BLOCK = 8;
parameter INPUT_BITS = 8;
parameter COEFF_BITS = 8;
parameter COEFF_FACTOR = 2;
parameter ROUND_BITS = 8 + 8 + 2;
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

task mutmax2;
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

function integer dct_round;
    input integer in;

    integer pos_in;
begin
    pos_in = in > 0 ? in : -in;
    dct_round = in > 0 ?
        (pos_in + 2 ** (ROUND_BITS-1)) >> ROUND_BITS :
        -((pos_in + 2 ** (ROUND_BITS-1)) >> ROUND_BITS);
end endfunction


endmodule