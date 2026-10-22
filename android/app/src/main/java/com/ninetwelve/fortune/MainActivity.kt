package com.ninetwelve.fortune

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.model.AppState
import com.ninetwelve.fortune.ui.FortuneScreen
import com.ninetwelve.fortune.ui.NatalScreen
import com.ninetwelve.fortune.ui.NineTwelveTheme
import com.ninetwelve.fortune.ui.OnboardingScreen
import com.ninetwelve.fortune.ui.PaywallScreen
import com.ninetwelve.fortune.ui.SettingsScreen
import com.ninetwelve.fortune.ui.SynastryScreen
import com.ninetwelve.fortune.ui.Theme
import com.ninetwelve.fortune.ui.TodayScreen
import com.ninetwelve.fortune.ui.pageColor

class MainActivity : ComponentActivity() {

    private val membership: Membership
        get() = (application as NineTwelveApplication).membership

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            NineTwelveTheme {
                val state: AppState = viewModel()
                RootScreen(state, membership)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // 回到 App 時重新確認一次會員狀態（例如剛在商店取消或續訂）
        membership.refresh()
    }
}

private enum class Tab { TODAY, CHART, FORTUNE, SYNASTRY, SETTINGS }

private fun Tab.title(t: Txt): String = when (this) {
    Tab.TODAY -> t("今日", "Today", "Hoy", "Oggi")
    Tab.CHART -> t("命盤", "Chart", "Carta", "Carta")
    Tab.FORTUNE -> t("運程", "Fortune", "Destino", "Sorte")
    Tab.SYNASTRY -> t("合盤", "Synastry", "Sinastría", "Sinastria")
    Tab.SETTINGS -> t("設定", "Settings", "Ajustes", "Impostazioni")
}

private val Tab.glyph: String
    get() = when (this) {
        Tab.TODAY -> "☀"
        Tab.CHART -> "◎"
        Tab.FORTUNE -> "↗"
        Tab.SYNASTRY -> "♁"
        Tab.SETTINGS -> "⚙"
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RootScreen(state: AppState, membership: Membership) {
    val t = state.t

    if (state.owner == null) {
        OnboardingScreen(state.lang, { state.lang = it }) { state.owner = it }
        return
    }

    var tab by remember { mutableStateOf(Tab.TODAY) }

    Scaffold(
        containerColor = pageColor,
        topBar = {
            TopAppBar(
                title = {
                    Text(tab.title(t), fontWeight = FontWeight.Bold)
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = pageColor,
                    titleContentColor = Theme.accent,
                ),
            )
        },
        bottomBar = {
            NavigationBar(containerColor = pageColor) {
                Tab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = { Text(item.glyph, fontSize = 17.sp) },
                        label = { Text(item.title(t), fontSize = 10.sp, maxLines = 1) },
                    )
                }
            }
        },
    ) { padding ->
        androidx.compose.foundation.layout.Box(Modifier.padding(padding)) {
            when (tab) {
                // 今日免費：日運是入口，讓人先看得到東西
                Tab.TODAY -> TodayScreen(state)

                // 以下三頁需要會員
                Tab.CHART -> Gated(membership, tab.title(t), t) { NatalScreen(state) }
                Tab.FORTUNE -> Gated(membership, tab.title(t), t) { FortuneScreen(state) }
                Tab.SYNASTRY -> Gated(membership, tab.title(t), t) { SynastryScreen(state) }

                Tab.SETTINGS -> SettingsScreen(state, membership)
            }
        }
    }
}

/** 有會員就顯示內容，沒有就顯示解鎖畫面。 */
@Composable
private fun Gated(
    membership: Membership,
    title: String,
    t: Txt,
    content: @Composable () -> Unit,
) {
    if (membership.isActive) content() else PaywallScreen(title, t, membership)
}
