package com.hiyozoo.bearlock.lab

import org.junit.Assert.*
import org.junit.Test

class LockWindowTest {
    private val now = 1_000_000L
    @Test fun boundariesAndRecoveryMatchIosIntervals() {
        val w = LockWindow.create(Method.USAGE, "probe", now, 30, 60, null)
        assertFalse(w.active(now + 29_999))
        assertTrue(w.active(now + 30_000))
        assertTrue(w.active(now + 89_999))
        assertFalse(w.active(now + 90_000))
        assertEquals(now + 30_000, w.nextBoundary(now))
        assertEquals(now + 90_000, w.nextBoundary(now + 45_000))
        assertNull(w.nextBoundary(now + 90_000))
    }
    @Test fun changingMethodOrTargetCannotReplacePendingOrActiveWindow() {
        val w = LockWindow.create(Method.USAGE, "probe", now, 30, 60, null)
        for (time in listOf(now, now + 40_000)) {
            assertThrows(IllegalArgumentException::class.java) {
                LockWindow.create(Method.ACCESSIBILITY, "different", time, 0, 5, w)
            }
        }
        assertNotNull(LockWindow.create(Method.ACCESSIBILITY, "different", w.end, 0, 5, w))
    }
    @Test fun invalidExperimentsAreRejected() {
        for ((delay, duration) in listOf(-1 to 5, 301 to 5, 0 to 0, 0 to 301)) {
            assertThrows(IllegalArgumentException::class.java) { LockWindow.create(Method.USAGE, "probe", now, delay, duration, null) }
        }
    }
}
