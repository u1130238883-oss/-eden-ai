package com.ninetwelve.fortune.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Txt

/**
 * 未訂閱時，命盤／運程／合盤三頁顯示的解鎖畫面。
 *
 * 上半部（說明與權益）兩種發行管道共用；下半部的購買區塊由 flavor 提供
 * （`src/play/.../PurchaseSection.kt` 與 `src/direct/.../PurchaseSection.kt`），
 * 因為 Google Play 版必須走 Play 帳單，而直連版走微信／支付寶 + 啟用碼。
 */
@Composable
fun PaywallScreen(title: String, t: Txt, membership: Membership) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            modifier = Modifier.padding(top = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("🔒", fontSize = 44.sp)
            Text(
                t("解鎖完整功能", "Unlock the full app", "Desbloquea la app completa", "Sblocca l'app completa"),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                t(
                    "命盤、運程與合盤需要會員。今日的日運永遠免費。",
                    "The chart, fortune and synastry pages need a membership. The daily reading stays free.",
                    "Las páginas de carta, destino y sinastría requieren membresía. La lectura diaria sigue siendo gratuita.",
                    "Le pagine carta, sorte e sinastria richiedono l'abbonamento. La lettura giornaliera resta gratuita.",
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = secondaryText,
                textAlign = TextAlign.Center,
            )
            Text(
                title,
                style = MaterialTheme.typography.labelMedium,
                color = Theme.accent,
            )
        }

        Card {
            Perk("◎", t("本命十二宮盤與三柱", "Your natal twelve-palace chart and pillars",
                "Tu carta natal de doce palacios y sus pilares",
                "La tua carta natale a dodici palazzi e i pilastri"))
            Perk("↗", t("大運、流年、月運", "Luck Pillars, annual and monthly luck",
                "Pilares de Suerte, suerte anual y mensual",
                "Pilastri della Sorte, sorte annuale e mensile"))
            Perk("♁", t("與任何人合盤", "Synastry with anyone",
                "Sinastría con cualquier persona", "Sinastria con chiunque"))
            Perk("✱", t("每一列的完整推算與宮位含義",
                "Full workings and palace meanings for every row",
                "Cálculo completo y significados de cada fila",
                "Calcolo completo e significati per ogni riga"))
        }

        PurchaseSection(membership, t)

        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun Perk(icon: String, text: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(icon, color = Theme.accent, fontSize = 14.sp, modifier = Modifier.width(22.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
    }
}
