package com.hiyozoo.bearlock

import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

/** Public Play licensing key; never accepts unsigned or tampered purchase data. */
object PurchaseVerifier {
    fun verify(key: String, data: String, signature: String): Boolean = runCatching {
        if(key.isBlank() || data.isBlank() || signature.isBlank()) return false
        val publicKey=KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.getDecoder().decode(key)))
        Signature.getInstance("SHA1withRSA").run {
            initVerify(publicKey); update(data.toByteArray(Charsets.UTF_8)); verify(Base64.getDecoder().decode(signature))
        }
    }.getOrDefault(false)
}
