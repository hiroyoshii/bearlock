package com.hiyozoo.bearlock

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class CodecTest {
    private val rule=Rule(id="a",title="Focus",targets=Targets(apps=setOf("app.a"),domains=setOf("example.com")),
        schedule=LockSchedule.Single(1_000,7_201_000))
    private val recent=Recent(rule.targets,1_000,true,1_000)
    @Test fun immediateModeRoundTripsAndOldKnownTitlesMigrateWithoutChangingTimes() {
        val immediate=rule.copy(title="Now",schedule=rule.single!!.copy(immediate=true))
        assertEquals(immediate,Codec.decode(Codec.encode(State(listOf(immediate)))).rules.single())
        for(title in listOf("Now","今すぐ","Custom")) {
            val old=JSONObject(Codec.encode(State(listOf(rule.copy(title=title)))))
            old.getJSONArray("rules").getJSONObject(0).getJSONObject("schedule").remove("immediate")
            val restored=Codec.decode(old.toString()).rules.single()
            assertEquals(title!="Custom",restored.single!!.immediate)
            assertEquals(rule.single!!.start,restored.single!!.start)
            assertEquals(rule.single!!.end,restored.single!!.end)
        }
    }

    @Test fun schemaThreePreservesRulesAndHistoryWithoutWake() {
        val old=JSONObject(Codec.encode(State(listOf(rule),listOf(recent))))
            .put("schema",3).apply { remove("wakes") }.toString()
        assertEquals(State(listOf(rule),listOf(recent)),Codec.decode(old))
    }
    @Test fun wakePersistsAcrossReloadAndExpiry() {
        val state=Planner.scheduleWake(State(listOf(rule),listOf(recent)),rule.id,rule.single!!.start,1_000)
        val restored=Codec.decode(Codec.encode(state))
        assertEquals(state,restored)
        assertEquals(1_801_000,restored.activeLocks(1_001).single().end)
        assertTrue(restored.activeLocks(1_801_000).isEmpty())
        val cancelled=Planner.cancelWake(restored,rule.id,rule.single!!.start,1_001)
        assertEquals(cancelled,Codec.decode(Codec.encode(cancelled)))
    }
    @Test fun invalidSchemaAndMissingWakeDataAreRejected() {
        val json=JSONObject(Codec.encode(State(listOf(rule))))
        assertThrows(IllegalArgumentException::class.java) { Codec.decode(json.put("schema",99).toString()) }
        json.put("schema",4).remove("wakes")
        assertThrows(org.json.JSONException::class.java) { Codec.decode(json.toString()) }
    }
    @Test fun selectionRoundTripsAndOldSchemasRemainUnmigratedUntilLegacySelectionIsRead() {
        for(schema in 3..4) {
            val old=JSONObject(Codec.encode(State(listOf(rule),listOf(recent)))).put("schema",schema).apply { remove("selection") }
            assertNull(Codec.decode(old.toString()).selection)
        }
        for(selection in listOf(Targets(),rule.targets.copy(categories=setOf(2)))) {
            val state=State(listOf(rule),listOf(recent),selection=selection)
            assertEquals(state,Codec.decode(Codec.encode(state)))
            val booked=Planner.scheduleWake(state,rule.id,rule.single!!.start,1_000)
            assertEquals(selection,Codec.decode(Codec.encode(booked)).selection)
            assertEquals(selection,Planner.cancelWake(booked,rule.id,rule.single!!.start,1_001).selection)
        }
    }
    @Test fun malformedSelectionIsNotSilentlyEmptied() {
        val json=JSONObject(Codec.encode(State())).put("selection",JSONObject().put("apps","invalid"))
        assertThrows(org.json.JSONException::class.java) { Codec.decode(json.toString()) }
    }
}
