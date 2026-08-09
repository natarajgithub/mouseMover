package com.mkflabs.mousemover.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Green = Color(0xFF1B5E20)
private val Scheme =
    lightColorScheme(
        primary = Green,
        secondary = Color(0xFF2E7D32),
        tertiary = Color(0xFF00838F),
    )

@Composable
fun MouseMoverTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Scheme, content = content)
}
