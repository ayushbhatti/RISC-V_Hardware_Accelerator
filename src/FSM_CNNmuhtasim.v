`timescale 1ns/1ps

module CNN_FSM (
    input clk,               // Clock signal
    input rst,               // Reset signal
    input start,             // Start signal
    input mac_done,          // MAC computation complete
    input mem_ready,         // Memory ready for next operation
    input fifo_empty,        // FIFO empty signal
    output reg mac_start,    // Start MAC computation
    output reg mem_read,     // Memory read signal
    output reg mem_write,    // Memory write signal
    output reg done          // Overall computation done
);

    // FSM States
    typedef enum reg [2:0] {
        IDLE        = 3'b000,
        LOAD        = 3'b001,
        COMPUTE     = 3'b010,
        WRITEBACK   = 3'b011,
        FINISH      = 3'b100
    } state_t;
    
    state_t current_state, next_state;

    // Sequential block for state transitions
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Combinational block for next state logic
    always @(*) begin
        // Default outputs
        mac_start = 0;
        mem_read = 0;
        mem_write = 0;
        done = 0;
        
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                mem_read = 1;
                if (mem_ready)
                    next_state = COMPUTE;
                else
                    next_state = LOAD;
            end
            
            COMPUTE: begin
                mac_start = 1;
                if (mac_done)
                    next_state = WRITEBACK;
                else
                    next_state = COMPUTE;
            end
            
            WRITEBACK: begin
                mem_write = 1;
                if (fifo_empty)
                    next_state = FINISH;
                else
                    next_state = WRITEBACK;
            end
            
            FINISH: begin
                done = 1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
