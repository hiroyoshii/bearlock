package com.hiyozoo.bearlock

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.LruCache

data class AppEntry(val pkg: String, val name: String, val category: Int, val resourceKey: String)
class Catalog(private val context: Context) {
    companion object { private val names = LruCache<String, String>(1024) }
    private val fixedExcluded = setOf(context.packageName, "com.android.settings", "com.android.systemui", "com.google.android.permissioncontroller", "com.android.permissioncontroller")
    @Suppress("DEPRECATION")
    fun apps(): List<AppEntry> {
        val pm = context.packageManager
        val excludedPackages = excludedPackages()
        return pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo.applicationInfo }.distinctBy { it.packageName }
            .filterNot { it.packageName in excludedPackages }
            .map {
                // Re-query membership each time, but reuse labels until the APK or locale changes.
                val key="${it.packageName}:${it.sourceDir}:${it.icon}:${context.resources.configuration}"
                val name=names.get(key) ?: runCatching { pm.getApplicationLabel(it).toString() }
                    .getOrDefault(it.packageName).also { label -> names.put(key,label) }
                AppEntry(it.packageName,name,it.category,key)
            }
            .sortedBy { it.name.lowercase() }
    }
    fun excluded(pkg: String): Boolean = pkg in fixedExcluded || pkg in excludedPackages()
    @Suppress("DEPRECATION")
    private fun excludedPackages(): Set<String> {
        return fixedExcluded + listOf(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), Intent(Intent.ACTION_DIAL)).flatMap { intent ->
            context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).map { it.activityInfo.packageName }
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
