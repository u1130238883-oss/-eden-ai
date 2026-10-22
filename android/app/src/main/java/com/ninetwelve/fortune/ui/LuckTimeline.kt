package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.LuckPeriod
import com.ninetwelve.fortune.engine.Txt
import kotlin.math.max

/**
 * 一生大運的橫向時間軸。每段寬度與年數成比例，顏色是該段的判定，
 * 開啟時自動捲到現在所處的那一段。
 */
@Composable
fun LuckTimeline(
    periods: List<LuckPeriod>,
    birthYear: Int,
    currentYear: Int,
    lang: Lang,
    onSelect: (LuckPeriod) -> Unit,
) {
    val t = Txt(lang)
    val state = rememberLazyListState()
    val nowIndex = periods.indexOfFirst { it.contains(currentYear) }

    LaunchedEffect(nowIndex) {
        if (nowIndex >= 0) state.scrollToItem(max(0, nowIndex - 1))
    }

    LazyRow(
        state = state,
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        contentPadding = PaddingValues(vertical = 4.dp),
    ) {
        items(periods.size) { i ->
            val p = periods[i]
            val isNow = p.contains(currentYear)
            val startAge = max(0, p.startYear - birthYear)
            val endAge = max(0, p.endYear - birthYear)

            Column(
                modifier = Modifier
                    .width(max(56, p.length * 15).dp)
                    .clickable { onSelect(p) },
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(
                    "${p.startYear}",
                    fontSize = 11.sp,
                    fontWeight = if (isNow) FontWeight.Bold else FontWeight.Normal,
                    color = if (isNow) Theme.accent else secondaryText,
                    maxLines = 1,
                )
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clip(RoundedCornerShape(7.dp))
                        .background(Theme.color(p.row.reading.verdict))
                        .then(
                            if (isNow) Modifier.border(3.dp, Theme.accent, RoundedCornerShape(7.dp))
                            else Modifier
                        )
                        .padding(horizontal = 7.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Column {
                        Text(
                            "${p.row.palace}",
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                        )
                        Text(
                            t.verdict(p.row.reading.verdict),
                            color = Color.White,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                        )
                    }
                }
                Text(
                    t(
                        "${startAge}–${endAge}歲", "age ${startAge}–$endAge",
                        "${startAge}–$endAge años", "${startAge}–$endAge anni",
                    ),
                    fontSize = 9.sp,
                    color = secondaryText,
                    maxLines = 1,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}
