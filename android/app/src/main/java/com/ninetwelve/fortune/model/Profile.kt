package com.ninetwelve.fortune.model

import com.ninetwelve.fortune.engine.BirthDate
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.engine.YearAnchor
import org.json.JSONObject
import java.util.UUID

/** 一筆已儲存的個人出生資料。 */
data class Profile(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val birth: BirthDate,
) {
    fun displayName(lang: Lang): String {
        val trimmed = name.trim()
        return trimmed.ifEmpty { Txt(lang)("未命名", "Unnamed", "Sin nombre", "Senza nome") }
    }

    fun destiny(anchor: YearAnchor): Destiny = Destiny(birth, anchor)

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("y", birth.year)
        put("m", birth.month)
        put("d", birth.day)
    }

    companion object {
        fun fromJson(o: JSONObject): Profile = Profile(
            id = o.optString("id", UUID.randomUUID().toString()),
            name = o.optString("name", ""),
            birth = BirthDate(
                year = o.optInt("y", 2000),
                month = o.optInt("m", 1),
                day = o.optInt("d", 1),
            ),
        )
    }
}
