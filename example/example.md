# example
``` dart
import 'package:flutter/material.dart';
import 'package:tex_markdown/tex_markdown.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return GptMarkdown(
                        _controller.text,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      );
                    }),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TextField(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              maxLines: null,
              controller: _controller,
            ),
          ),
        ],
      ),
    );
  }
}

```

Use `SelectableAdapter` to make any non selectable widget selectable.

```dart
SelectableAdapter(
  selectedText: 'sin(x^2)',
  child: Math.tex('sin(x^2)'),
);
```

Use `GptMarkdownTheme` widget and `GptMarkdownThemeData` to customize the GptMarkdown.

```dart
GptMarkdownTheme(
  data: GptMarkdownThemeData.of(context).copyWith(
    highlightColor: Colors.red,
  ),
  child: GptMarkdown(
    text,
  ),
);
```

In theme extension you can use `GptMarkdownThemeData` to customize the GptMarkdown.

```dart
theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorSchemeSeed: Colors.blue,
  extensions: [
    GptMarkdownThemeData(
      brightness: Brightness.light,
      highlightColor: Colors.red,
    ),
  ],
),
darkTheme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.blue,
  extensions: [
    GptMarkdownThemeData(
      brightness: Brightness.dark,
      highlightColor: Colors.red,
    ),
  ],
),
```

Use `tableBuilder` to customize table rendering:

```dart
GptMarkdown(
  markdownText,
  tableBuilder: (context, tableRows, textStyle, config) {
    return Table(
      border: TableBorder.all(
        width: 1,
        color: Colors.red,
      ),
      children: tableRows.map((e) {
        return TableRow(
          children: e.fields.map((e) {
            return Text(e.data);
          }).toList(),
        );
      }).toList(),
    );
  },
);
```

Please see the [README.md](https://github.com/Infinitix-LLC/gpt_markdown) and also [example](https://github.com/Infinitix-LLC/gpt_markdown/tree/main/example/lib/main.dart) app for more details.

## Vega-Lite Charts

You can embed interactive Vega-Lite charts using the ```vega-lite syntax:

### Bar Chart (50% width)
```vega-lite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "A simple bar chart with embedded data.",
  "data": {
    "values": [
      {"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43},
      {"a": "D", "b": 91}, {"a": "E", "b": 81}, {"a": "F", "b": 53},
      {"a": "G", "b": 19}, {"a": "H", "b": 87}
    ]
  },
  "mark": "bar",
  "encoding": {
    "x": {"field": "a", "type": "nominal", "axis": {"labelAngle": 0}},
    "y": {"field": "b", "type": "quantitative"}
  }
}
```

### Line Chart (80% width)
```vega-lite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "A simple line chart showing trends.",
  "data": {
    "values": [
      {"x": 1, "y": 28}, {"x": 2, "y": 55}, {"x": 3, "y": 43},
      {"x": 4, "y": 91}, {"x": 5, "y": 81}, {"x": 6, "y": 53},
      {"x": 7, "y": 19}, {"x": 8, "y": 87}, {"x": 9, "y": 72}
    ]
  },
  "mark": "line",
  "encoding": {
    "x": {"field": "x", "type": "quantitative"},
    "y": {"field": "y", "type": "quantitative"}
  }
}
```

### Scatter Plot (400px fixed width)
```vega-lite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "A scatter plot showing correlation.",
  "data": {
    "values": [
      {"x": 1, "y": 28}, {"x": 2, "y": 55}, {"x": 3, "y": 43},
      {"x": 4, "y": 91}, {"x": 5, "y": 81}, {"x": 6, "y": 53},
      {"x": 7, "y": 19}, {"x": 8, "y": 87}, {"x": 9, "y": 72}
    ]
  },
  "mark": "circle",
  "encoding": {
    "x": {"field": "x", "type": "quantitative"},
    "y": {"field": "y", "type": "quantitative"}
  }
}
```

### Area Chart (100% width with 800px max)
```vega-lite
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "An area chart showing filled trends.",
  "data": {
    "values": [
      {"x": 1, "y": 28}, {"x": 2, "y": 55}, {"x": 3, "y": 43},
      {"x": 4, "y": 91}, {"x": 5, "y": 81}, {"x": 6, "y": 53},
      {"x": 7, "y": 19}, {"x": 8, "y": 87}, {"x": 9, "y": 72}
    ]
  },
  "mark": "area",
  "encoding": {
    "x": {"field": "x", "type": "quantitative"},
    "y": {"field": "y", "type": "quantitative"}
  }
}
```

````

