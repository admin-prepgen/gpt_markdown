# Mermaid Diagram Sizing Guide

This guide explains the best strategies for controlling Mermaid diagram dimensions in your markdown content, especially for READMEs and documentation.

## Quick Summary

**For most use cases (including READMEs):**
```dart
mermaidBuilder: (context, code, style) {
  return MermaidWidget(
    mermaidCode: code,
    height: 300,  // Fixed height that works well for most diagrams
    width: null,  // Full width - adapts to container
  );
}
```

## Available Sizing Options

### 1. Fixed Dimensions (Precise Control)

Use when you need exact control over diagram size:

```dart
MermaidWidget(
  mermaidCode: code,
  height: 400,  // Fixed 400px height
  width: 800,   // Fixed 800px width
)
```

**Best for:**
- Consistent sizing across all diagrams
- When you know exact dimensions needed
- Documentation with specific layout requirements

### 2. Auto-Height with Constraints (Flexible)

Let the diagram size itself within reasonable bounds:

```dart
MermaidWidget(
  mermaidCode: code,
  height: null,  // Auto-sizes between 200px-600px
  width: null,   // Full width of container
)
```

**Best for:**
- READMEs on GitHub/GitLab
- Diagrams of varying complexity
- Responsive layouts

### 3. Responsive Width, Fixed Height (Recommended)

Adapts to container width while maintaining readable height:

```dart
MermaidWidget(
  mermaidCode: code,
  height: 300,  // Consistent height for all diagrams
  width: null,  // Adapts to available width
)
```

**Best for:**
- Multi-column layouts
- Mobile-responsive documentation
- **This is the default in the example app**

### 4. Global Defaults (Package-Wide)

Set default dimensions for all diagrams at the `GptMarkdown` level:

```dart
GptMarkdown(
  data,
  mermaidDefaultHeight: 350,
  mermaidDefaultWidth: null,  // Full width
  mermaidBuilder: (context, code, style) {
    // These dimensions will be used if not overridden
    return MermaidWidget(mermaidCode: code);
  },
)
```

**Best for:**
- Consistent styling across entire app
- Large documentation sites
- When you want to change all diagrams at once

## README.md Best Practices

### Strategy A: Fixed Height, Full Width (Recommended)

```dart
mermaidBuilder: (context, code, style) {
  return MermaidWidget(
    mermaidCode: code,
    height: 300,  // Tall enough for most diagrams
    width: null,  // Adapts to GitHub's content width
  );
}
```

**Advantages:**
- Consistent height across all diagrams
- Scrollable if content overflows
- Works on both desktop and mobile GitHub

### Strategy B: Auto-Sizing for Variable Content

```dart
mermaidBuilder: (context, code, style) {
  return MermaidWidget(
    mermaidCode: code,
    height: null,  // Auto-size with 200-600px range
  );
}
```

**Advantages:**
- Small diagrams don't waste space
- Large diagrams get more room
- Natural content flow

### Strategy C: Conditional Sizing by Diagram Type

```dart
mermaidBuilder: (context, code, style) {
  // Detect diagram type and adjust size accordingly
  final isFlowchart = code.contains('graph ') || code.contains('flowchart ');
  final isSequence = code.contains('sequenceDiagram');
  final isPie = code.contains('pie ');
  
  return MermaidWidget(
    mermaidCode: code,
    height: isSequence ? 400 : isPie ? 250 : 300,
    width: null,
  );
}
```

**Advantages:**
- Optimized for each diagram type
- Sequence diagrams get more vertical space
- Pie charts don't waste space

## Special Considerations

### Scrolling Behavior

When content exceeds dimensions:
- **Fixed dimensions**: Diagram becomes scrollable
- **Auto-size**: Diagram expands (up to maxHeight constraint)

### Mobile Responsiveness

```dart
mermaidBuilder: (context, code, style) {
  final isSmallScreen = MediaQuery.of(context).size.width < 600;
  
  return MermaidWidget(
    mermaidCode: code,
    height: isSmallScreen ? 250 : 350,
    width: null,  // Always full width on mobile
  );
}
```

### Theme Integration

Don't forget to set the theme for better appearance:

```dart
MermaidWidget(
  mermaidCode: code,
  height: 300,
  theme: Theme.of(context).brightness == Brightness.dark 
      ? MermaidTheme.dark 
      : MermaidTheme.default_,
  backgroundColor: Theme.of(context).colorScheme.surface,
)
```

## Examples in Practice

### GitHub README Example

```dart
GptMarkdown(
  readmeContent,
  mermaidBuilder: (context, code, style) {
    return MermaidWidget(
      mermaidCode: code,
      height: 300,  // Good balance for most diagrams
      width: null,  // GitHub's content area width
      theme: MermaidTheme.default_,
    );
  },
)
```

### Documentation Site Example

```dart
GptMarkdown(
  documentation,
  mermaidDefaultHeight: 400,  // Global default
  mermaidBuilder: (context, code, style) {
    // Can still override per diagram
    return MermaidWidget(
      mermaidCode: code,
      // Uses mermaidDefaultHeight unless specified
    );
  },
)
```

### Blog Post Example

```dart
GptMarkdown(
  blogPost,
  mermaidBuilder: (context, code, style) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: MermaidWidget(
        mermaidCode: code,
        height: null,  // Let each diagram find its natural size
        width: 700,    // Max content width for blog layout
      ),
    );
  },
)
```

## Troubleshooting

### Diagram Cut Off
- **Increase height**: `height: 400` or use `height: null`
- **Check container**: Ensure parent widget isn't constraining size

### Too Much White Space
- **Use auto-sizing**: `height: null`
- **Or reduce fixed height**: `height: 250`

### Horizontal Scrollbar Appears
- **Set width to null**: `width: null`
- **Or reduce fixed width**: `width: 600`

### Diagram Not Centering
- Wrap MermaidWidget in `Center` or `Align` widget
- Or use container with alignment:
  ```dart
  Container(
    alignment: Alignment.center,
    child: MermaidWidget(...),
  )
  ```

## Summary Table

| Use Case | Height | Width | Notes |
|----------|--------|-------|-------|
| README.md | `300` | `null` | Most versatile |
| Documentation | `null` | `null` | Natural sizing |
| Mobile App | `250` | `null` | Compact |
| Desktop App | `400` | `800` | Spacious |
| Blog Post | `null` | `700` | Content-focused |
| Dashboard | `200` | `400` | Space-efficient |

## Default Values

If you don't specify dimensions:
- **height**: Auto-sizes between 200-600px (when `null`)
- **width**: Full width of parent container (when `null`)
- Fixed values take precedence over auto-sizing
