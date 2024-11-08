package cnnHwAccelerator

import chisel3._
import chisel3.util._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.config.Parameters

class CNNFSM(implicit p: Parameters) extends Module {
  val io = IO(new Bundle {
    val start = Input(Bool())            // Start signal
    val dmaBusy = Input(Bool())          // DMA busy signal
    val computeDone = Input(Bool())      // Computation done signal
    val fifoEmpty = Input(Bool())        // FIFO empty signal
    val error = Output(Bool())           // Error flag
    val dmaStart = Output(Bool())        // Start DMA
    val computeStart = Output(Bool())    // Start computation
    val writeBackStart = Output(Bool())  // Start write-back
  })

  // FSM states
  val sIdle :: sLoad :: sCompute :: sWriteBack :: sError :: Nil = Enum(5)
  val state = RegInit(sIdle)

  // Default outputs
  io.dmaStart := false.B
  io.computeStart := false.B
  io.writeBackStart := false.B
  io.error := false.B

  // FSM logic
  switch(state) {
    is(sIdle) {
      when(io.start) {
        state := sLoad
      }
    }

    is(sLoad) {
      io.dmaStart := true.B
      when(!io.dmaBusy) {
        state := sCompute
      } .elsewhen(io.dmaBusy && io.fifoEmpty) {
        state := sError
      }
    }

    is(sCompute) {
      io.computeStart := true.B
      when(io.computeDone) {
        state := sWriteBack
      } .elsewhen(io.fifoEmpty) {
        state := sError
      }
    }

    is(sWriteBack) {
      io.writeBackStart := true.B
      when(!io.dmaBusy) {
        state := sIdle
      } .elsewhen(io.fifoEmpty) {
        state := sError
      }
    }

    is(sError) {
      io.error := true.B
      state := sIdle
    }
  }

  // Debugging
  printf(p"FSM State: $state, DMA: ${io.dmaBusy}, Compute Done: ${io.computeDone}, FIFO Empty: ${io.fifoEmpty}\n")
}
