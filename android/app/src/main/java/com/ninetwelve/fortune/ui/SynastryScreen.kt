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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import com.ninetwelve.fortune.engine.BirthDate
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Synastry
import com.ninetwelve.fortune.model.AppState
import com.ninetwelve.fortune.model.Profile

/** 合盤：輸入另一個人的生日，兩盤三柱相加後排出十二宮。 */
@Composable
fun SynastryScreen(state: AppState) {
    val mine = state.destiny ?: return
    val t = state.t

    var name by remember { mutableStateOf("") }
    var birth by remember { mutableStateOf(BirthDate(2000, 1, 1)) }
    var result by remember { mutableStateOf<Synastry?>(null) }
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
            title = t(
                "對方的出生資料", "The other person's birth details",
                "Datos de nacimiento de la otra persona", "Dati di nascita dell'altra persona",
            )
        ) {
            BirthInput(name, { name = it }, birth, { birth = it }, state.lang)
            Button(
                onClick = {
                    val other = Profile(name = name, birth = birth)
                    state.addOther(other)
                    result = Synastry(mine, other.destiny(state.yearAnchor))
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Theme.accent),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(
                    t("合盤", "Combine charts", "Combinar cartas", "Combina le carte"),
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(vertical = 4.dp),
                )
            }
        }

        if (state.others.isNotEmpty()) {
            Card(
                title = t(
                    "最近合過的人", "Recently combined",
                    "Combinados recientemente", "Combinati di recente",
                )
            ) {
                state.others.forEachIndexed { i, p ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                name = p.name
                                birth = p.birth
                                result = Synastry(mine, p.destiny(state.yearAnchor))
                            }
                            .padding(vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            p.displayName(state.lang),
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            t.date(p.birth),
                            style = MaterialTheme.typography.bodySmall,
                            color = secondaryText,
                        )
                        Text(" ›", color = secondaryText, fontSize = 14.sp)
                    }
                    if (i < state.others.size - 1) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }
            }
        }

        result?.let { s -> ResultSection(state, s) { sheetRow = it } }
    }

    sheetRow?.let { RowDetailSheet(it, state.lang) { sheetRow = null } }
}

@Composable
private fun ResultSection(
    state: AppState,
    s: Synastry,
    onSelect: (PalaceRow) -> Unit,
) {
    val t = state.t

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            t(
                "合盤十二宮", "The combined twelve palaces",
                "Los doce palacios combinados", "I dodici palazzi combinati",
            ),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
        ChartTable(s.chart, state.lang, highlightIndex = 0, onSelect = onSelect)
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
