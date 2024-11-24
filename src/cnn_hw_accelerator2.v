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
    assign baseClr = cntClrR & fifoWrReady;
    
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
                    stateR      <= CALC;
                end
                CALC : begin
                    if (done) begin
                        stateR  <= IDLE;
                    end
                end
            endcase
        end
    end
    
    always @(posedge clkIn) begin
        if (rstIn) begin
            rdEn2R  <= 0;
        end else begin
            for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
                if (rowDoneR) begin
                    if (i < lastRowCntR) begin
                        rdEn2R[i] <= 1;
                    end else begin
                        rdEn2R[i] <= 0;
                    end
                end else begin
                    rdEn2R[i] <= 1;
                end
            end
        end
    end
    
    delay #(
        .LATENCY(2),
        .DATA_WIDTH(VECTOR_SIZE)) rden_delay (
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataIn(rdEn2R),
        .dataOut(rdEn4R));
    
    always @(posedge clkIn) begin
    
        // Pipeline #2
        addr2R   <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}} * colCntR;
        offset2R <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}} + baseCntR:
        rowCnt2R <= {rowCntR, VECTOR_SIZE_LOG2{1'b0}};
        
        // Pipeline #3
        dataAddr3R  <= addr2R + offset2R;
        filtAddr3R  <= addr2R + rowCnt2R;
        
        // Pipeline #4
        dataShift4R = dataAddr3R[(VECTOR_SIZE_LOG2-1):0];
        filtShift4R = filtAddr3R[(VECTOR_SIZE_LOG2-1):0];
        
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            dataAddrVar  = dataAddr3R + i;
            filtAddrVar  = filtAddr3R + i;
            
            dataAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= dataAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];            
            filtAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= filtAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];
        end
        
        // Pipeline #5
        dataAddr5R <= (dataAddr4R << (dataShift4R*RAM_ADDR_WIDTH)) | (dataAddr4R >> ((VECTOR_SIZE - dataShift4R)*RAM_ADDR_WIDTH));
        filtAddr5R <= (filtAddr4R << (filtShift4R*RAM_ADDR_WIDTH)) | (filtAddr4R >> ((VECTOR_SIZE - filtShift4R)*RAM_ADDR_WIDTH));
    end
    
    always @(posedge clkIn) begin
        if (rstIn) begin
            dataRdEn5R <= 0;
            filtRdEn5R <= 0;
        end else begin
            dataRdEn5R <= (rdEn4R << dataShift) | (rdEn4R >> (VECTOR_SIZE - dataShift));
            filtRdEn5R <= (rdEn4R << filtShift) | (rdEn4R >> (VECTOR_SIZE - filtShift));
        end
    end
    
    
    filtAddrR <= 
    
    
    cell2R    <= 
    
    
    
    rowDoneR & colDoneR & baseDoneR;
    
    always @(posedge clkIn) begin
        if (startR) begin
            rowIdxR             <= 0;
            if (maxRowIdxR == 0) begin
                rowDoneR        <= 1;
            end else begin
                rowDoneR        <= 0;
            end
        else
            nextRowIdxVar        = rowIdxR + 1;
            if (nextRowIdxR == maxRowIdxR) begin
                rowDoneR        <= 1;
            else
                rowDoneR        <= 0;
            end
            rowIdxR             <= nextRowIdxVar;
        end
    end
    
    always @(posedge clkIn) begin
        if (startR) begin
            colIdxR             <= 0;
            if (maxColIdxR == 0) begin
                colDoneR        <= 1;
            end else begin
                colDoneR        <= 0;
            end
        end else begin
            if (rowDoneR) begin
                nextColIdxVar    = colIdxR + 1;
            end else begin
                nextColIdxVar    = colIdxR;
            end
            if (nextColIdxVar == maxColIdxR) begin
                colDoneR        <= 1;
            else
                colDoneR        <= 0;
            end
            colIdxR             <= nextColIdxVar;
        end
    end
           
    always @(posedge clkIn) begin
    
    end
    
            if (rowSizeIn < VECTOR_SIZE) begin
                maxRowIdxR      <= 0;
                rowDoneR        <= 1;
            else
                maxRowIdxR      <= rowSizeIn - VECTOR_SIZE;
                rowDoneR        <= 0;
            end
        end else begin
            rowIdxR             <= rowIdxR + VECTOR_SIZE;
            rowDoneR            <= 0;
            if (rowIdxR >= maxRowIdxR) begin
                rowIdxR         <= 0;
                rowDoneR        <= 1;
            end
        end
    end
    
    always @(posedge clkIn) begin
        if (startR) begin
            colIdx2R            <= 0;
            maxColIdx2R         <= colSizeR - 1;
            if ((colSizeR == 1) && rowDoneR) begin
                colDone2R       <= 1;
            else
                colDone2R       <= 0;
            end
        end else begin
            colDone2R           <= 0;
            if (rowDone2R) begin
                colIdx2R        <= colIdx2R + 1;
                if (colIdx2R >= maxColIdx2R) begin
                    colIdx2R    <= 0;
                    colDone2R   <= 1;
                end
            end
        end
    end
    
    
    colIdx2R * rowIdx2R
    colIdxR     <= colIdxR + 1;
    if (colIdxR >= maxColIdxR) begin
        doneR   <= 1;
    end
    
    addrR       <= colIdxR * rowSizeR + rowIdxR + baseAddrR;
    
    shift2R     <= addrR[SHIFT_HI:SHIFT_LO];
    for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        addr2R[i] <= addrR + i;
    end
    addr3R[i]     <= addr2R[i][ADDR_HI:ADDR_LO];
    
    addrR[i]    <= addrR
    always @(posedge clkIn) begin
        if (rstIn) begin
        end else begin
            wrEnR   <= 0;
            wrDataR <= 0;
            case (stateR)
                // Pass-through for RISCV inputs
                IDLE : begin
                    addrR[i]    <= addrIn[ADDR_HI:ADDR_LO];
                    wrEnR[i]    <= wr
                    wrDataR[i]  <= wrDataIn[31:0];
                    wrDataR[i+1]<= wrDataIn[63:32];
                    filtRowsR   <= filtRowsIn;
                    filtColsR   <= filtColsIn;
                    dataRowsR   <= dataRowsIn;
                    dataColsR   <= dataColsIn;
                    if (startIn) begin
                        stateR  <= RUN;
                        // Error messages on user input
                    end
                end
                RUN : begin
                    if (colsRemainingR < vectorSize) begin
                        lastR   <= 1;
                    end
                    for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
                        idxR    <= idxR + VECTOR_SIZE;
                        
                        colIdxR <= idxR % filtColsR;
                        rowIdx  <= idxR / filtColsR;
                        validR[i]   <= (colsRemainingR > i);
                        if (filtColsR)
                            
                        else
                            addrR[i] <= addrR[i] + VECTOR_SIZE;
                        end
                    end
                    addrR       <= addrR + VECTOR_SIZE;
                    rdEnR       <=
                end
            endcase;                
        end
    end
    
    // Multiply and Accumulate
    multiply_and_accumulate #(.FRAC_WIDTH(FRAC_WIDTH), .EXP_WIDTH(EXP_WIDTH)) mac(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataAIn(dataA),
        .dataBIn(dataB),
        .validIn(valid),
        .lastIn(last),
        .dataOut(data),
        .validOut(valid));
       
    // Output FIFO
    fifo #(.DATA_WIDTH(DATA_WIDTH), .FIFO_SKID(128)) fifo_i(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .wrDataIn(macData),
        .wrValidIn(macValid),
        .wrReadyOut(fifoWrReady),
        .rdDataOut(dataOut),
        .rdValidOut(validOut),
        .rdReadyIn(readyIn);
    
endmodule