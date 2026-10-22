package com.ninetwelve.fortune.ui

import android.content.Intent
import android.net.Uri
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Element
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.YearAnchor
import com.ninetwelve.fortune.model.AppState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(state: AppState, membership: Membership) {
    val t = state.t
    val context = LocalContext.current
    var editing by remember { mutableStateOf(false) }
    var confirmReset by remember { mutableStateOf(false) }
    var showMeanings by remember { mutableStateOf(false) }

    if (showMeanings) {
        MeaningsScreen(state) { showMeanings = false }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        state.owner?.let { owner ->
            Card(
                title = t(
                    "本命資料", "Your birth details",
                    "Tus datos de nacimiento", "I tuoi dati di nascita",
                )
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(
                            owner.displayName(state.lang),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            t.date(owner.birth),
                            style = MaterialTheme.typography.bodySmall,
                            color = secondaryText,
                        )
                    }
                    Text(
                        t.triple(owner.birth.triple),
                        style = MaterialTheme.typography.bodyMedium,
                        color = secondaryText,
                    )
                }
                Text(
                    t(
                        "修改出生資料", "Edit birth details",
                        "Editar datos de nacimiento", "Modifica i dati di nascita",
                    ),
                    color = Theme.accent,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { editing = true }
                        .padding(vertical = 6.dp),
                )
            }
        }

        Card(title = t("會員", "Membership", "Membresía", "Abbonamento")) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(if (membership.isActive) "✓ " else "🔒 ", fontSize = 14.sp)
                Text(
                    when {
                        membership.isFree ->
                            t("完整版", "Full version", "Versión completa", "Versione completa")
                        membership.isActive ->
                            t("會員使用中", "Membership active", "Membresía activa", "Abbonamento attivo")
                        else ->
                            t("尚未成為會員", "Not a member yet", "Aún no eres miembro", "Non sei ancora membro")
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f),
                )
            }
            membership.expiryText?.let { exp ->
                LabeledLine(t("有效期至", "Valid until", "Válido hasta", "Valido fino al"), exp)
            }
            val manage = membership.manageUrl
            if (membership.isFree) {
                // 解鎖版沒有商店可跳轉，也沒有東西要刷新
            } else if (membership.isActive && manage != null) {
                Text(
                    t("管理訂閱", "Manage subscription", "Gestionar suscripción", "Gestisci abbonamento"),
                    color = Theme.accent,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(manage)))
                        }
                        .padding(vertical = 6.dp),
                )
            } else if (!membership.isActive) {
                Text(
                    t("重新確認會員狀態", "Refresh membership", "Actualizar membresía", "Aggiorna abbonamento"),
                    color = Theme.accent,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { membership.refresh() }
                        .padding(vertical = 6.dp),
                )
            }
            Text(
                if (membership.isFree)
                    t(
                        "這個版本沒有付費機制，全部功能都開放。",
                        "This build has no payment features; everything is unlocked.",
                        "Esta versión no tiene pagos; todo está desbloqueado.",
                        "Questa versione non ha pagamenti; tutto è sbloccato.",
                    )
                else if (membership.isActive)
                    t(
                        "命盤、運程與合盤已解鎖。",
                        "The chart, fortune and synastry pages are unlocked.",
                        "Las páginas de carta, destino y sinastría están desbloqueadas.",
                        "Le pagine carta, sorte e sinastria sono sbloccate.",
                    )
                else
                    t(
                        "命盤、運程與合盤需要會員；今日的日運永遠免費。",
                        "The chart, fortune and synastry pages need a membership; the daily reading stays free.",
                        "Las páginas de carta, destino y sinastría requieren membresía; la lectura diaria es siempre gratuita.",
                        "Le pagine carta, sorte e sinastria richiedono l'abbonamento; la lettura giornaliera è sempre gratuita.",
                    ),
                style = MaterialTheme.typography.bodySmall,
                color = secondaryText,
            )
        }

        Card(title = t("語言", "Language", "Idioma", "Lingua")) {
            LangPicker(state.lang) { state.lang = it }
        }

        Card(title = t("說明", "Reference", "Referencia", "Riferimento")) {
            Text(
                t(
                    "十二宮含義", "Meanings of the twelve palaces",
                    "Significados de los doce palacios", "Significati dei dodici palazzi",
                ),
                color = Theme.accent,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showMeanings = true }
                    .padding(vertical = 6.dp),
            )
        }

        Card(
            title = t("流年", "Annual luck", "Suerte anual", "Sorte annuale"),
            subtitle = state.yearAnchor.detail(state.lang),
        ) {
            YearAnchor.entries.forEach { a ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { state.yearAnchor = a },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = state.yearAnchor == a, onClick = { state.yearAnchor = a })
                    Text(a.title(state.lang), style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        Card {
            Text(
                t("清除全部資料", "Erase all data", "Borrar todos los datos", "Cancella tutti i dati"),
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { confirmReset = true }
                    .padding(vertical = 6.dp),
            )
            Text(
                t(
                    "所有資料只存在本機，不會上傳任何伺服器。",
                    "Everything is stored on this device only and is never sent to a server.",
                    "Todo se guarda solo en este dispositivo y nunca se envía a ningún servidor.",
                    "Tutto è salvato solo su questo dispositivo e non viene mai inviato a un server.",
                ),
                style = MaterialTheme.typography.bodySmall,
                color = secondaryText,
            )
        }
    }

    if (editing) {
        EditProfileDialog(state) { editing = false }
    }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = {
                Text(t("清除全部資料？", "Erase all data?", "¿Borrar todos los datos?", "Cancellare tutti i dati?"))
            },
            text = {
                Text(
                    t(
                        "本命資料與合盤紀錄都會被刪除，無法復原。",
                        "Your birth details and synastry history will be deleted. This cannot be undone.",
                        "Se borrarán tus datos de nacimiento y el historial de sinastría. No se puede deshacer.",
                        "I tuoi dati di nascita e la cronologia della sinastria verranno eliminati. L'operazione non è reversibile.",
                    )
                )
            },
            confirmButton = {
                TextButton(onClick = { state.reset(); confirmReset = false }) {
                    Text(
                        t("清除", "Erase", "Borrar", "Cancella"),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmReset = false }) {
                    Text(t("取消", "Cancel", "Cancelar", "Annulla"))
                }
            },
        )
    }
}

@Composable
private fun EditProfileDialog(state: AppState, onDismiss: () -> Unit) {
    val t = state.t
    val owner = state.owner ?: return
    var name by remember { mutableStateOf(owner.name) }
    var birth by remember { mutableStateOf(owner.birth) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                t(
                    "修改出生資料", "Edit birth details",
                    "Editar datos de nacimiento", "Modifica i dati di nascita",
                )
            )
        },
        text = { BirthInput(name, { name = it }, birth, { birth = it }, state.lang) },
        confirmButton = {
            TextButton(onClick = {
                state.owner = owner.copy(name = name, birth = birth)
                onDismiss()
            }) { Text(t("儲存", "Save", "Guardar", "Salva")) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(t("取消", "Cancel", "Cancelar", "Annulla")) }
        },
    )
}

/** 十二宮含義瀏覽，可用關鍵字搜尋（中英文都會一起比對）。 */
@Composable
fun MeaningsScreen(state: AppState, onBack: () -> Unit) {
    val t = state.t
    var query by remember { mutableStateOf("") }

    val q = query.trim().lowercase()
    val matches = (1..12).mapNotNull { p ->
        if (q.isEmpty()) p to emptyList<String>()
        else {
            // 兩種語言都比對，這樣用中文也能找到英文條目，反之亦然
            val all = Palace.keywords(p, Lang.ZH) + Palace.keywords(p, Lang.EN) +
                Palace.keywords(p, state.lang) +
                listOf(
                    Palace.shortName(p, Lang.ZH),
                    Palace.shortName(p, Lang.EN),
                    Palace.shortName(p, state.lang),
                )
            val hits = all.filter { it.lowercase().contains(q) }.distinct()
            if (hits.isEmpty()) null else p to hits
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "‹ " + t("設定", "Settings", "Ajustes", "Impostazioni"),
                color = Theme.accent,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClick = onBack)
                    .padding(vertical = 6.dp, horizontal = 4.dp),
            )
        }

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = {
                Text(
                    t(
                        "搜尋含義，例如：婚姻、正財", "Search meanings, e.g. marriage, wealth",
                        "Buscar significados, p. ej. matrimonio, riqueza",
                        "Cerca significati, es. matrimonio, ricchezza",
                    )
                )
            },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        if (matches.isEmpty()) {
            Text(
                t(
                    "找不到「${query}」", "No match for “${query}”",
                    "Sin resultados para «${query}»", "Nessun risultato per «${query}»",
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = secondaryText,
            )
        }

        matches.forEach { (p, hits) ->
            Card {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    PalaceChip(p, state.lang)
                    Text(
                        t.palaceNamed(p),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        t.element(Element.of(p)),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold,
                        color = Theme.color(Element.of(p)),
                    )
                }
                if (hits.isNotEmpty()) {
                    Text(
                        hits.joinToString(t.listSeparator),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = Theme.accent,
                    )
                }
                Text(
                    Palace.text(p, state.lang),
                    style = MaterialTheme.typography.bodyMedium,
                    color = secondaryText,
                )
            }
        }
    }
}
