module cnn_hw_accelerator (
    clkIn;
    rstIn;
    startIn;
    filtRowsIn;
    filtColsIn;
    dataRowsIn;
    dataColsIn;
    addrIn;
    wrEnIn;
    wrDataIn;
    dataIn;
    readyIn;
    validOut;
    dataOut;

    // Configuration of RISCV bus interface
    parameter BUS_ADDR_WIDTH  = 32;
    parameter BUS_DATA_WIDTH  = 64;
    parameter BUS_WE_WIDTH    = BUS_DATA_WIDTH/8;
    
    // Floating-point hardware accelerator configuration
    // Standard single precision
    parameter FRAC_WIDTH      = 24;
    parameter EXP_WIDTH       = 8;
    
    // Multiply and accumulate input width
    parameter VECTOR_SIZE     = 8;
    
    // Maximum size of input matrices (in elements)
    parameter MAX_SIZE        = 4096;

    // Derived vector size parameters
    parameter VECTOR_SIZE_LOG2 = $clog2(VECTOR_SIZE);
    
    // Derived RAM parameters
    localparam RAM_DEPTH      = MAX_SIZE/VECTOR_SIZE;
    localparam RAM_ADDR_WIDTH = $clog2(RAM_DEPTH);
    localparam RAM_DATA_WIDTH = FRAC_WIDTH + EXP_WIDTH;
    localparam RAM_WE_WIDTH   = RAM_DATA_WIDTH/8;  
    
    // Constants for selecting relevant bits of address
    localparam NUM_BYTES      = RAM_WE_WIDTH*VECTOR_SIZE;
    localparam ADDR_LO        = $clog2(NUM_BYTES);
    localparam ADDR_HI        = RAM_ADDR_WIDTH + ADRR_LO - 1;

    // Constants for mapping write enable bits
    localparam GROUP_SIZE     = BUS_WE_WIDTH/RAM_WE_WIDTH
    localparam NUM_GROUPS     = NUM_BYTES/BUS_WE_WIDTH
        
    input clkIn;
    input rstIn;
    
    input [BUS_ADDR_WIDTH-1:0] addrIn;
    input [  BUS_WE_WIDTH-1:0] wrEnIn;
    input [BUS_DATA_WIDTH-1:0] wrDataIn;
    
    input  readyIn;
    output validOut;
    output [DATA_WIDTH-1:0] dataOut;
    
    reg [ADDR_WIDTH-1:0] addrR [0:VECTOR_SIZE-1];
    reg validR [VECTOR_SIZE-1];
    reg lastR;
    
    wire fifoWrReady;
    
    genvar i;
    generate
        
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            localparam WE_LO   = (i % GROUP_SIZE) * RAM_WE_WIDTH;
            localparam WE_HI   = WE_LO + RAM_WE_WIDTH - 1;
            localparam DATA_LO = (i % GROUP_SIZE) * RAM_DATA_WIDTH;
            localparam DATA_HI = DATA_LO + RAM_DATA_WIDTH - 1;
            
            wire [RAM_ADDR_WIDTH-1:0] busAddr;
            wire [RAM_DATA_WIDTH-1:0] busWrData;
            wire [  RAM_WE_WIDTH-1:0] busWrEn;
            
            assign busAddr   = addrIn  [ADDR_HI:ADDR_LO];
            assign busWrData = wrDataIn[DATA_HI:DATA_LO];
            assign busWrEn   = wrEnIn  [  WE_HI:WE_LO  ];

              
        
        if (NUM_BYTES >= BUS_WE_WIDTH) begin
            ADDR_WIDTH = NUM_BYTES/BUS_WE_WIDTH
        end else begin
            
        end
        
        if (addrIn(WE
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            sp_ram mem_i(
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrIn(addrR[i]),
                .wrEnIn(),
                .wrDataIn(),
                .rdEnIn(validR[i]),
                .rdDataOut(ramData[i]),
                .rdAckOut(ramValid[i]))
        end
    endgenerate
    
    baseAddrR   <= baseAddrR + 1;
    
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            always @(posedge clkIn) begin
                addrR[i] <= addrR[i] + VECTOR_SIZE;
                if (addrR[i] < endAddrR) begin
                    addrR[i] <= ;
                else
                    addrR[i] <= addrR[i] + VECTOR_SIZE;
                end
            end
        end
    endgenerate
    
    // Row Index Counter
    wire rowAdv;
    wire rowClr;
    wire rowDoneR;
    wire [CNT_WIDTH-1:0] rowCntR;
    
    // Column Index Counter
    wire colAdv;
    wire colClr;
    wire colDoneR;
    wire [CNT_WIDTH-1:0] colCntR;
    
    // Base Address Counter
    wire baseAdv;
    wire baseClr;
    wire baseDoneR;
    wire [CNT_WIDTH-1:0] baseCntR;
    
    // Counter control signals
    assign baseAdv = rowDoneR & colDoneR & fifoWrReady;
    assign baseClr = !validR & fifoWrReady;
    
    assign colAdv  = rowDoneR;
    assign colClr  = baseClr | baseAdv;
    
    assign rowAdv  = 1;
    assign rowClr  = colClr | (colAdv & !colClr);
    
    // Row Index Counter
    counter #(
        .CNT_WIDTH(CNT_WIDTH)) row_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(rowClr),
        .advIn(rowAdv),
        .endValIn(maxRowCntR),
        .cntOut(rowCntR),
        .doneOut(rowDoneR));
       
    // Column Index Counter
    counter #(
        .CNT_WIDTH(CNT_WIDTH)) col_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(colClr),
        .advIn(colAdv),
        .endValIn(maxColCntR),
        .cntOut(colCntR),
        .doneOut(colDoneR));
      
    // Base Address Counter
    counter #(
        .CNT_WIDTH(CNT_WIDTH)) base_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(baseClr),
        .advIn(baseAdv),
        .endValIn(maxAddrR),
        .cntOut(baseCntR),
        .doneOut(baseDoneR));
    
    // Done signal for 2D Convolution 
    assign done = rowDoneR & colDoneR & baseDoneR;
    
    always @(posedge clkIn) begin
        if (rstIn) begin
            stateR  <= IDLE;
            validR  <= 0;
        end else begin
            case (stateR)
                IDLE : begin
                    numCellsR   <= dataRowsIn * dataColsIn;
                    maxColCntR  <= filtColsIn - 1;
                    maxRowCntR  <= filtRowsIn[ROWS_HI:ROWS_LO] - 1;
                    lastRowCntR <= filtRowsIn[ROWS_LO-1:0] - 1;
                    if (startIn) begin
                        stateR  <= INIT;
                    end
                end
                INIT : begin
                    maxBaseCntR <= numCellsR - 1;
                    validR      <= 1;
                    stateR      <= CALC;
                end
                CALC : begin
                    if (done) begin
                        validR  <= 0;
                        stateR  <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Data Process
    always @(posedge clkIn) begin
    
        // Pipeline #2
        last2R   <= rowDoneR & colDoneR;
        addr2R   <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}} * colCntR;
        offset2R <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}} + baseCntR:
        rowCnt2R <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}};
        
        // Pipeline #3
        last3R      <= last2R;
        dataAddr3R  <= addr2R + offset2R;
        filtAddr3R  <= addr2R + rowCnt2R;
        
        // Pipeline #4
        last4R      <= last3R;
        
        // Determine shift required to access correct RAM bank
        dataShift4R <= dataAddr3R[(VECTOR_SIZE_LOG2-1):0];
        filtShift4R <= filtAddr3R[(VECTOR_SIZE_LOG2-1):0];
        
        // Determine addresses for each RAM bank
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            dataAddrVar  = dataAddr3R + i;
            filtAddrVar  = filtAddr3R + i;
            
            dataAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= dataAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];            
            filtAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= filtAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];
        end
        
        // Pipeline #5
        dataShift5R <= dataShift4R;
        filtShift5R <= filtShift4R;
        
        // Circular shift
        dataAddr5R  <= (dataAddr4R << (dataShift4R*RAM_ADDR_WIDTH)) | (dataAddr4R >> ((VECTOR_SIZE - dataShift4R)*RAM_ADDR_WIDTH));
        filtAddr5R  <= (filtAddr4R << (filtShift4R*RAM_ADDR_WIDTH)) | (filtAddr4R >> ((VECTOR_SIZE - filtShift4R)*RAM_ADDR_WIDTH));
    end
    
    reg [VECTOR_SIZE-1:0] rdEn2R;
    reg [VECTOR_SIZE-1:0] rdEn3R;
    reg [VECTOR_SIZE-1:0] rdEn4R;
    reg [VECTOR_SIZE-1:0] dataRdEn5R;
    reg [VECTOR_SIZE-1:0] filtRdEn5R;
    
    // Read Enable Process
    always @(posedge clkIn) begin
        if (rstIn) begin
            rdEn2R      <= 0;
            rdEn3R      <= 0;
            rdEn4R      <= 0;
            dataRdEn5R  <= 0;
            filtRdEn5R  <= 0;
        end else begin
        
            // Pipeline #2
            // Determine which bits of read enable are high
            for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
                if (rowDoneR) begin
                    if (i < lastRowCntR) begin
                        rdEn2R[i] <= validR;
                    end else begin
                        rdEn2R[i] <= 0;
                    end
                end else begin
                    rdEn2R[i] <= validR;
                end
            end
            
            // Pipeline #3
            rdEn3R      <= rdEn2R;
            
            // Pipeline #4
            rdEn4R      <= rdEn3R;
            
            // Pipeline #5
            // Circular shift
            dataRdEn5R  <= (rdEn4R << dataShift4R) | (rdEn4R >> (VECTOR_SIZE - dataShift4R));
            filtRdEn5R  <= (rdEn4R << filtShift4R) | (rdEn4R >> (VECTOR_SIZE - filtShift4R));
        end
    end
    
    localparam WREN_ZERO  = {VECTOR_SIZE{1'b0}};
    localparam DATA_ZERO  = { DATA_WIDTH{1'b0}};
    localparam RD_LATENCY = 1;
                
    // Generate Data RAM for each vector element
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            wire [RAM_ADDR_WIDTH-1:0] rdAddr;
            wire [DATA_WIDTH-1:0] rdData;
            
            assign rdAddr = dataAddr5R[i*RAM_ADDR_WIDTH+:RAM_ADDR_WIDTH];
            
            dp_ram #(
                .DATA_WIDTH(DATA_WIDTH),
                .RAM_DEPTH(RAM_DEPTH)) data_ram (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrAIn(busAddr[i]),
                .wrEnAIn(busWrEn[i]),
                .wrDataAIn(busWrData[i]),
                .rdEnAIn(1'b0),
                .addrBIn(rdAddr),
                .wrEnBIn(WREN_ZERO),
                .wrDataBIn(DATA_ZERO),
                .rdEnBIn(dataRdEn5R[i]),
                .rdDataBOut(rdData),
                .rdAckBOut(valid[i]));
                
            assign dataA[DATA_WIDTH*i+:DATA_WIDTH] = rdData;
            
            delay #(
                .LATENCY(RD_LATENCY),
                .DATA_WIDTH(VECTOR_SIZE_LOG2)) data_delay (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .dataIn(dataRdShift5R),
                .dataOut(dataAShift));            
        end
    endgenerate
        
    // Generate Filter RAM for each vector element
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            wire [RAM_ADDR_WIDTH-1:0] rdAddr;
            wire [DATA_WIDTH-1:0] rdData;
            
            assign rdAddr = filtAddr[i*RAM_ADDR_WIDTH+:RAM_ADDR_WIDTH];
            
            dp_ram #(
                .DATA_WIDTH(DATA_WIDTH),
                .RAM_DEPTH(RAM_DEPTH)) filt_ram (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrAIn(busAddr[i]),
                .wrEnAIn(busWrEn[i]),
                .wrDataAIn(busWrData[i]),
                .rdEnAIn(1'b0),
                .addrBIn(rdAddr),
                .wrEnBIn(WREN_ZERO),
                .wrDataBIn(DATA_ZERO),
                .rdEnBIn(dataRdEn5R[i]),
                .rdDataBOut(rdData));
                
            assign dataB[DATA_WIDTH*i+:DATA_WIDTH] = rdData;
            
            delay #(
                .LATENCY(RD_LATENCY),
                .DATA_WIDTH(VECTOR_SIZE_LOG2)) filt_delay (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .dataIn(filtRdShift5R),
                .dataOut(dataBShift)); 
        end
    endgenerate
    
    // Valid Process
    always @(posedge clkIn) begin
        if (rstIn) begin
            validR  <= 0;
        end else begin
            // Circular shift
            validR  <= (valid >> dataAShift) | (valid << (VECTOR_SIZE - dataAShift));            
        end
    end
    
    // Data Process
    always @(posedge clkIn) begin
        // Circular shift
        dataAR  <= (dataA >> (dataAShift*DATA_WIDTH)) | (dataA << ((VECTOR_SIZE - dataAShift)*DATA_WIDTH));
        dataBR  <= (dataB >> (dataBShift*DATA_WIDTH)) | (dataB << ((VECTOR_SIZE - dataBShift)*DATA_WIDTH));
    end
    
    // Multiply and Accumulate
    multiply_and_accumulate #(
        .FRAC_WIDTH(FRAC_WIDTH),
        .EXP_WIDTH(EXP_WIDTH)) mac(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataAIn(dataAR),
        .dataBIn(dataBR),
        .validIn(validR),
        .lastIn(last),
        .dataOut(data),
        .validOut(valid));
       
    // Output FIFO
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_SKID(128)) fifo_i(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .wrDataIn(macData),
        .wrValidIn(macValid),
        .wrReadyOut(fifoWrReady),
        .rdDataOut(dataOut),
        .rdValidOut(validOut),
        .rdReadyIn(readyIn);
    
endmodule