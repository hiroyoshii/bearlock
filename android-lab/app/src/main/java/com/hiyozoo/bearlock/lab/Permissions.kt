package com.hiyozoo.bearlock.lab

import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.os.Build
import android.os.Process
import android.provider.Settings

object Permissions {
    @Suppress("DEPRECATION")
    fun usage(c: Context) = c.getSystemService(AppOpsManager::class.java)
        .checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), c.packageName) == AppOpsManager.MODE_ALLOWED
    fun alarms(c: Context) = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun missing(c: Context, method: Method): List<String> = buildList {
        if (!Permissions.alarms(c)) add("正確なアラーム")
        if (method == Method.USAGE) {
            if (!usage(c)) add("使用状況へのアクセス")
            if (!Settings.canDrawOverlays(c)) add("他のアプリの上に表示")
        } else if (AccessMonitor.instance == null) add("Accessibility サービスの接続")
    }
}
