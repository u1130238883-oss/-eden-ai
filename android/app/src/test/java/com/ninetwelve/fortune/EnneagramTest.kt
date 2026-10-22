package com.ninetwelve.fortune

import com.ninetwelve.fortune.engine.Enneagram
import com.ninetwelve.fortune.engine.Lang
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 九型人格的內容檢查：靈數幾就是幾型、四種語言都齊、九個顏色不重複。
 */
class EnneagramTest {
    @Test fun typeFollowsLifeNumber() {
        for (n in 1..9) assertEquals(n, Enneagram.typeForLifeNumber(n))
        assertEquals(1, Enneagram.typeForLifeNumber(10))
    }

    @Test fun fiveIsTheInvestigator() {
        assertEquals("格物致知者", Enneagram.name(5, Lang.ZH))
        assertEquals("第五型", Enneagram.label(5, Lang.ZH))
        assertEquals("Type 5", Enneagram.label(5, Lang.EN))
        assertEquals("The Investigator", Enneagram.name(5, Lang.EN))
        assertEquals("El Investigador", Enneagram.name(5, Lang.ES))
        assertEquals("L'Investigatore", Enneagram.name(5, Lang.IT))
    }

    @Test fun everyTypeIsComplete() {
        for (t in 1..9) {
            for (l in Lang.entries) {
                assertTrue(Enneagram.name(t, l).isNotEmpty())
                assertTrue(Enneagram.tagline(t, l).isNotEmpty())
                assertTrue(Enneagram.summary(t, l).length > 40)
                for (i in 0 until Enneagram.SECTION_COUNT) {
                    assertTrue(Enneagram.sectionTitle(i, l).isNotEmpty())
                    val lines = Enneagram.section(t, i, l)
                    assertTrue("type $t sec $i $l", lines.isNotEmpty())
                    lines.forEach { assertTrue(it.isNotBlank()) }
                }
            }
        }
    }

    @Test fun everyTypeHasItsOwnColour() {
        val seen = (1..9).map { Enneagram.colorHex(it) }
        assertEquals(9, seen.toSet().size)
        seen.forEach { assertTrue(it in 0..0xFFFFFF) }
    }

    @Test fun allLanguagesHaveTheSameNumberOfLines() {
        for (t in 1..9) for (i in 0 until Enneagram.SECTION_COUNT) {
            val n = Lang.entries.map { Enneagram.section(t, i, it).size }.toSet()
            assertEquals("type $t sec $i", 1, n.size)
        }
    }
}
