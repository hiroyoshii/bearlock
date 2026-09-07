package com.hiyozoo.bearlock

import android.graphics.*
import android.graphics.drawable.Drawable

/** Small native vector strokes, using the same icon meanings as the SwiftUI controls. */
class LineIcon(private val name: String, private val color: Int = Palette.navy): Drawable() {
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply { style=Paint.Style.STROKE; strokeWidth=1.7f; strokeCap=Paint.Cap.ROUND; strokeJoin=Paint.Join.ROUND; this.color=this@LineIcon.color }
    override fun draw(canvas: Canvas) {
        canvas.save(); canvas.translate(bounds.left.toFloat(),bounds.top.toFloat()); canvas.scale(bounds.width()/24f,bounds.height()/24f)
        fun line(vararg values: Float) { val p=Path(); p.moveTo(values[0],values[1]); for(i in 2 until values.size step 2) p.lineTo(values[i],values[i+1]); canvas.drawPath(p,paint) }
        when(name) {
            "trash" -> { line(4f,6f,20f,6f); line(8f,6f,8f,3f,16f,3f,16f,6f); line(6f,6f,7f,21f,17f,21f,18f,6f); line(10f,9f,10f,18f); line(14f,9f,14f,18f) }
            "edit" -> { line(4f,20f,5f,15f,17f,3f,21f,7f,9f,19f,4f,20f); line(14f,6f,18f,10f) }
            "down" -> line(5f,9f,12f,16f,19f,9f)
            "up" -> line(5f,15f,12f,8f,19f,15f)
            "gear" -> {
                val p=Path()
                for(i in 0 until 32) {
                    val r=if(i%4 in 1..2) 10f else 8f
                    val angle=Math.toRadians(i*11.25)
                    val x=12f+r*kotlin.math.cos(angle).toFloat(); val y=12f+r*kotlin.math.sin(angle).toFloat()
                    if(i==0) p.moveTo(x,y) else p.lineTo(x,y)
                }
                p.close(); canvas.drawPath(p,paint); canvas.drawCircle(12f,12f,3f,paint)
            }
            "calendar" -> { canvas.drawRoundRect(3f,5f,21f,21f,2f,2f,paint); line(3f,10f,21f,10f); line(8f,3f,8f,7f); line(16f,3f,16f,7f); for(y in listOf(14f,18f)) for(x in listOf(7f,12f,17f)) canvas.drawPoint(x,y,paint) }
            "repeat" -> { line(3f,10f,3f,6f,20f,6f,16f,2f); line(21f,14f,21f,18f,4f,18f,8f,22f) }
            "bolt" -> line(14f,2f,5f,13f,12f,13f,10f,22f,20f,9f,13f,9f,14f,2f)
            "timer" -> { canvas.drawArc(4f,4f,20f,20f,-75f,300f,false,paint); line(12f,7f,12f,12f,16f,14f); line(3f,4f,3f,9f,8f,9f) }
            "lock" -> { canvas.drawRoundRect(5f,10f,19f,22f,2f,2f,paint); canvas.drawArc(7f,1f,17f,17f,180f,180f,false,paint) }
            else -> for(x in listOf(5f,12f,19f)) canvas.drawCircle(x,12f,1f,paint)
        }
        canvas.restore()
    }
    override fun setAlpha(alpha: Int) { paint.alpha=alpha }
    override fun setColorFilter(filter: ColorFilter?) { paint.colorFilter=filter }
    @Deprecated("Required Drawable override") override fun getOpacity()=PixelFormat.TRANSLUCENT
}
