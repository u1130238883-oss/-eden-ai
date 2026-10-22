package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.Enneagram
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Num
import com.ninetwelve.fortune.engine.Txt

/** 九型人格每一型的代表色。 */
fun enneagramColor(type: Int): Color = Color(Enneagram.colorHex(type) or 0xFF000000.toInt())

/** 命盤上的九型人格入口：靈數幾就是第幾型。點開看完整內容。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EnneagramCard(lifeNumber: Int, lang: Lang) {
    val t = Txt(lang)
    val type = Enneagram.typeForLifeNumber(lifeNumber)
    var showing by remember { mutableStateOf(false) }

    // 圓圈靠右，上下對整張卡置中
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(cardColor)
            .clickable { showing = true }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                t("九型人格", "Enneagram", "Eneagrama", "Enneagramma"),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    Enneagram.label(type, lang),
                    style = MaterialTheme.typography.bodySmall,
                    color = secondaryText,
                )
                Text(
                    Enneagram.name(type, lang),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    Enneagram.tagline(type, lang),
                    style = MaterialTheme.typography.bodySmall,
                    color = secondaryText,
                )
            }
        }
        TypeBadge(type, 54.dp)
    }

    if (showing) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { showing = false },
            sheetState = sheetState,
            containerColor = pageColor,
        ) {
            EnneagramDetail(type, lang)
        }
    }
}

/** 圓形的型號標記，填該型的代表色。 */
@Composable
fun TypeBadge(type: Int, size: Dp = 54.dp) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(enneagramColor(type)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "${Num.r9(type)}",
            fontSize = (size.value * 0.44f).sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
        )
    }
}

/** 某一型的完整內容。 */
@Composable
private fun EnneagramDetail(type: Int, lang: Lang) {
    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // 頂部：整片色塊，型號與型名
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(enneagramColor(type))
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                Enneagram.label(type, lang),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.9f),
            )
            Text(
                Enneagram.name(type, lang),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Text(
                Enneagram.tagline(type, lang),
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.85f),
            )
        }

        Card {
            Text(Enneagram.summary(type, lang), style = MaterialTheme.typography.bodyMedium)
        }

        for (i in 0 until Enneagram.SECTION_COUNT) {
            Card(title = Enneagram.sectionTitle(i, lang)) {
                for (line in Enneagram.section(type, i, lang)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(
                            modifier = Modifier
                                .padding(top = 7.dp)
                                .size(5.dp)
                                .clip(CircleShape)
                                .background(enneagramColor(type))
                        )
                        Text(line, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}
