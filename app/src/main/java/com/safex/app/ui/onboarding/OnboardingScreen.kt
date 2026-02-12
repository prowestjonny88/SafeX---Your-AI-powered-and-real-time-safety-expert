package com.safex.app.ui.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun OnboardingScreen(
    initialLanguage: String,
    initialMode: String,
    onDone: (languageTag: String, mode: String) -> Unit
) {
    var lang by remember { mutableStateOf(if (initialLanguage.isBlank()) "en" else initialLanguage) }
    var mode by remember { mutableStateOf(if (initialMode.isBlank()) "guardian" else initialMode) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Welcome to SafeX", style = MaterialTheme.typography.headlineMedium)

        Text("Choose language:")
        LanguageChoiceRow(selected = lang, onSelect = { lang = it })

        Divider()

        Text("Choose mode:")
        ModeChoiceRow(selected = mode, onSelect = { mode = it })

        Spacer(Modifier.weight(1f))

        Button(
            onClick = { onDone(lang, mode) },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Continue")
        }
    }
}

@Composable
private fun LanguageChoiceRow(selected: String, onSelect: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        FilterChip(
            selected = selected == "en",
            onClick = { onSelect("en") },
            label = { Text("EN") }
        )
        FilterChip(
            selected = selected == "ms",
            onClick = { onSelect("ms") },
            label = { Text("MS") }
        )
        FilterChip(
            selected = selected == "zh",
            onClick = { onSelect("zh") },
            label = { Text("ZH") }
        )
    }
}

@Composable
private fun ModeChoiceRow(selected: String, onSelect: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        FilterChip(
            selected = selected == "guardian",
            onClick = { onSelect("guardian") },
            label = { Text("Guardian") }
        )
        FilterChip(
            selected = selected == "companion",
            onClick = { onSelect("companion") },
            label = { Text("Companion") }
        )
    }
}