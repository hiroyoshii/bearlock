package com.hiyozoo.bearlock

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable

data class AppEntry(val pkg: String, val name: String, val category: Int, val icon: Drawable)
class Catalog(private val context: Context) {
    @Suppress("DEPRECATION")
    fun apps(): List<AppEntry> {
        val pm = context.packageManager
        return pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo.applicationInfo }.distinctBy { it.packageName }
            .filterNot { excluded(it.packageName) }
            .map { AppEntry(it.packageName, pm.getApplicationLabel(it).toString(), it.category, pm.getApplicationIcon(it)) }
            .sortedBy { it.name.lowercase() }
    }
    @Suppress("DEPRECATION")
    fun excluded(pkg: String): Boolean {
        if (pkg in setOf(context.packageName, "com.android.settings", "com.android.systemui", "com.google.android.permissioncontroller", "com.android.permissioncontroller")) return true
        val pm = context.packageManager
        return listOf(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), Intent(Intent.ACTION_DIAL)).any { intent ->
            pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).any { it.activityInfo.packageName == pkg }
        }
    }
    @Suppress("DEPRECATION")
    fun category(pkg: String): Int = runCatching { context.packageManager.getApplicationInfo(pkg, 0).category }.getOrDefault(-1)
    @Suppress("DEPRECATION")
    fun name(pkg: String): String = runCatching { context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString() }.getOrDefault(pkg)
    fun summary(t: Targets): String = (t.apps.map(::name) + t.domains + t.categories.map { categoryName(it) }).joinToString(" · ")
    fun categoryName(id: Int) = when(id) {
        0 -> tr(context,"ゲーム","Games"); 1 -> tr(context,"音楽","Audio"); 2 -> tr(context,"動画","Video")
        3 -> tr(context,"写真","Photos"); 4 -> tr(context,"ソーシャル","Social"); 5 -> tr(context,"ニュース","News")
        6 -> tr(context,"地図","Maps"); 7 -> tr(context,"仕事効率化","Productivity"); else -> tr(context,"その他","Other")
    }
}
