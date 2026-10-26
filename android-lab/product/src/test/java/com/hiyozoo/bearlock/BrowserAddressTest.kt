package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test

class BrowserAddressTest {
    @Test fun firefoxDisplayDescriptionUsesOnlyTheUrl() {
        assertEquals("example.com",BrowserAddress.describedHost(" example.com. Search or enter address"))
        assertEquals("sub.example.com",BrowserAddress.describedHost(" sub.example.com/path?q=1. 検索語句またはアドレスを入力"))
        assertEquals("example.org",BrowserAddress.describedHost(" https://example.org/path. Search or enter address"))
    }
    @Test fun hintsTitlesAndUncertainDescriptionsDoNotBecomeDomains() {
        for(value in listOf("Search or enter address","example.com","News example.com. Search or enter address",
            "example.com. evil.test. Search or enter address"," example.com@evil.test. Search or enter address",
            " about:blank. Search or enter address"," example.com. ")) assertNull(value,BrowserAddress.describedHost(value))
    }
}
