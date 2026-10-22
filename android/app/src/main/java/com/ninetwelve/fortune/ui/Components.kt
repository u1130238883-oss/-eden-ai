package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.Element
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Reading
import com.ninetwelve.fortune.engine.Txt

/** 卡片容器。 */
@Composable
fun Card(
    modifier: Modifier = Modifier,
    title: String? = null,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardColor)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (title != null || subtitle != null) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                if (title != null) {
                    Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                }
                if (subtitle != null) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                }
            }
        }
        content()
    }
}

/** 「好3因8」／「Favorable 3 from 8」的色塊。 */
@Composable
fun VerdictBadge(reading: Reading, lang: Lang, compact: Boolean = false) {
    val t = Txt(lang)
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Theme.color(reading.verdict))
            .padding(horizontal = if (compact) 8.dp else 10.dp, vertical = if (compact) 4.dp else 6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val size = if (compact) 12.sp else 14.sp
        Text(t.verdict(reading.verdict), color = Color.White, fontSize = size, fontWeight = FontWeight.Bold, maxLines = 1)
        Text("${reading.result}", color = Color.White, fontSize = size, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(t.causeParticle, color = Color.White.copy(alpha = 0.78f), fontSize = size * 0.85f, maxLines = 1)
        Text("${reading.cause}", color = Color.White, fontSize = size, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

/** 宮位圓標。 */
@Composable
fun PalaceChip(palace: Int, lang: Lang = Lang.ZH, highlighted: Boolean = false) {
    val element = Element.of(palace)
    Box(
        modifier = Modifier
            .size(38.dp)
            .clip(CircleShape)
            .background(Theme.color(element))
            .then(
                if (highlighted) Modifier.border(2.5.dp, Theme.accent, CircleShape) else Modifier
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "$palace",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
            Text(
                element.name(lang),
                color = Color.White.copy(alpha = 0.9f),
                fontSize = if (lang == Lang.ZH) 8.sp else 6.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
            )
        }
    }
}

/** 標籤 + 數值的一行。 */
@Composable
fun LabeledLine(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = secondaryText,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(12.dp))
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 因 → 果 的小圖，說明這一列的來龍去脈落在哪兩個宮。 */
@Composable
fun CauseEffectFlow(row: PalaceRow, lang: Lang, displayPalace: Int = row.palace) {
    val t = Txt(lang)
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FlowNode(row.reading.cause, t.causeWord, lang)
            Text("→", color = secondaryText, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            FlowNode(row.reading.result, t.effectWord, lang)
        }
        Text(
            t(
                "發生在 ${t.palaceNamed(displayPalace)}",
                "playing out in ${t.palaceNamed(displayPalace)}",
                "ocurre en ${t.palaceNamed(displayPalace)}",
                "si svolge in ${t.palaceNamed(displayPalace)}",
            ),
            style = MaterialTheme.typography.bodySmall,
            color = secondaryText,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun FlowNode(palace: Int, caption: String, lang: Lang) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text(
            caption,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = secondaryText,
        )
        PalaceChip(palace, lang)
        Text(
            Palace.shortName(palace, lang),
            style = MaterialTheme.typography.labelSmall,
            textAlign = TextAlign.Center,
            maxLines = 2,
            modifier = Modifier.widthIn(max = 96.dp),
        )
    }
}
