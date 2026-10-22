package com.ninetwelve.fortune.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.R
import com.ninetwelve.fortune.billing.DirectMembership
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Txt

/**
 * 直連版（不經 Google Play 發行）的購買區塊：掃碼付款 + 啟用碼。
 *
 * 這個做法只有在不透過 Google Play 發行時才成立。從 Play 下載的 App 一律要走
 * Play 帳單，見 `src/play` 的同名檔案。
 */
@Composable
fun PurchaseSection(membership: Membership, t: Txt) {
    val direct = membership as? DirectMembership ?: return
    val clipboard = LocalClipboardManager.current
    var code by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            t(
                "${DirectMembership.PRICE_TEXT}　一個月",
                "${DirectMembership.PRICE_TEXT}  per month",
                "${DirectMembership.PRICE_TEXT}  al mes",
                "${DirectMembership.PRICE_TEXT}  al mese",
            ),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = Theme.accent,
            textAlign = TextAlign.Center,
        )

        Card(
            title = t("① 掃碼付款", "① Scan and pay", "① Escanea y paga", "① Scansiona e paga"),
            subtitle = t(
                "用微信或支付寶付款，金額依當日匯率換算。",
                "Pay with WeChat Pay or Alipay; the amount is converted at the day's exchange rate.",
                "Paga con WeChat Pay o Alipay; el importe se convierte al tipo de cambio del día.",
                "Paga con WeChat Pay o Alipay; l'importo è convertito al cambio del giorno.",
            ),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PayCode(R.drawable.pay_wechat, "WeChat Pay", Modifier.weight(1f))
                PayCode(R.drawable.pay_alipay, "Alipay 支付寶", Modifier.weight(1f))
            }
        }

        Card(
            title = t("② 把裝置碼傳給我", "② Send me your device code",
                "② Envíame tu código de dispositivo", "② Inviami il tuo codice dispositivo"),
            subtitle = t(
                "付款時附上這組碼，啟用碼會綁定這台手機。",
                "Include this code with your payment; the activation code is tied to this phone.",
                "Incluye este código con tu pago; el código de activación queda ligado a este teléfono.",
                "Includi questo codice nel pagamento; il codice di attivazione è legato a questo telefono.",
            ),
        ) {
            Text(
                direct.deviceCode,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 4.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                    .clickable {
                        clipboard.setText(AnnotatedString(direct.deviceCode))
                        status = t("已複製", "Copied", "Copiado", "Copiato")
                    }
                    .padding(vertical = 14.dp),
            )
            Text(
                t("點一下複製", "Tap to copy", "Toca para copiar", "Tocca per copiare"),
                style = MaterialTheme.typography.labelSmall,
                color = secondaryText,
            )
        }

        Card(
            title = t("③ 輸入啟用碼", "③ Enter your activation code",
                "③ Introduce el código de activación", "③ Inserisci il codice di attivazione"),
        ) {
            OutlinedTextField(
                value = code,
                onValueChange = { code = it; status = null },
                placeholder = { Text("20270819-ABCD2345") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = {
                    status = when (direct.activate(code)) {
                        null -> t("啟用成功", "Activated", "Activado", "Attivato")
                        DirectMembership.ActivationError.EMPTY -> t(
                            "請先輸入啟用碼", "Enter a code first",
                            "Introduce primero un código", "Inserisci prima un codice",
                        )
                        DirectMembership.ActivationError.INVALID -> t(
                            "啟用碼不正確，請確認是用這台手機的裝置碼產生的。",
                            "That code is not valid. Check it was generated for this phone's device code.",
                            "Ese código no es válido. Comprueba que se generó para el código de este teléfono.",
                            "Codice non valido. Verifica che sia stato generato per il codice di questo telefono.",
                        )
                        DirectMembership.ActivationError.EXPIRED -> t(
                            "這組啟用碼已經過期了。", "That code has expired.",
                            "Ese código ha caducado.", "Questo codice è scaduto.",
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Theme.accent),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(
                    t("啟用", "Activate", "Activar", "Attiva"),
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(vertical = 6.dp),
                )
            }
            status?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (direct.isActive) Theme.accent else MaterialTheme.colorScheme.error,
                )
            }
        }

        Text(
            t(
                "這個版本不是從 Google Play 安裝的，所以收款不經過商店。啟用碼綁定這台手機，換手機需要重新申請。",
                "This build was not installed from Google Play, so payment does not go through the store. The activation code is tied to this phone; a new phone needs a new code.",
                "Esta versión no se instaló desde Google Play, así que el pago no pasa por la tienda. El código de activación está ligado a este teléfono; otro teléfono necesita un código nuevo.",
                "Questa versione non è stata installata da Google Play, quindi il pagamento non passa dallo store. Il codice di attivazione è legato a questo telefono; un altro telefono richiede un codice nuovo.",
            ),
            style = MaterialTheme.typography.labelSmall,
            color = secondaryText,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun PayCode(resId: Int, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Image(
            painter = painterResource(resId),
            contentDescription = label,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .padding(6.dp),
        )
        Text(label, style = MaterialTheme.typography.labelSmall, color = secondaryText)
    }
}
