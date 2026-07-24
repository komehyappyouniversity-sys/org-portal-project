package jp.komehyappyo.member.next.core.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object BrandColors {
    val Primary = Color(0xFF3F7D58)
    val Secondary = Color(0xFFD7E8D5)
    val Accent = Color(0xFFF4A261)
    val Error = Color(0xFFBA1A1A)
}

private val OrgPortalColorScheme = lightColorScheme(
    primary = BrandColors.Primary,
    secondary = BrandColors.Secondary,
    tertiary = BrandColors.Accent,
    error = BrandColors.Error,
)

private val OrgPortalDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9FD5AE),
    secondary = Color(0xFFB8CCB7),
    tertiary = Color(0xFFFFB68C),
    error = Color(0xFFFFB4AB),
)

@Composable
fun OrgPortalTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) {
            OrgPortalDarkColorScheme
        } else {
            OrgPortalColorScheme
        },
        content = content,
    )
}
