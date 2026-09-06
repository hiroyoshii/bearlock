package com.hiyozoo.bearlock.lab

enum class Method { USAGE, ACCESSIBILITY }

/** Immutable single-window experiment. Time intervals match iOS: [start, end). */
data class LockWindow(val method: Method, val target: String, val start: Long, val end: Long) {
    init { require(target.isNotBlank()); require(end > start); require(end - start <= 300_000) }
    fun active(now: Long) = now >= start && now < end
    fun pending(now: Long) = now < end
    fun nextBoundary(now: Long): Long? = when {
        now < start -> start
        now < end -> end
        else -> null
    }
    companion object {
        fun create(method: Method, target: String, now: Long, delaySeconds: Int, durationSeconds: Int, existing: LockWindow?): LockWindow {
            require(existing?.pending(now) != true) { "既存の比較が終了するまで変更できません。" }
            require(delaySeconds in 0..300) { "開始までの秒数は0〜300です。" }
            require(durationSeconds in 5..300) { "ロック時間は5〜300秒です。" }
            return LockWindow(method, target, now + delaySeconds * 1000L, now + (delaySeconds + durationSeconds) * 1000L)
        }
    }
}
