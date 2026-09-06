package com.hiyozoo.bearlock.probe

import android.app.Instrumentation
import android.app.UiAutomation
import android.graphics.Rect
import android.os.Bundle
import android.util.Xml
import android.view.accessibility.AccessibilityNodeInfo
import java.io.StringWriter

/** Outside input-blocking measurements only: preserves the product accessibility service. */
class QAInstrumentation: Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        try {
            val automation=getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
            val root=automation.rootInActiveWindow ?: error("No active window")
            val output=StringWriter(); val xml=Xml.newSerializer(); xml.setOutput(output)
            xml.startTag(null,"hierarchy")
            fun write(node: AccessibilityNodeInfo) {
                val r=Rect();node.getBoundsInScreen(r)
                xml.startTag(null,"node")
                for((key,value) in mapOf("text" to node.text?.toString().orEmpty(),"content-desc" to node.contentDescription?.toString().orEmpty(),
                    "bounds" to "[${r.left},${r.top}][${r.right},${r.bottom}]","class" to node.className.toString(),
                    "enabled" to node.isEnabled.toString(),"checked" to node.isChecked.toString(),"selected" to node.isSelected.toString(),"clickable" to node.isClickable.toString())) xml.attribute(null,key,value)
                for(i in 0 until node.childCount) node.getChild(i)?.let(::write)
                xml.endTag(null,"node")
            }
            write(root);xml.endTag(null,"hierarchy");xml.flush()
            finish(-1,Bundle().apply { putString("tree",output.toString()) })
        } catch(e: Exception) { finish(0,Bundle().apply { putString("error",e.toString()) }) }
    }
}
