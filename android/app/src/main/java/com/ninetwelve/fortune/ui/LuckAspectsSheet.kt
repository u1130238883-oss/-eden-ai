package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.LuckPeriod
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Txt

/**
 * 一段大運的十二個方面。
 *
 * 以該大運最後一年的年運為第一宮，往下接滿十二宮；
 * 第 N 宮就用第 N 宮的含義去讀。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LuckAspectsSheet(
    destiny: Destiny,
    period: LuckPeriod,
    lang: Lang,
    onDismiss: () -> Unit,
) {
    val t = Txt(lang)
    val aspects = remember(destiny, period) { destiny.luckAspects(period.startYear) }
    // 詳情頁除了那一列，還要帶著「以第幾宮的含義去讀」
    var sheetRow by remember { mutableStateOf<Pair<PalaceRow, Int>?>(null) }
    // 點最上面那張卡時，詳情頁要列出的引動
    var sheetTriggers by remember { mutableStateOf<TriggerList?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = pageColor,
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                t("大運十二方面", "Twelve aspects", "Los doce aspectos", "I dodici aspetti"),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )

            Card(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .clickable {
                        sheetRow = period.row to period.row.palace
                        sheetTriggers = TriggerList.luck(period, destiny)
                    },
                title = period.span,
                subtitle = t(
                    "這一段大運的十二個方面",
                    "The twelve aspects of this pillar",
                    "Los doce aspectos de este pilar",
                    "I dodici aspetti di questo pilastro",
                ),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    PalaceChip(period.row.palace, lang, highlighted = true)
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(
                            t.palaceNamed(period.row.palace),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            t.triple(period.row.triple),
                            style = MaterialTheme.typography.bodySmall,
                            color = secondaryText,
                        )
                    }
                    VerdictBadge(period.row.reading, lang, compact = true)
                }
            }

            aspects.forEach { item ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(cardColor)
                        .clickable {
                            sheetRow = item.row to item.aspect
                            sheetTriggers = null
                        }
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // 這個數字是「第幾個方面」，也就是要用哪一宮的含義去讀
                        PalaceChip(item.aspect, lang, highlighted = true)
                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            Text(
                                t.palaceNamed(item.aspect),
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Text(
                                t.triple(item.row.triple),
                                style = MaterialTheme.typography.bodySmall,
                                color = secondaryText,
                            )
                        }
                        VerdictBadge(item.row.reading, lang, compact = true)
                    }
                    Text(
                        Palace.brief(item.aspect, lang),
                        style = MaterialTheme.typography.bodySmall,
                        color = secondaryText,
                    )
                }
            }
        }
    }

    sheetRow?.let { (row, palace) ->
        RowDetailSheet(row, lang, palace, sheetTriggers) {
            sheetRow = null
            sheetTriggers = null
        }
    }
}
