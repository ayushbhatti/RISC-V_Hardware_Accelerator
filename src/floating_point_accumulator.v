module floating_point_accumulate (
    clkIn,
    rstIn,
    startIn,
    lastIn,
    validIn,
    dataIn,
    validOut,
    dataOut);
    
    // Parameters to define floating-point type
    parameter FRAC_WIDTH      = 24;
    parameter EXP_WIDTH       =  8;
    
    localparam DATA_WIDTH     = FRAC_WIDTH + EXP_WIDTH;
    localparam ADD_LATENCY    = 13;
    localparam NUM_STAGES     = $clog2(ADD_LATENCY+1);
    
    input clkIn;
    input rstIn;
    
    input startIn;
    input lastIn;
    input validIn;
    input [DATA_WIDTH-1:0] dataIn;
    
    output validOut;
    output [DATA_WIDTH-1:0] dataOut;
    
    wire [DATA_WIDTH-1:0] stageIData [0:NUM_STAGES-1];
    wire [DATA_WIDTH-1:0] stageOData [0:NUM_STAGES-1];
    
    wire stageIValid [0:NUM_STAGES-1];
    wire stageOValid [0:NUM_STAGES-1];
    
    wire stageIStart [0:NUM_STAGES-1];
    wire stageOStart [0:NUM_STAGES-1];
    
    wire stageILast  [0:NUM_STAGES-1];
    wire stageOLast  [0:NUM_STAGES-1];
    
    genvar i;
    generate
    
        for (i = 0; i < NUM_STAGES; i = i + 1) begin

            reg [DATA_WIDTH-1:0] dataR;
            reg startR;
            reg validR;
            
            wire valid;
            
            wire [1:0] iDelay;
            wire [1:0] oDelay;
            
            /*assign stageIData [i] = dataIn; // (i == 0) ? dataIn  : stageOData [i-1];
            assign stageIValid[i] = validIn; // (i == 0) ? validIn : stageOValid[i-1];
            assign stageIStart[i] = startIn; // (i == 0) ? startIn : stageOStart[i-1];
            assign stageILast [i] = lastIn; //(i == 0) ? lastIn  : stageOLast [i-1];*/
            
            if (i == 0) begin
                assign stageIData [i] = dataIn;
                assign stageIValid[i] = validIn;
                assign stageIStart[i] = startIn;
                assign stageILast [i] = lastIn;
            end else begin
                assign stageIData [i] = stageOData [i-1];
                assign stageIValid[i] = stageOValid[i-1];
                assign stageIStart[i] = stageOStart[i-1];
                assign stageILast [i] = stageOLast [i-1];
            end
                
            always @(posedge clkIn) begin
                if (rstIn) begin
                    validR <= 0;
                end else begin
                    if (stageIValid[i]) begin
                        validR <= !validR;
                    end
                end
            end
            
            assign valid = stageIValid[i] & validR;
            
            always @(posedge clkIn) begin
                if (stageIValid[i]) begin
                    dataR   <= stageIData[i];
                    startR  <= stageIStart[i];
                end
            end
                
            floating_point_add #(.FRAC_WIDTH(FRAC_WIDTH), .EXP_WIDTH(EXP_WIDTH)) add_i (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .dataAIn(stageIData[i]),
                .dataBIn(dataR),
                .validIn(valid),
                .dataOut(stageOData[i]),
                .validOut(stageOValid[i]));
                
            assign iDelay = {startR, stageILast[i]};
            
            delay #(.DATA_WIDTH(2), .LATENCY(ADD_LATENCY)) delay_i (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .dataIn(iDelay),
                .dataOut(oDelay));
                    
            assign stageOStart[i] = oDelay[1];
            assign stageOLast [i] = oDelay[0];
        end
    endgenerate
    
    reg [DATA_WIDTH-1:0] accumDataAR;
    reg [DATA_WIDTH-1:0] accumDataBR;
    reg accumValidR;
    reg accumLastR;
    
    wire [DATA_WIDTH-1:0] accumData;
    wire accumValid;
    wire accumLast;
    
    always @(posedge(clkIn)) begin
        accumDataAR <= stageOData [NUM_STAGES-1];
        accumValidR <= stageOValid[NUM_STAGES-1];
        accumLastR  <= stageOLast [NUM_STAGES-1];
        if (stageOStart[NUM_STAGES-1]) begin
            accumDataBR <= 0;
        end else if (accumValid) begin
            accumDataBR <= accumData;
        end
    end
    
    floating_point_add #(.FRAC_WIDTH(FRAC_WIDTH), .EXP_WIDTH(EXP_WIDTH)) accum_i (
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataAIn(accumDataAR),
        .dataBIn(accumDataBR),
        .validIn(accumValidR),
        .dataOut(accumData),
        .validOut(accumValid));
    
    delay #(.DATA_WIDTH(1), .LATENCY(ADD_LATENCY)) delay_i (
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataIn(accumLastR),
        .dataOut(accumLast));
        
    assign validOut = accumValid & accumLast;
    assign dataOut  = accumData;
                    
endmodule