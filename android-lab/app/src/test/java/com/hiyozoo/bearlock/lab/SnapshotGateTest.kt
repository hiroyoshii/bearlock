package com.hiyozoo.bearlock.lab

import org.junit.Assert.*
import org.junit.Test

class SnapshotGateTest {
    @Test fun targetSnapshotCannotUndoNewerHomeEvent() {
        val gate = SnapshotGate()
        val targetRead = gate.begin()!!
        gate.invalidate() // User has moved Home while another process was answering.
        assertFalse(gate.finish(targetRead))
        val homeRead = gate.begin()!!
        assertTrue(gate.finish(homeRead))
    }
    @Test fun reconnectCannotReceiveOldServiceResult() {
        val oldService = SnapshotGate()
        val pending = oldService.begin()!!
        oldService.close()
        assertFalse(oldService.finish(pending))
        assertNull(oldService.begin())
        val newService = SnapshotGate()
        assertTrue(newService.finish(newService.begin()!!))
    }
    @Test fun slowWindowProcessDoesNotAccumulateConcurrentReads() {
        val gate = SnapshotGate()
        val read = gate.begin()!!
        repeat(10) { gate.invalidate(); assertNull(gate.begin()) }
        assertFalse(gate.finish(read))
        assertTrue(gate.finish(gate.begin()!!))
    }
}
