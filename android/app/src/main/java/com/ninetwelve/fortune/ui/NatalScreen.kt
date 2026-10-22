package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.model.AppState

/** 本命盤：十二列，首列為命宮，宮位逆序，末列即本命三柱。 */
@Composable
fun NatalScreen(state: AppState) {
    val destiny = state.destiny ?: return
    val t = state.t
    var sheetRow by remember { mutableStateOf<PalaceRow?>(null) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Card(
            title = t("本命三柱", "The three pillars", "Los tres pilares", "I tre pilastri"),
            subtitle = t(
                "${t.date(destiny.birth)} → 年、月、日各自化約",
                "${t.date(destiny.birth)} → year, month and day each reduced",
                "${t.date(destiny.birth)} → año, mes y día reducidos por separado",
                "${t.date(destiny.birth)} → anno, mese e giorno ridotti separatamente",
            ),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                PillarBox(
                    t("年", "Year", "Año", "Anno"), "${destiny.birth.year}",
                    destiny.triple.year, Modifier.weight(1f),
                )
                PillarBox(
                    t("月", "Month", "Mes", "Mese"), "${destiny.birth.month}",
                    destiny.triple.month, Modifier.weight(1f),
                )
                PillarBox(
                    t("日", "Day", "Día", "Giorno"), "${destiny.birth.day}",
                    destiny.triple.day, Modifier.weight(1f),
                )
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            val sum = destiny.triple.year + destiny.triple.month + destiny.triple.day
            LabeledLine(
                t(
                    "三柱相加（九進制）", "Sum of the three (base 9)",
                    "Suma de los tres (base 9)", "Somma dei tre (base 9)",
                ),
                "${destiny.triple.year} + ${destiny.triple.month} + ${destiny.triple.day}" +
                    " = $sum → ${t.lifeNumber} ${destiny.lifeNumber}",
            )
            LabeledLine(t.lifePalace, t.palaceNamed(destiny.lifeNumber))
        }

        // 靈數幾就是第幾型人格
        EnneagramCard(destiny.lifeNumber, state.lang)

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                t("十二宮盤", "The twelve palaces", "Los doce palacios", "I dodici palazzi"),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
            ChartTable(
                rows = destiny.natalChart,
                lang = state.lang,
                highlightIndex = 0,
                onSelect = { sheetRow = it },
            )
            Text(
                t(
                    "點任一列可看詳細。", "Tap any row for detail.",
                    "Toca cualquier fila para ver el detalle.",
                    "Tocca una riga per il dettaglio.",
                ),
                fontSize = 11.sp,
                color = secondaryText,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
    }

    sheetRow?.let { RowDetailSheet(it, state.lang) { sheetRow = null } }
}

@Composable
private fun PillarBox(label: String, raw: String, value: Int, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text(label, fontSize = 10.sp, color = secondaryText, maxLines = 1)
        Text(raw, fontSize = 10.sp, color = secondaryText.copy(alpha = 0.7f), maxLines = 1)
        Text("$value", fontSize = 22.sp, fontWeight = FontWeight.Bold)
    }
}
