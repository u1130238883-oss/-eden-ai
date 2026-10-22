package com.ninetwelve.fortune.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.BirthDate
import com.ninetwelve.fortune.engine.DayFortune
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.LuckPeriod
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.model.AppState
import java.util.Calendar
import kotlin.math.max

/** 今日總覽：白天／晚上日運、當月月運、今年流年、當前大運。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(state: AppState) {
    val destiny = state.destiny ?: return
    val t = state.t
    val lang = state.lang
    val context = LocalContext.current

    val now = remember { Calendar.getInstance() }
    var date by remember {
        mutableStateOf(
            BirthDate(
                now.get(Calendar.YEAR),
                now.get(Calendar.MONTH) + 1,
                now.get(Calendar.DAY_OF_MONTH),
            )
        )
    }
    var picking by remember { mutableStateOf(false) }
    var sheetRow by remember { mutableStateOf<PalaceRow?>(null) }
    // 詳情頁要列出的引動（流年、大運才有）
    var sheetTriggers by remember { mutableStateOf<TriggerList?>(null) }

    val y = date.year
    val m = date.month
    val d = date.day
    val fortune = destiny.dayFortune(m, d)
    val yearRow = destiny.year(y)
    val monthRow = destiny.month(m, y).row
    val luck = destiny.luckPeriod(y)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Card {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text(
                        state.owner?.displayName(lang) ?: t("本命", "Natal", "Natal", "Natale"),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    val age = max(0, y - destiny.birth.year)
                    Text(
                        t.date(destiny.birth) + t(
                            "　${age}歲", "  ·  age $age", "  ·  $age años", "  ·  $age anni",
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                    Text(
                        t("本命 ", "Natal ", "Natal ", "Natale ") + t.triple(destiny.triple),
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                }
                Box(
                    modifier = Modifier
                        .size(62.dp)
                        .clip(CircleShape)
                        .background(Theme.accent),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            t.lifeNumber,
                            fontSize = 9.sp,
                            color = Color.White.copy(alpha = 0.85f),
                            maxLines = 1,
                        )
                        Text(
                            "${destiny.lifeNumber}",
                            fontSize = 26.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                        )
                    }
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(cardColor)
                .clickable { picking = true }
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                t("日期", "Date", "Fecha", "Data"),
                style = MaterialTheme.typography.bodyMedium,
                color = secondaryText,
                modifier = Modifier.weight(1f),
            )
            Text(
                t.date(date),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = Theme.accent,
            )
        }

        // 兩張卡取較高的那一個高度，不論關鍵字長短，版面都一樣大。
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Max),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            DayCard(
                icon = "☀",
                title = t("白天日運", "Daytime", "Día", "Giorno"),
                palace = fortune.dayPalace,
                scale = t("十二進制", "base 12", "base 12", "base 12"),
                lang = lang,
                modifier = Modifier.weight(1f),
            )
            DayCard(
                icon = "☾",
                title = t("晚上日運", "Night", "Noche", "Notte"),
                palace = fortune.nightPalace,
                scale = t("九進制", "base 9", "base 9", "base 9"),
                lang = lang,
                modifier = Modifier.weight(1f),
            )
        }

        SummaryCard(
            title = t(
                "${m}月月運", "${t.month(m)} — monthly luck",
                "${t.month(m)} — suerte mensual", "${t.month(m)} — sorte mensile",
            ),
            caption = t(
                "${y}年 第${m}個月", "Month $m of $y", "Mes $m de $y", "Mese $m del $y",
            ),
            row = monthRow,
            lang = lang,
            onClick = {
                sheetRow = monthRow
                sheetTriggers = null
            },
        )

        SummaryCard(
            title = t(
                "${y}年流年", "$y — annual luck", "$y — suerte anual", "$y — sorte annuale",
            ),
            caption = t(
                "${y}年整年的運勢", "The reading for the whole of $y",
                "La lectura de todo el año $y", "La lettura di tutto l'anno $y",
            ),
            row = yearRow,
            lang = lang,
            onClick = {
                sheetRow = yearRow
                sheetTriggers = TriggerList.year(y, destiny)
            },
        )

        SummaryCard(
            title = t(
                "當前大運", "Current luck pillar",
                "Pilar de Suerte actual", "Pilastro della Sorte attuale",
            ),
            caption = t(
                "${luck.span}（${luck.length}年）", "${luck.span} (${luck.length} yrs)",
                "${luck.span} (${luck.length} años)", "${luck.span} (${luck.length} anni)",
            ),
            row = luck.row,
            lang = lang,
            onClick = {
                sheetRow = luck.row
                sheetTriggers = TriggerList.luck(luck, destiny)
            },
        )

        val shareLabel = t(
            "分享這一天的推算", "Share this day's reading",
            "Compartir la lectura de este día", "Condividi la lettura di questo giorno",
        )
        Text(
            shareLabel,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = Theme.accent,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(cardColor)
                .clickable {
                    val text = summaryText(destiny, y, m, d, fortune, yearRow, monthRow, luck, lang)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    context.startActivity(Intent.createChooser(send, shareLabel))
                }
                .padding(vertical = 14.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )

        Spacer(Modifier.height(8.dp))
    }

    if (picking) {
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = utcMillis(date.year, date.month, date.day),
            yearRange = 1900..2100,
        )
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let {
                        val (yy, mm, dd) = fromUtcMillis(it)
                        date = BirthDate(yy, mm, dd)
                    }
                    picking = false
                }) { Text(t("完成", "Done", "Listo", "Fatto")) }
            },
            dismissButton = {
                TextButton(onClick = { picking = false }) {
                    Text(t("取消", "Cancel", "Cancelar", "Annulla"))
                }
            },
        ) { DatePicker(state = pickerState) }
    }

    sheetRow?.let {
        RowDetailSheet(it, lang, triggers = sheetTriggers) {
            sheetRow = null
            sheetTriggers = null
        }
    }
}

@Composable
private fun DayCard(
    icon: String,
    title: String,
    palace: Int,
    scale: String,
    lang: Lang,
    modifier: Modifier = Modifier,
) {
    val t = Txt(lang)
    Column(
        modifier = modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(16.dp))
            .background(cardColor)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(icon, color = Theme.accent, fontSize = 14.sp)
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = Theme.accent,
                maxLines = 1,
            )
        }

        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("$palace", fontSize = 38.sp, fontWeight = FontWeight.Bold)
            Text(
                t("宮", "palace", "palacio", "palazzo"),
                style = MaterialTheme.typography.titleSmall,
                color = secondaryText,
                modifier = Modifier.padding(bottom = 6.dp),
            )
        }

        Text(
            Palace.shortName(palace, lang),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
        )
        Text(
            Palace.brief(palace, lang),
            fontSize = 11.sp,
            color = secondaryText,
        )

        // 把進制標註推到底部，兩張卡的底線才會對齊
        Spacer(Modifier.weight(1f))

        Text(scale, fontSize = 9.sp, color = secondaryText.copy(alpha = 0.7f))
    }
}

/** 「某一段時間走哪一宮」的摘要卡，可點開看詳細。 */
@Composable
fun SummaryCard(
    title: String,
    caption: String,
    row: PalaceRow,
    lang: Lang,
    onClick: () -> Unit,
    badge: String? = null,
    /** 給大運用：點左邊那個圓圈時要做的事。沒給的話圓圈跟著整張卡走。 */
    onPalaceClick: (() -> Unit)? = null,
) {
    val t = Txt(lang)
    Box {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(cardColor)
                .clickable(onClick = onClick)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(caption, style = MaterialTheme.typography.bodySmall, color = secondaryText)
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    modifier = if (onPalaceClick != null)
                        Modifier.clip(CircleShape).clickable { onPalaceClick() }
                    else Modifier
                ) {
                    PalaceChip(row.palace, lang, highlighted = true)
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        t.palaceNamed(row.palace),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        t.triple(row.triple),
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                }
                VerdictBadge(row.reading, lang, compact = true)
            }
            Text(
                "${t.effectWord} ${t.palaceNamed(row.reading.result)}" +
                    t("　·　", "  ·  ", "  ·  ", "  ·  ") +
                    "${t.causeWord} ${t.palaceNamed(row.reading.cause)}",
                style = MaterialTheme.typography.bodySmall,
                color = secondaryText,
            )
            Text(
                Palace.brief(row.reading.result, lang),
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (badge != null) {
            Text(
                badge,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(10.dp)
                    .clip(CircleShape)
                    .background(Theme.accent)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
    }
}

/** 把當天的推算整理成純文字，方便貼給別人看。 */
private fun summaryText(
    destiny: Destiny,
    y: Int,
    m: Int,
    d: Int,
    fortune: DayFortune,
    yearRow: PalaceRow,
    monthRow: PalaceRow,
    luck: LuckPeriod,
    lang: Lang,
): String {
    val t = Txt(lang)
    fun line(label: String, row: PalaceRow) =
        "${label}：${t.palaceNamed(row.palace)}  ${t.triple(row.triple)}  ${t.reading(row.reading)}"

    val head = t(
        "九型十二宮 · ${y}年${m}月${d}日",
        "Nine & Twelve · $d ${t.month(m)} $y",
        "Nueve y Doce · $d ${t.month(m)} $y",
        "Nove e Dodici · $d ${t.month(m)} $y",
    )
    return listOf(
        head,
        t(
            "本命 ${t.triple(destiny.triple)}　${t.lifeNumber} ${destiny.lifeNumber}",
            "Natal ${t.triple(destiny.triple)} · ${t.lifeNumber} ${destiny.lifeNumber}",
            "Natal ${t.triple(destiny.triple)} · ${t.lifeNumber} ${destiny.lifeNumber}",
            "Natale ${t.triple(destiny.triple)} · ${t.lifeNumber} ${destiny.lifeNumber}",
        ),
        "",
        t(
            "白天：${t.palaceNamed(fortune.dayPalace)}",
            "Daytime: ${t.palaceNamed(fortune.dayPalace)}",
            "Día: ${t.palaceNamed(fortune.dayPalace)}",
            "Giorno: ${t.palaceNamed(fortune.dayPalace)}",
        ),
        t(
            "晚上：${t.palaceNamed(fortune.nightPalace)}",
            "Night: ${t.palaceNamed(fortune.nightPalace)}",
            "Noche: ${t.palaceNamed(fortune.nightPalace)}",
            "Notte: ${t.palaceNamed(fortune.nightPalace)}",
        ),
        line(t("月運", "Monthly", "Mensual", "Mensile"), monthRow),
        line(t("流年", "Annual", "Anual", "Annuale"), yearRow),
        line(
            t(
                "大運 ${luck.span}", "Luck Pillar ${luck.span}",
                "Pilar de Suerte ${luck.span}", "Pilastro della Sorte ${luck.span}",
            ),
            luck.row,
        ),
    ).joinToString("\n")
}
