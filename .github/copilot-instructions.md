# GPT Markdown - AI Coding Instructions

## Project Overview

This is a Flutter package that renders rich Markdown and LaTeX content, specifically designed for AI outputs like ChatGPT and Gemini. It's a drop-in replacement for `flutter_markdown` with extended LaTeX support and customization capabilities.

## Architecture Overview

### Component-Based Design
The package uses a **component-based architecture** where each Markdown element is implemented as a separate `MarkdownComponent`:

- **Block Components** (`BlockMd`): Handle block-level elements (headers, lists, tables, code blocks)
- **Inline Components** (`InlineMd`): Handle inline elements (bold, italic, links, inline math)
- **Two-Phase Processing**: Global components process first, then inline components handle remaining text

Key files: `lib/markdown_component.dart` contains all component definitions in a single part file.

### Configuration System
The `GptMarkdownConfig` class centralizes all customization options:
- Style overrides via builder functions (e.g., `latexBuilder`, `codeBuilder`, `linkBuilder`)  
- Theme integration through `GptMarkdownTheme` (extends Flutter's `ThemeExtension`)
- Text direction, alignment, and overflow handling

### LaTeX Integration
Uses `flutter_math_fork` for LaTeX rendering with multiple syntax support:
- Standard LaTeX: `\(...\)` for inline, `\[...\]` for display
- Dollar signs: `$...$` and `$$...$$` (when `useDollarSignsForLatex: true`)
- Custom LaTeX workarounds via `latexWorkaround` function

### Mermaid Integration
Supports Mermaid diagrams using WebView for interactive rendering:
- Standard Mermaid syntax: ````mermaid ... ``` blocks
- Cross-platform support with fallback rendering on unsupported platforms
- Configurable themes (default, dark, forest, neutral, base)
- Custom mermaidBuilder for advanced customization

## Development Patterns

### Adding New Components
1. Extend either `BlockMd` or `InlineMd` in `lib/markdown_component.dart`
2. Implement `RegExp get exp` with your pattern
3. Implement `span()` method for rendering
4. Add to `globalComponents` or `inlineComponents` lists

Example pattern from `BoldMd`:
```dart
class BoldMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?<!\*)\*\*(?<!\s)(.+?)(?<!\s)\*\*(?!\*)");
  
  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    // Implementation handles nested markdown processing
  }
}
```

### Custom Builder Functions
All visual customization happens through typed builder functions in `GptMarkdownConfig`:
- `CodeBlockBuilder` for syntax highlighting
- `LatexBuilder` for math rendering customization  
- `MermaidBuilder` for diagram rendering (WebView-based or custom)
- `TableBuilder` for table layout control
- `LinkBuilder`, `ImageBuilder`, `HighlightBuilder` for other elements

### Theme Customization
Use `GptMarkdownTheme` widget or add `GptMarkdownThemeData` to app theme extensions:
```dart
extensions: [
  GptMarkdownThemeData(
    brightness: Brightness.dark,
    highlightColor: Colors.purple,
  ),
]
```

## Testing & Examples

### Example App Structure  
The `example/` directory demonstrates:
- Theme switching (light/dark mode)
- Custom builder implementations
- File watching for live preview
- Complex nested markdown structures
- RTL/LTR text direction support

### Testing Approach
- Main test file: `test/gpt_markdown_test.dart` (currently minimal)
- Live testing via example app with comprehensive markdown samples
- Component regex testing should be added for each `MarkdownComponent`

## Key Constraints & Gotchas

### Regex Processing Order
Component order in `globalComponents`/`inlineComponents` lists matters - first match wins. Place more specific patterns before general ones.

### Part File Architecture
All components are in `lib/markdown_component.dart` as a `part` of `lib/gpt_markdown.dart`. This keeps related functionality together but requires careful organization.

### LaTeX Error Handling
Always provide `onErrorFallback` in LaTeX builders - malformed LaTeX should gracefully degrade to text rendering.

### SelectionArea Integration
Use `SelectableAdapter` wrapper for custom widgets to maintain text selection capability when parent uses `SelectionArea`.

## Flutter Package Conventions

- Follows standard pubspec.yaml structure for Flutter packages
- Uses `lib/` for source code with clear public API in `gpt_markdown.dart`
- Custom widgets are organized in `lib/custom_widgets/`
- Font assets embedded in `lib/fonts/` for code blocks (JetBrains Mono)
- Example app demonstrates all features and serves as integration test

This codebase prioritizes extensibility through the builder pattern while maintaining performance through efficient regex-based parsing.