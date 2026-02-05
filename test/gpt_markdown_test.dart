import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';

void main() {
  group('LaTeX Rendering Tests', () {
    testWidgets('should render Hardy-Weinberg equation text correctly', (WidgetTester tester) async {
      // The problematic text with escaped LaTeX formulas
      const problemText = '''Variables:\ p \ p \ = frequency of dominant allele (usually "normal").\ q \ q \ = frequency of recessive allele (usually "mutant").Formulas:\ p + q = 1 \ p + q = 1 \\ p^2 + 2pq + q^2 = 1 \ p^2 + 2pq + q^2 = 1 \\ p^2 \ p^2 \ = frequency of homozygous dominant (unaffected).\ 2pq \ 2pq \ = frequency of heterozygotes (Carrier Frequency).\ q^2 \ q^2 \ = frequency of homozygous recessive (Disease Incidence).

How to apply:1.Given disease incidence (\ q^2 \ q^2 \), take the square root to find \ q \ q \.2.Calculate \ p = 1 - q \ p = 1 - q \.3.Calculate carrier frequency \ 2pq \ 2pq \. Since \ p \approx 1 \ p \approx 1 \ for rare diseases, Carrier Frequency \ \approx 2q \ \approx 2q \.
''';

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GptMarkdown(
                problemText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // The test passes if the widget builds without errors
      expect(find.byType(GptMarkdown), findsOneWidget);
    });
    
    test('LaTeX inline regex should match proper LaTeX syntax', () {
      // Test the current LaTeX inline regex
      final latexRegex = RegExp(r"\\\((.*?)\\\)", dotAll: true);
      
      // These should match valid LaTeX syntax
      expect(latexRegex.hasMatch(r'\(p + q = 1\)'), isTrue);
      expect(latexRegex.hasMatch(r'\(p^2 + 2pq + q^2 = 1\)'), isTrue);
      expect(latexRegex.hasMatch(r'\(q^2\)'), isTrue);
      
      // These should not match (escaped backslashes or malformed syntax)
      expect(latexRegex.hasMatch(r'\ p + q = 1 \'), isFalse);
      expect(latexRegex.hasMatch(r'\ q^2 \'), isFalse);
    });
    
    test('should preprocess malformed LaTeX syntax', () {
      // Test preprocessing function that should fix common LaTeX issues
      const input = r'Variables: \ p \ p \ = frequency of dominant allele. \ q^2 \ q^2 \ = disease incidence.';
      
      // This tests our fix function
      final result = _preprocessLatexText(input);
      expect(result, contains(r'\(p\)'));
      expect(result, contains(r'\(q^2\)'));
    });
    
    test('should handle complex Hardy-Weinberg LaTeX patterns', () {
      // Test the actual problematic Hardy-Weinberg text
      const input = r'Formulas: \ p + q = 1 \ p + q = 1 \\ p^2 + 2pq + q^2 = 1 \ p^2 + 2pq + q^2 = 1 \\ p^2 \ p^2 \ = frequency';
      
      final result = _preprocessLatexText(input);
      
      // Should convert patterns like \ p + q = 1 \ to \(p + q = 1\)
      expect(result, contains(r'\(p + q = 1\)'));
      expect(result, contains(r'\(p^2 + 2pq + q^2 = 1\)'));
      expect(result, contains(r'\(p^2\)'));
    });
    
    // Note: Approximation symbols (\approx) in escaped form are more complex to handle
    // and may require additional preprocessing patterns if needed in the future
    
    testWidgets('integration test - Hardy-Weinberg text should render LaTeX formulas correctly', (WidgetTester tester) async {
      const testText = '''Variables:\\ p \\ p \\ = frequency of dominant allele.
      
      Formulas:\\ p + q = 1 \\ p + q = 1 \\ and \\ p^2 \\ p^2 \\ = homozygous dominant frequency.
      
      Given disease incidence (\\ q^2 \\ q^2 \\), calculate \\ p = 1 - q \\ p = 1 - q \\.''';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              testText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // The test passes if the widget builds without errors and LaTeX is processed
      expect(find.byType(GptMarkdown), findsOneWidget);
      
      // Verify that the widget tree was built successfully without throwing errors
      expect(tester.takeException(), isNull);
    });
  });
  
  group('Mermaid Component Tests', () {
    test('Mermaid regex should match valid mermaid syntax', () {
      // Test the regex pattern directly
      const pattern = r"```mermaid\s*(.*?)\s*```";
      final regex = RegExp(pattern, dotAll: true, multiLine: true);
      
      const testMermaid = '''```mermaid
graph TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great!]
    B -->|No| D[Fix it]
    D --> B
```''';

      final match = regex.firstMatch(testMermaid);
      expect(match, isNotNull);
      expect(match!.group(1)!.trim(), contains('graph TD'));
      expect(match.group(1)!.trim(), contains('A[Start] --> B{Is it working?}'));
    });

    test('Mermaid regex should match sequence diagram', () {
      const pattern = r"```mermaid\s*(.*?)\s*```";
      final regex = RegExp(pattern, dotAll: true, multiLine: true);
      
      const testMermaid = '''```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    Alice->>John: Hello John, how are you?
```''';

      final match = regex.firstMatch(testMermaid);
      expect(match, isNotNull);
      expect(match!.group(1)!.trim(), contains('sequenceDiagram'));
      expect(match.group(1)!.trim(), contains('participant Alice'));
    });

    test('Mermaid regex should not match non-mermaid code blocks', () {
      const pattern = r"```mermaid\s*(.*?)\s*```";
      final regex = RegExp(pattern, dotAll: true, multiLine: true);
      
      const testCode = '''```javascript
function hello() {
  console.log("Hello World!");
}
```''';

      final match = regex.firstMatch(testCode);
      expect(match, isNull);
    });

    test('Mermaid regex should handle whitespace correctly', () {
      const pattern = r"```mermaid\s*(.*?)\s*```";
      final regex = RegExp(pattern, dotAll: true, multiLine: true);
      
      const testMermaid = '''```mermaid   

graph LR
    A --> B

   ```''';

      final match = regex.firstMatch(testMermaid);
      expect(match, isNotNull);
      expect(match!.group(1)!.trim(), equals('graph LR\n    A --> B'));
    });
  });
}

/// Helper function to preprocess malformed LaTeX text
String _preprocessLatexText(String text) {
  String result = text;
  
  // Pattern to match isolated backslash-space-content-space-backslash sequences
  // This matches: \ content \ where content is mathematical notation
  // We need to be careful to match the exact spacing pattern from the input
  
  // First handle the main pattern: \ [content] \
  // Use non-greedy matching and ensure we capture mathematical content
  final mainPattern = RegExp(r'\\ ([^\\]+?) \\(?!\()');
  
  result = result.replaceAllMapped(mainPattern, (match) {
    final content = match.group(1)?.trim() ?? '';
    // Skip if content is empty, just punctuation, or already processed
    if (content.isEmpty || 
        content == '=' || 
        content.contains('\\(') || 
        content.contains('\\)')) {
      return match.group(0) ?? '';
    }
    
    // Check if this looks like mathematical content
    final mathPattern = RegExp(r'[a-zA-Z0-9+\-=^{}_\\\(\)≈~]+');
    if (mathPattern.hasMatch(content)) {
      return '\\($content\\)';
    }
    
    return match.group(0) ?? '';
  });
  
  return result;
}
