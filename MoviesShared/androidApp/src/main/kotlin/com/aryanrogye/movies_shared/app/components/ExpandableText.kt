package com.aryanrogye.movies_shared.app.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun ExpandableText(
    text: String,
    modifier: Modifier = Modifier,
    collapsedLines: Int = 2,
    tintColor: Color = Color(0xFFFFD54F),
) {
    var expanded by remember(text) { mutableStateOf(false) }
    var truncated by remember(text) { mutableStateOf(false) }

    Column(modifier) {
        Text(
            text = text,
            maxLines = if (expanded) Int.MAX_VALUE else collapsedLines,
            overflow = TextOverflow.Ellipsis,
            color = Color.White.copy(alpha = .72f),
            lineHeight = 20.sp,
            onTextLayout = { result ->
                if (!expanded) truncated = result.hasVisualOverflow
            },
        )

        if (truncated) {
            var focused by remember { mutableStateOf(false) }
            val background by animateColorAsState(
                if (focused) tintColor else Color.White.copy(alpha = .07f),
                label = "expandable text action",
            )
            Surface(
                modifier = Modifier
                    .padding(top = 6.dp)
                    .onFocusChanged { focused = it.isFocused }
                    .clickable { expanded = !expanded },
                color = background,
                contentColor = if (focused) Color.Black else tintColor,
                shape = RoundedCornerShape(50),
            ) {
                Text(
                    if (expanded) "Show less" else "More",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 9.dp),
                )
            }
        }
    }
}
