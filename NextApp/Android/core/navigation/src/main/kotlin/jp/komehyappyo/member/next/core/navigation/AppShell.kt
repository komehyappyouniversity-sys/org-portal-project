package jp.komehyappyo.member.next.core.navigation

import android.content.res.Configuration
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Build

enum class AppTab(val label: String, val icon: ImageVector) {
    Home("ホーム", Icons.Outlined.Home),
    Tools("便利", Icons.Outlined.Build),
    Connect("つながる", Icons.Outlined.Link),
    MyPage("マイページ", Icons.Outlined.Person),
}

@Composable
fun AppShell(
    home: @Composable () -> Unit,
    tools: @Composable () -> Unit,
    connect: @Composable () -> Unit,
    myPage: @Composable () -> Unit,
) {
    val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
    var selected by rememberSaveable { mutableStateOf(AppTab.Home) }
    Scaffold(
        bottomBar = {
            if (!isLandscape) {
                NavigationBar {
                    AppTab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = selected == tab,
                            onClick = { selected = tab },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                        )
                    }
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (selected) {
                AppTab.Home -> home()
                AppTab.Tools -> tools()
                AppTab.Connect -> connect()
                AppTab.MyPage -> myPage()
            }
        }
    }
}
