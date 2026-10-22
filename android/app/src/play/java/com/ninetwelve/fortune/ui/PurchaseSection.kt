package com.ninetwelve.fortune.ui

import android.app.Activity
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Txt

/**
 * Google Play 版的購買區塊。
 *
 * Play 的付款政策要求：在 Play 上架的 App，App 內解鎖數位功能一律走 Google Play 帳單。
 * 因此這裡只有一顆「訂閱」按鈕，價格與扣款都由 Play 處理。
 */
@Composable
fun PurchaseSection(membership: Membership, t: Txt) {
    val context = LocalContext.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        when {
            membership.isLoading -> CircularProgressIndicator(modifier = Modifier.padding(16.dp))

            membership.priceText != null -> Button(
                onClick = { (context as? Activity)?.let { membership.purchase(it) } },
                enabled = !membership.isBusy,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Theme.accent),
                shape = RoundedCornerShape(14.dp),
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(vertical = 6.dp),
                ) {
                    Text(
                        t("成為會員", "Become a member", "Hazte miembro", "Diventa membro"),
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        t(
                            "${membership.priceText} / 月", "${membership.priceText} / month",
                            "${membership.priceText} / mes", "${membership.priceText} / mese",
                        ),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            else -> Text(
                // 通常是還沒在 Play Console 建立商品、這台裝置沒有 Play 服務，或離線
                t(
                    "目前無法取得訂閱資訊，請稍後再試。",
                    "Subscription information is unavailable right now. Please try again later.",
                    "La información de la suscripción no está disponible ahora. Inténtalo más tarde.",
                    "Le informazioni sull'abbonamento non sono disponibili ora. Riprova più tardi.",
                ),
                style = MaterialTheme.typography.bodySmall,
                color = secondaryText,
                textAlign = TextAlign.Center,
            )
        }

        Text(
            t("回復購買", "Restore purchases", "Restaurar compras", "Ripristina acquisti"),
            style = MaterialTheme.typography.bodyMedium,
            color = Theme.accent,
            modifier = Modifier
                .clickable { membership.refresh() }
                .padding(8.dp),
        )

        membership.errorMessage?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                textAlign = TextAlign.Center,
            )
        }

        Text(
            t(
                "訂閱每月自動續訂，可隨時在 Google Play 的「訂閱」中取消。付款於確認購買時由 Google Play 收取。",
                "The subscription renews monthly and can be cancelled any time under Subscriptions in Google Play. Payment is charged by Google Play on confirmation.",
                "La suscripción se renueva cada mes y puede cancelarse en cualquier momento en Suscripciones de Google Play. El pago lo cobra Google Play al confirmar.",
                "L'abbonamento si rinnova ogni mese e può essere annullato in qualsiasi momento in Abbonamenti su Google Play. Il pagamento viene addebitato da Google Play alla conferma.",
            ),
            style = MaterialTheme.typography.labelSmall,
            color = secondaryText,
            textAlign = TextAlign.Center,
        )
    }
}
