package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.LuckPeriod
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.model.AppState
import java.util.Calendar

private enum class Segment { LUCK, YEAR, MONTH }

private fun Segment.title(t: Txt): String = when (this) {
    Segment.LUCK -> t("大運", "Luck Pillars", "Pilares de Suerte", "Pilastri della Sorte")
    Segment.YEAR -> t("流年", "Annual", "Anual", "Annuale")
    Segment.MONTH -> t("月運", "Monthly", "Mensual", "Mensile")
}

/** 運程：大運 / 流年 / 月運。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FortuneScreen(state: AppState) {
    val destiny = state.destiny ?: return
    val t = state.t
    val thisYear = remember { Calendar.getInstance().get(Calendar.YEAR) }
    val thisMonth = remember { Calendar.getInstance().get(Calendar.MONTH) + 1 }

    var tab by remember { mutableStateOf(Segment.LUCK) }
    var year by remember { mutableIntStateOf(thisYear) }
    var sheetRow by remember { mutableStateOf<PalaceRow?>(null) }
    // 詳情頁要列出的引動（流年、大運才有）
    var sheetTriggers by remember { mutableStateOf<TriggerList?>(null) }
    // 點了哪一段大運的圓圈，就看那一段的十二個方面
    var aspectsPeriod by remember { mutableStateOf<LuckPeriod?>(null) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            Segment.entries.forEachIndexed { i, s ->
                SegmentedButton(
                    selected = s == tab,
                    onClick = { tab = s },
                    shape = SegmentedButtonDefaults.itemShape(index = i, count = Segment.entries.size),
                ) { Text(s.title(t), maxLines = 1, fontSize = 13.sp) }
            }
        }

        when (tab) {
            Segment.LUCK -> LuckSection(
                destiny, state.lang, thisYear,
                onSelect = {
                    sheetRow = it.row
                    sheetTriggers = TriggerList.luck(it, destiny)
                },
                onAspects = { aspectsPeriod = it },
            )
            Segment.YEAR -> YearSection(destiny, state.lang, year, thisYear, { year = it }) { row, y ->
                sheetRow = row
                sheetTriggers = TriggerList.year(y, destiny)
            }
            Segment.MONTH -> MonthSection(destiny, state.lang, year, thisYear, thisMonth, { year = it }) {
                sheetRow = it
                sheetTriggers = null
            }
        }
    }

    sheetRow?.let {
        RowDetailSheet(it, state.lang, triggers = sheetTriggers) {
            sheetRow = null
            sheetTriggers = null
        }
    }
    aspectsPeriod?.let {
        LuckAspectsSheet(destiny, it, state.lang) { aspectsPeriod = null }
    }
}

// ── 大運 ──

@Composable
private fun LuckSection(
    destiny: Destiny,
    lang: Lang,
    thisYear: Int,
    onSelect: (LuckPeriod) -> Unit,
    onAspects: (LuckPeriod) -> Unit,
) {
    val t = Txt(lang)
    val periods = remember(destiny) { destiny.luckPeriods(11) }

    Card(
        title = t(
            "一生大運", "A lifetime of Luck Pillars",
            "Los Pilares de Suerte de toda una vida", "I Pilastri della Sorte di tutta una vita",
        ),
        subtitle = t(
            "每段寬度即年數，外框是現在所處的一段",
            "Each block's width is its length; the outlined one is where you are now",
            "El ancho de cada bloque es su duración; el enmarcado es donde estás ahora",
            "La larghezza di ogni blocco è la sua durata; quello incorniciato è dove ti trovi adesso",
        ),
    ) {
        LuckTimeline(periods, destiny.birth.year, thisYear, lang, onSelect)
    }

    periods.forEach { p ->
        val isNow = p.contains(thisYear)
        SummaryCard(
            title = p.span,
            caption = if (isNow) t(
                "現在所處的大運 · ${p.length}年",
                "Current pillar · ${p.length} yrs",
                "Pilar actual · ${p.length} años",
                "Pilastro attuale · ${p.length} anni",
            ) else t(
                "${p.length}年", "${p.length} yrs",
                "${p.length} años", "${p.length} anni",
            ),
            row = p.row,
            lang = lang,
            onClick = { onSelect(p) },
            badge = if (isNow) t("目前", "Now", "Ahora", "Ora") else null,
            // 點左邊那個圓圈：看這段大運的十二個方面
            onPalaceClick = { onAspects(p) },
        )
    }
}

// ── 流年 ──

@Composable
private fun YearSection(
    destiny: Destiny,
    lang: Lang,
    year: Int,
    thisYear: Int,
    onYearChange: (Int) -> Unit,
    /** 點了哪一列，以及那一列是哪一年。 */
    onSelect: (PalaceRow, Int) -> Unit,
) {
    val t = Txt(lang)
    val labels = (0 until 12).map { t.year(year + it) }
    val rows = (0 until 12).map { destiny.year(year + it) }
    val highlight = if (thisYear in year until year + 12) thisYear - year else null

    YearStepper(
        year = year,
        title = t("由這一年起算十二年", "Twelve years from", "Doce años desde", "Dodici anni da"),
        lang = lang,
        thisYear = thisYear,
        birthYear = destiny.birth.year,
        onYearChange = onYearChange,
    )

    ChartTable(rows, lang, labels, highlight) { row -> onSelect(row, year + rows.indexOf(row)) }
}

// ── 月運 ──

@Composable
private fun MonthSection(
    destiny: Destiny,
    lang: Lang,
    year: Int,
    thisYear: Int,
    thisMonth: Int,
    onYearChange: (Int) -> Unit,
    onSelect: (PalaceRow) -> Unit,
) {
    val t = Txt(lang)
    val months = destiny.monthChart(year)
    val highlight = if (year == thisYear) thisMonth - 1 else null

    YearStepper(
        year = year,
        title = t("選擇年份", "Year", "Año", "Anno"),
        lang = lang,
        thisYear = thisYear,
        birthYear = destiny.birth.year,
        onYearChange = onYearChange,
    )

    ChartTable(
        rows = months.map { it.row },
        lang = lang,
        trailingLabels = months.map { t.month(it.month) },
        highlightIndex = highlight,
        onSelect = onSelect,
    )
}

@Composable
private fun YearStepper(
    year: Int,
    title: String,
    lang: Lang,
    thisYear: Int,
    birthYear: Int?,
    onYearChange: (Int) -> Unit,
) {
    val t = Txt(lang)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardColor)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodySmall, color = secondaryText)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(t.year(year), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                if (birthYear != null && year >= birthYear) {
                    val age = year - birthYear
                    Text(
                        t("${age}歲", "age $age", "$age años", "$age anni"),
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                }
                if (year != thisYear) {
                    Text(
                        t("回到今年", "Today", "Hoy", "Oggi"),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Theme.accent,
                        modifier = Modifier.clickable { onYearChange(thisYear) },
                    )
                }
            }
        }
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
        ) {
            StepButton("−") { onYearChange(year - 1) }
            StepButton("+") { onYearChange(year + 1) }
        }
    }
}

@Composable
private fun StepButton(label: String, onClick: () -> Unit) {
    Text(
        label,
        color = Theme.accent,
        fontSize = 20.sp,
        fontWeight = FontWeight.Bold,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .size(44.dp, 40.dp)
            .clickable(onClick = onClick)
            .padding(top = 6.dp),
    )
}
