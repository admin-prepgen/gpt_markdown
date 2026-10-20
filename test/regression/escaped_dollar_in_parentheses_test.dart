import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

String _rendered(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .join(' ');

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GptMarkdown(text, useDollarSignsForLatex: true)),
      ),
    );

void main() {
  // An escaped dollar (currency, not maths) inside ordinary parentheses or
  // brackets kept its backslash: the pass that protects LaTeX \( \) and \[ \]
  // also matched plain "( )" and "[ ]", so "(\$5 a week)" showed "\$5".
  testWidgets('currency inside plain parentheses shows no backslash', (tester) async {
    await _pump(tester, r'Each worker was valued (at about \$5 a week) by the planters.');
    await tester.pumpAndSettle();
    final text = _rendered(tester);
    expect(text, contains(r'$5'));
    expect(text, isNot(contains(r'\$')));
  });

  testWidgets('currency inside square brackets shows no backslash', (tester) async {
    await _pump(tester, r'The fee [\$40, paid in advance] cannot be recovered.');
    await tester.pumpAndSettle();
    expect(_rendered(tester), isNot(contains(r'\$')));
  });

  testWidgets('real inline maths is still maths', (tester) async {
    await _pump(tester, r'The multiplier is $\frac{1}{1-0.8}$ here, and a ticket costs \$5.');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_rendered(tester), isNot(contains(r'\$')));
  });
}
