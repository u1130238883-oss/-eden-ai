package com.ninetwelve.fortune.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Txt

/**
 * 解鎖版不會用到 —— [PaywallScreen] 只在沒有會員時才顯示，
 * 而這個版本永遠是有會員的。留一個空實作讓程式能編譯。
 */
@Composable
fun PurchaseSection(membership: Membership, t: Txt) {
    Text(
        t("這個版本沒有付費機制。", "This build has no payment features.",
          "Esta versión no tiene pagos.", "Questa versione non ha pagamenti."),
        style = MaterialTheme.typography.bodySmall,
        color = secondaryText,
    )
}
