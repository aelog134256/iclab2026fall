// TODO
// Load file

module JPEG_helper();

// DCT
parameter SIZE_OF_BLOCK = 8;
parameter INPUT_BITS = 8;
parameter COEFF_BITS = 8;
parameter COEFF_FACTOR = 2;

parameter FOLDER = "00_TESTBED";
parameter DC_HUFFMAN_FILE = "dc_huffman_lut.txt";
parameter AC_HUFFMAN_FILE = "ac_huffman_lut.txt";
parameter SYMBOL_OF_ZRL = 8'hF0;
parameter NUM_OF_ZRL = 16;
parameter NUM_DC_HUFFMAN = 12;
parameter NUM_AC_HUFFMAN = 256;
parameter NUM_OF_BITS = 256;

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

integer dc_huffman_code[NUM_DC_HUFFMAN-1:0];
integer dc_huffman_length[NUM_DC_HUFFMAN-1:0];

integer ac_huffman_code[NUM_AC_HUFFMAN-1:0];
integer ac_huffman_length[NUM_AC_HUFFMAN-1:0];
integer ac_huffman_valid[NUM_AC_HUFFMAN-1:0];

initial begin
    load_dc_huffman;
    load_ac_huffman;
end

task load_dc_huffman;
    integer file;
    integer scan_result;
    integer category;
    integer length;
    integer code;
    reg [1023:0] header;
    reg [NUM_OF_BITS-1:0] code_bits;
begin
    file = $fopen({"../", FOLDER, "/", DC_HUFFMAN_FILE}, "r");

    if (file == 0) begin
        $display("[ERROR] Cannot open %s/%s", FOLDER, DC_HUFFMAN_FILE);
        $finish;
    end

    // Skip header
    scan_result = $fgets(header, file);

    // Initialize
    for (category=0 ; category < NUM_DC_HUFFMAN ; category=category+1) begin
        dc_huffman_code[category]   = 0;
        dc_huffman_length[category] = 0;
    end

    // Read LUT
    while (!$feof(file)) begin
        scan_result =
            $fscanf(file, "%d %d %h %s", category, length, code, code_bits);

        if (scan_result == 4) begin
            dc_huffman_code[category]   = code;
            dc_huffman_length[category] = length;
        end
    end

    $fclose(file);
    $display("[INFO] DC Huffman LUT loaded.");
end endtask


task load_ac_huffman;
    integer file;
    integer scan_result;
    integer symbol;
    integer run;
    integer size;
    integer length;
    integer code;
    reg [1024:0] header;
    reg [NUM_OF_BITS-1:0] code_bits;
begin
    file = $fopen({"../", FOLDER, "/", AC_HUFFMAN_FILE}, "r");

    if (file == 0) begin
        $display("[ERROR] Cannot open %s/%s",FOLDER, AC_HUFFMAN_FILE);
        $finish;
    end

    // Skip header
    scan_result = $fgets(header, file);

    // Initialize
    for (symbol=0 ; symbol<NUM_AC_HUFFMAN ; symbol=symbol+1) begin
        ac_huffman_code[symbol]   = 0;
        ac_huffman_length[symbol] = 0;
        ac_huffman_valid[symbol]  = 0;
    end

    // Read LUT
    while (!$feof(file)) begin
        scan_result =
            $fscanf(file, "%h %d %d %d %h %s", symbol, run, size, length, code, code_bits);

        if (scan_result == 6) begin
            ac_huffman_code[symbol]   = code;
            ac_huffman_length[symbol] = length;
            ac_huffman_valid[symbol]  = 1;
        end
    end

    $fclose(file);
    $display("[INFO] AC Huffman LUT loaded.");
end endtask


// Utility
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
    integer q_to_z[SIZE_OF_BLOCK-1:0][SIZE_OF_BLOCK-1:0];
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

task zigzag_row_col;
    input integer index;
    output integer row;
    output integer col;

    integer i, j, s, k;
    integer z_to_row[SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];
    integer z_to_col[SIZE_OF_BLOCK*SIZE_OF_BLOCK-1:0];
begin
     k = 0;
    for (s=0 ; s<2*SIZE_OF_BLOCK-1; s=s+1) begin
        if (s%2 == 0) begin
            // Even diagonal: bottom to top
            for (i=SIZE_OF_BLOCK-1; i>=0; i=i-1) begin
                j = s-i;

                if (j>=0 && j<SIZE_OF_BLOCK) begin
                    z_to_row[k] = i;
                    z_to_col[k] = j;
                    k = k + 1;
                end
            end
        end
        else begin
            // Odd diagonal: top to bottom
            for (i=0 ; i<SIZE_OF_BLOCK ; i=i+1) begin
                j = s-i;

                if (j>=0 && j<SIZE_OF_BLOCK) begin
                    z_to_row[k] = i;
                    z_to_col[k] = j;
                    k = k + 1;
                end
            end
        end
    end
    row = z_to_row[index];
    col = z_to_col[index];

end endtask



endmodule