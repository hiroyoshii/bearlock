package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64

class PurchaseVerifierTest {
    @Test fun signedDataMustMatchTheConfiguredKeyAndOriginalPayload() {
        val pair=KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val key=Base64.getEncoder().encodeToString(pair.public.encoded)
        val data="{\"productId\":\"com.hiyozoo.bearlock.support.coffee\"}"
        val signed=Signature.getInstance("SHA1withRSA").run { initSign(pair.private); update(data.toByteArray()); sign() }
        val signature=Base64.getEncoder().encodeToString(signed)
        assertTrue(PurchaseVerifier.verify(key,data,signature))
        assertFalse(PurchaseVerifier.verify(key,data.replace("coffee","dinner"),signature))
        val other=KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        assertFalse(PurchaseVerifier.verify(Base64.getEncoder().encodeToString(other.public.encoded),data,signature))
    }
    @Test fun missingAndMalformedSignaturesAreRejected() {
        assertFalse(PurchaseVerifier.verify("","{}",""))
        assertFalse(PurchaseVerifier.verify("not-a-key","{}","not-a-signature"))
    }
}
