import 'package:flutter_test/flutter_test.dart';

void main() {
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
