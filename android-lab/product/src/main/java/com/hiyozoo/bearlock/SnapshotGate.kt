package com.hiyozoo.bearlock

/** Main-thread state: a slow snapshot must not overwrite a newer foreground event. */
class SnapshotGate {
    private var revision = 0L
    private var inFlight: Long? = null
    private var closed = false
    fun invalidate() { revision++ }
    fun begin(): Long? {
        if (closed || inFlight != null) return null
        return revision.also { inFlight = it }
    }
    fun finish(ticket: Long): Boolean {
        check(inFlight == ticket)
        inFlight = null
        return !closed && ticket == revision
    }
    fun close() { closed = true; invalidate() }
}
