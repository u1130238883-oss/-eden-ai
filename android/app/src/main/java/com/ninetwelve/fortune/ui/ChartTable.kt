package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.LuckPeriod
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Txt

/** 十二宮盤的表格。每列可點開看詳細判讀。 */
@Composable
fun ChartTable(
    rows: List<PalaceRow>,
    lang: Lang,
    /** 每列右側的附註（例如年份或月份）。 */
    trailingLabels: List<String> = emptyList(),
    /** 需要高亮的列索引。 */
    highlightIndex: Int? = null,
    onSelect: (PalaceRow) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardColor),
    ) {
        rows.forEachIndexed { idx, row ->
            ChartTableRow(
                row = row,
                lang = lang,
                trailing = trailingLabels.getOrNull(idx),
                highlighted = idx == highlightIndex,
                onClick = { onSelect(row) },
            )
            if (idx < rows.size - 1) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 54.dp),
                    color = MaterialTheme.colorScheme.outlineVariant,
                )
            }
        }
    }
}

@Composable
private fun ChartTableRow(
    row: PalaceRow,
    lang: Lang,
    trailing: String?,
    highlighted: Boolean,
    onClick: () -> Unit,
) {
    val t = Txt(lang)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (highlighted) Theme.accent.copy(alpha = 0.10f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        PalaceChip(row.palace, lang, highlighted)

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    t.triple(row.triple),
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                )
                if (trailing != null) {
                    Text(
                        trailing,
                        fontSize = 10.sp,
                        color = Theme.accent,
                        maxLines = 1,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(Theme.accent.copy(alpha = 0.14f))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
            Text(
                Palace.brief(row.palace, lang),
                fontSize = 11.sp,
                color = secondaryText,
                maxLines = 1,
            )
        }

        Spacer(Modifier.width(6.dp))
        VerdictBadge(row.reading, lang, compact = true)
    }
}

/**
 * 單列的完整判讀說明，以底部彈出視窗呈現。
 *
 * [displayPalace] 是這一列要以哪一宮的含義去讀：大運十二方面用「第幾個方面」，
 * 其餘畫面就是這一列本身的宮位。
 * [triggers] 是這一列所引動的宮位（流年 → 大運方面；大運 → 本命），沒有就不顯示。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RowDetailSheet(
    row: PalaceRow,
    lang: Lang,
    displayPalace: Int = row.palace,
    triggers: TriggerList? = null,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = pageColor,
    ) {
        RowDetail(row, lang, displayPalace, triggers)
    }
}

@Composable
private fun RowDetail(row: PalaceRow, lang: Lang, displayPalace: Int, triggers: TriggerList?) {
    val t = Txt(lang)
    // 點了引動裡的哪一項：(以哪一宮去讀, 那一列)
    var inner by remember { mutableStateOf<Pair<Int, PalaceRow>?>(null) }
    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            "${t.palace(displayPalace)} ${t.reading(row.reading)}",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        Card {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                PalaceChip(displayPalace, lang, highlighted = true)
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        t.palaceNamed(displayPalace),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        t.triple(row.triple),
                        style = MaterialTheme.typography.bodyMedium,
                        color = secondaryText,
                    )
                }
                VerdictBadge(row.reading, lang)
            }
        }

        Card { CauseEffectFlow(row, lang, displayPalace) }

        // 沒有引動就整張卡不顯示
        if (triggers != null && triggers.items.isNotEmpty()) {
            TriggerCard(triggers, lang) { inner = it }
        }

        Card(
            title = "${t.effectWord} — ${t.palaceNamed(row.reading.result)}",
            subtitle = t("事情呈現出來的樣子", "How it shows up", "Cómo se manifiesta", "Come si manifesta"),
        ) {
            Text(Palace.text(row.reading.result, lang), style = MaterialTheme.typography.bodyMedium)
        }

        Card(
            title = "${t.causeWord} — ${t.palaceNamed(row.reading.cause)}",
            subtitle = t("事情背後的起因", "What lies behind it", "Qué hay detrás", "Che cosa c'è dietro"),
        ) {
            Text(Palace.text(row.reading.cause, lang), style = MaterialTheme.typography.bodyMedium)
        }

        Card(
            title = t("宮位本身", "The palace itself", "El palacio en sí", "Il palazzo in sé") +
                " — " + t.palace(displayPalace),
            subtitle = t("這件事發生的場域", "The arena it plays out in", "El terreno donde ocurre", "L'ambito in cui si svolge"),
        ) {
            Text(Palace.text(displayPalace, lang), style = MaterialTheme.typography.bodyMedium)
        }

        Spacer(Modifier.width(1.dp))
    }

    inner?.let { (palace, r) ->
        RowDetailSheet(r, lang, palace) { inner = null }
    }
}

/** 詳情頁裡「引動」那一段要列出的東西。 */
data class TriggerList(
    val kind: Kind,
    /** 被引動的那一段大運的年份（只有流年引動大運方面時才有）。 */
    val span: String?,
    /** 每一項：(以哪一宮去讀, 那一列)。 */
    val items: List<Pair<Int, PalaceRow>>,
    /** 每一項底下「被影響」的大運方面，和 items 一一對應（只有大運引動本命時才有）。 */
    val affected: List<List<Pair<Int, PalaceRow>>> = emptyList(),
) {
    enum class Kind { LUCK_ASPECTS, NATAL }

    companion object {
        /** 某一年的流年所引動的大運方面。 */
        fun year(y: Int, destiny: Destiny) = TriggerList(
            Kind.LUCK_ASPECTS,
            destiny.luckPeriod(y).span,
            destiny.triggeredAspects(y).map { it.aspect to it.row },
        )

        /** 某一段大運所引動的本命宮位。 */
        fun luck(p: LuckPeriod, destiny: Destiny): TriggerList {
            val rows = destiny.triggeredNatalRows(p)
            return TriggerList(
                Kind.NATAL,
                null,
                rows.map { it.palace to it },
                rows.map { r -> destiny.affectedAspects(r, p).map { it.aspect to it.row } },
            )
        }
    }
}

/** 引動裡的一項：宮位圓圈、宮名、三柱、判定。點開看那一宮的詳情。 */
@Composable
private fun TriggerItemRow(
    item: Pair<Int, PalaceRow>,
    lang: Lang,
    onSelect: (Pair<Int, PalaceRow>) -> Unit,
) {
    val t = Txt(lang)
    val (palace, r) = item
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect(item) },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PalaceChip(palace, lang, highlighted = true)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                t.palaceNamed(palace),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                t.triple(r.triple),
                style = MaterialTheme.typography.bodySmall,
                color = secondaryText,
            )
        }
        VerdictBadge(r.reading, lang, compact = true)
    }
}

/** 引動的那幾宮。每一項可點開看那一宮的詳情。 */
@Composable
private fun TriggerCard(
    triggers: TriggerList,
    lang: Lang,
    onSelect: (Pair<Int, PalaceRow>) -> Unit,
) {
    val t = Txt(lang)
    val title = when (triggers.kind) {
        TriggerList.Kind.LUCK_ASPECTS -> t(
            "引動大運", "Luck Pillar aspects triggered",
            "Aspectos del pilar activados", "Aspetti del pilastro attivati",
        )
        TriggerList.Kind.NATAL -> t(
            "引動本命", "Natal palaces triggered",
            "Palacios natales activados", "Palazzi natali attivati",
        )
    }
    Card(title = title, subtitle = triggers.span) {
        triggers.items.forEachIndexed { idx, item ->
            TriggerItemRow(item, lang, onSelect)

            // 被影響：這一宮再影響到的大運方面
            val affected = triggers.affected.getOrNull(idx).orEmpty()
            if (affected.isNotEmpty()) {
                Column(
                    modifier = Modifier.padding(start = 50.dp, top = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        t("被影響", "Influenced", "Influenciados", "Influenzati"),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                        color = secondaryText,
                    )
                    affected.forEach { sub -> TriggerItemRow(sub, lang, onSelect) }
                }
            }
            if (idx < triggers.items.size - 1) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 50.dp),
                    color = MaterialTheme.colorScheme.outlineVariant,
                )
            }
        }
    }
}
