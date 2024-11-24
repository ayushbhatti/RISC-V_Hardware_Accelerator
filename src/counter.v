module counter (
    clkIn,
    rstIn,
    clrIn,
    advIn,
    endValIn,
    cntOut,
    doneOut);
    
    parameter CNT_WIDTH = 8;
    
    input clkIn;
    input rstIn;
    
    input clrIn;
    input advIn;
    input [CNT_WIDTH-1:0] endValIn;
    
    output doneOut;
    output [CNT_WIDTH-1:0] cntOut;
    
    reg doneR;
    reg [CNT_WIDTH-1:0] nextCntVar;
    reg [CNT_WIDTH-1:0] cntR;
        
    always @(posedge clkIn) begin
        if (rstIn) begin
            doneR   <= 0;
            cntR    <= 0;
        end else begin
            if (clrIn) begin
                cntR        <= 0;
                doneR       <= 0;
                if (endValIn == 0) begin
                    doneR   <= 1;
                end
            end else if (advIn && (cntR != endValIn)) begin
                nextCntVar   =  cntR + 1;
                if (nextCntVar == endValIn) begin
                    doneR   <= 1;
                end
                cntR        <= nextCntVar;
            end            
        end
    end
    
    assign doneOut = doneR;
    assign cntOut  = cntR;
    
endmodule