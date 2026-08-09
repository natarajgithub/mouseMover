package com.mkflabs.mousemover

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.mkflabs.mousemover.ui.HomeScreen
import com.mkflabs.mousemover.ui.theme.MouseMoverTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MouseMoverTheme {
                HomeScreen()
            }
        }
    }
}
