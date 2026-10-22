package com.ninetwelve.fortune.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.ninetwelve.fortune.engine.Element
import com.ninetwelve.fortune.engine.Verdict

/** 顏色，與 iOS 版 `Views/Palette.swift` 相同。 */
object Theme {

    val accent = Color(0xFF9E7329)

    fun color(verdict: Verdict): Color = when (verdict) {
        Verdict.GOOD -> Color(0xFF22996B)
        Verdict.NEUTRAL -> Color(0xFF2973C7)
        Verdict.BAD -> Color(0xFFC7473D)
    }

    fun color(element: Element): Color = when (element) {
        Element.METAL -> Color(0xFF8C919E)
        Element.WOOD -> Color(0xFF409457)
        Element.WATER -> Color(0xFF337AB8)
        Element.FIRE -> Color(0xFFCC5742)
        Element.EARTH -> Color(0xFFA8803D)
    }
}

private val LightColors = lightColorScheme(
    primary = Theme.accent,
    onPrimary = Color.White,
    secondary = Theme.accent,
    background = Color(0xFFF2F2F7),
    onBackground = Color(0xFF11131A),
    surface = Color(0xFFF2F2F7),
    onSurface = Color(0xFF11131A),
    surfaceVariant = Color(0xFFFFFFFF),
    onSurfaceVariant = Color(0xFF5B5F66),
    outlineVariant = Color(0xFFDDDDE3),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFC69A42),
    onPrimary = Color(0xFF1A1A26),
    secondary = Color(0xFFC69A42),
    background = Color(0xFF0C0C12),
    onBackground = Color(0xFFE8E2D4),
    surface = Color(0xFF0C0C12),
    onSurface = Color(0xFFE8E2D4),
    surfaceVariant = Color(0xFF1A1A26),
    onSurfaceVariant = Color(0xFF9B9AA6),
    outlineVariant = Color(0xFF2A2A38),
)

/** 卡片底色（對應 iOS 的 secondarySystemGroupedBackground）。 */
val cardColor: Color
    @Composable get() = MaterialTheme.colorScheme.surfaceVariant

/** 頁面底色（對應 iOS 的 systemGroupedBackground）。 */
val pageColor: Color
    @Composable get() = MaterialTheme.colorScheme.background

/** 次要文字色。 */
val secondaryText: Color
    @Composable get() = MaterialTheme.colorScheme.onSurfaceVariant

@Composable
fun NineTwelveTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = Typography(),
        content = content,
    )
}
