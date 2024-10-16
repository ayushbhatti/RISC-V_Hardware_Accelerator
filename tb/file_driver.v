module file_driver (
    clkIn,
    rstIn,
    dataAOut,
    dataBOut,
    validOut);
    
    parameter DATA_WIDTH = 32;
    
    input clkIn, rstIn;
    output [DATA_WIDTH-1:0] dataAOut, dataBOut;
    output validOut;
    
    reg validR;
    reg [DATA_WIDTH-1:0] dataAR;
    reg [DATA_WIDTH-1:0] dataBR;
    
    reg [DATA_WIDTH-1:0] fileDataA;
    reg [DATA_WIDTH-1:0] fileDataB;
    
    integer inputFile;
    
    initial begin
        inputFile = $fopen("input.txt", "r");
        if (inputFile == 0) begin
            $display("Could not open \"input.txt\"");
            $finish;
        end 
    end
    
    always @(posedge clkIn or posedge rstIn) begin
        if (rstIn) begin
            dataAR <= 0;
            dataBR <= 0;
            validR <= 0;
        end else begin
            dataAR <= 0;
            dataBR <= 0;
            validR <= 0;
            if (!$feof(inputFile)) begin
                $fscanf(inputFile, "%h %h\n", fileDataA, fileDataB);
                dataAR <= fileDataA;
                dataBR <= fileDataB;
                validR <= 1;
            end
        end
    end
    
    assign validOut = validR;
    assign dataAOut = dataAR;
    assign dataBOut = dataBR;
    
endmodule