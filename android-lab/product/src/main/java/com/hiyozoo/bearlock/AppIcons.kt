package com.hiyozoo.bearlock

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.view.View
import android.widget.ImageView
import java.lang.ref.WeakReference
import java.util.concurrent.Executors
import java.util.concurrent.Future

/** Icon IO never runs on the UI thread or delays publication of the catalog. */
internal object AppIcons {
    private val loader=Executors.newFixedThreadPool(2)
    private val main=Handler(Looper.getMainLooper())
    private val cache=object: LruCache<String,Bitmap>(4*1024*1024) {
        override fun sizeOf(key: String,value: Bitmap)=value.byteCount
    }
    private class Request { var work: Future<*>? = null }
    fun bind(view: ImageView,app: AppEntry) {
        (view.tag as? Request)?.work?.cancel(false)
        val request=Request(); view.tag=request
        val context=view.context.applicationContext
        val size=(36*context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val key="${app.resourceKey}:$size"
        val cached=cache.get(key)
        view.setImageBitmap(cached)
        if(cached!=null) return
        // A lightweight local placeholder, no PackageManager lookup on this thread.
        view.setImageResource(android.R.drawable.sym_def_app_icon)
        val target=WeakReference(view)
        request.work=loader.submit {
            val bitmap=cache.get(key) ?: runCatching {
                val icon=context.packageManager.getApplicationIcon(app.pkg)
                Bitmap.createBitmap(size,size,Bitmap.Config.ARGB_8888).also {
                    icon.setBounds(0,0,size,size); icon.draw(Canvas(it)); cache.put(key,it)
                }
            }.getOrNull()
            main.post {
                target.get()?.let { image ->
                    if(image.tag===request && image.isAttachedToWindow && bitmap!=null) image.setImageBitmap(bitmap)
                }
            }
        }
        if(view.getTag(R.id.app_icon_listener)==null) {
            view.setTag(R.id.app_icon_listener,true)
            view.addOnAttachStateChangeListener(object: View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) {}
                override fun onViewDetachedFromWindow(v: View) {
                    (v.tag as? Request)?.work?.cancel(false)
                    v.tag=null
                }
            })
        }
    }
}
