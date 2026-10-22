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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ninetwelve.fortune.engine.BirthDate
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.model.Profile
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/** 把 yyyy/M/d 轉成 DatePicker 用的 UTC 毫秒。 */
internal fun utcMillis(year: Int, month: Int, day: Int): Long {
    val c = GregorianCalendar(TimeZone.getTimeZone("UTC"))
    c.clear()
    c.set(year, month - 1, day)
    return c.timeInMillis
}

/** 反向：UTC 毫秒 → yyyy/M/d。 */
internal fun fromUtcMillis(millis: Long): kotlin.Triple<Int, Int, Int> {
    val c = GregorianCalendar(TimeZone.getTimeZone("UTC"))
    c.timeInMillis = millis
    return kotlin.Triple(
        c.get(Calendar.YEAR),
        c.get(Calendar.MONTH) + 1,
        c.get(Calendar.DAY_OF_MONTH),
    )
}

/** 出生資料輸入（姓名 + 年月日），即時顯示算出的三柱與靈數。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BirthInput(
    name: String,
    onNameChange: (String) -> Unit,
    birth: BirthDate,
    onBirthChange: (BirthDate) -> Unit,
    lang: Lang,
    showsName: Boolean = true,
) {
    val t = Txt(lang)
    var picking by remember { mutableStateOf(false) }
    val triple = birth.triple

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (showsName) {
            OutlinedTextField(
                value = name,
                onValueChange = onNameChange,
                label = { Text(t("稱呼", "Name", "Nombre", "Nome")) },
                placeholder = { Text(t("例如：自己", "e.g. Me", "p. ej. Yo", "es. Io")) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                .clickable { picking = true }
                .padding(horizontal = 14.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                t("出生日期", "Date of birth", "Fecha de nacimiento", "Data di nascita"),
                style = MaterialTheme.typography.bodyMedium,
                color = secondaryText,
                modifier = Modifier.weight(1f),
            )
            Text(
                t.date(birth),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = Theme.accent,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillarBox(t.yearPillar, triple.year, Modifier.weight(1f))
            PillarBox(t.monthPillar, triple.month, Modifier.weight(1f))
            PillarBox(t.dayPillar, triple.day, Modifier.weight(1f))
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Theme.accent)
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    t.lifeNumber,
                    fontSize = 10.sp,
                    color = Color.White.copy(alpha = 0.85f),
                    maxLines = 1,
                )
                Text(
                    "${triple.lifeNumber}",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }
        }
    }

    if (picking) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = utcMillis(birth.year, birth.month, birth.day),
            yearRange = 1900..2100,
        )
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let {
                        val (y, m, d) = fromUtcMillis(it)
                        onBirthChange(BirthDate(y, m, d))
                    }
                    picking = false
                }) { Text(t("完成", "Done", "Listo", "Fatto")) }
            },
            dismissButton = {
                TextButton(onClick = { picking = false }) {
                    Text(t("取消", "Cancel", "Cancelar", "Annulla"))
                }
            },
        ) {
            DatePicker(state = state)
        }
    }
}

@Composable
private fun PillarBox(label: String, value: Int, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, fontSize = 10.sp, color = secondaryText, maxLines = 1)
        Text("$value", fontSize = 22.sp, fontWeight = FontWeight.Bold)
    }
}

/** 首次啟動時的輸入畫面。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen(
    lang: Lang,
    onLangChange: (Lang) -> Unit,
    onDone: (Profile) -> Unit,
) {
    val t = Txt(lang)
    var name by remember { mutableStateOf("") }
    var birth by remember { mutableStateOf(BirthDate(2000, 1, 1)) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(pageColor)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            modifier = Modifier.padding(top = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                t("九型十二宮", "Nine & Twelve", "Nueve y Doce", "Nove e Dodici"),
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                t(
                    "輸入你的出生年月日，排出命盤",
                    "Enter your date of birth to cast your chart",
                    "Introduce tu fecha de nacimiento para trazar tu carta",
                    "Inserisci la tua data di nascita per tracciare la carta",
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = secondaryText,
                textAlign = TextAlign.Center,
            )
        }

        LangPicker(lang, onLangChange)

        Card { BirthInput(name, { name = it }, birth, { birth = it }, lang) }

        Button(
            onClick = { onDone(Profile(name = name, birth = birth)) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Theme.accent),
            shape = RoundedCornerShape(14.dp),
        ) {
            Text(
                t("排盤", "Cast chart", "Trazar carta", "Traccia la carta"),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(vertical = 6.dp),
            )
        }

        Text(
            t(
                "資料只儲存在這台裝置上，不會上傳。",
                "Your data stays on this device and is never uploaded.",
                "Tus datos se quedan en este dispositivo y nunca se envían a ningún sitio.",
                "I tuoi dati restano su questo dispositivo e non vengono mai inviati altrove.",
            ),
            style = MaterialTheme.typography.labelSmall,
            color = secondaryText,
            textAlign = TextAlign.Center,
        )
    }
}

/** 這個版本開放的兩種語言之間切換。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LangPicker(lang: Lang, onLangChange: (Lang) -> Unit) {
    val options = Lang.available
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        options.forEachIndexed { i, l ->
            SegmentedButton(
                selected = l == lang,
                onClick = { onLangChange(l) },
                shape = SegmentedButtonDefaults.itemShape(index = i, count = options.size),
            ) { Text(l.title, maxLines = 1) }
        }
    }
}
