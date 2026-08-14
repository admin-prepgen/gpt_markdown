import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/custom_widgets/custom_error_image.dart';
import 'package:gpt_markdown/custom_widgets/custom_rb_cb.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'dart:math';

import 'custom_widgets/code_field.dart';
import 'custom_widgets/indent_widget.dart';
import 'custom_widgets/link_button.dart';
import 'custom_widgets/mermaid_widget.dart';
import 'custom_widgets/vega_lite_widget.dart';

part 'theme.dart';
part 'markdown_component.dart';
part 'md_widget.dart';

/// This widget create a full markdown widget as a column view.
class GptMarkdown extends StatelessWidget {
  const GptMarkdown(
    this.data, {
    super.key,
    this.style,
    this.followLinkColor = false,
    this.textDirection = TextDirection.ltr,
    this.latexWorkaround,
    this.textAlign,
    this.imageBuilder,
    this.textScaler,
    this.onLinkTap,
    this.latexBuilder,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.maxLines,
    this.overflow,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.tableBuilder,
    this.components,
    this.inlineComponents,
    this.useDollarSignsForLatex = false,
    this.mermaidBuilder,
    this.mermaidDefaultHeight,
    this.mermaidDefaultWidth,
    this.vegaLiteBuilder,
    this.vegaLiteDefaultHeight,
    this.vegaLiteDefaultWidth,
  });

  /// The direction of the text.
  final TextDirection textDirection;

  /// The data to be displayed.
  final String data;

  /// The style of the text.
  final TextStyle? style;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The LaTeX workaround.
  final String Function(String tex)? latexWorkaround;
  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// The LaTeX builder.
  final LatexBuilder? latexBuilder;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The source tag builder.
  final SourceTagBuilder? sourceTagBuilder;

  /// The highlight builder.
  final HighlightBuilder? highlightBuilder;

  /// The link builder.
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The ordered list builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The unordered list builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// Whether to use dollar signs for LaTeX.
  final bool useDollarSignsForLatex;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// The mermaid builder.
  final MermaidBuilder? mermaidBuilder;

  /// Default height for Mermaid diagrams (null = auto-size with constraints)
  final double? mermaidDefaultHeight;

  /// Default width for Mermaid diagrams (null = full width)
  final double? mermaidDefaultWidth;

  /// The vega-lite builder.
  final VegaLiteBuilder? vegaLiteBuilder;

  /// Default height for Vega-Lite charts (null = auto-size with constraints)
  final double? vegaLiteDefaultHeight;

  /// Default width for Vega-Lite charts (null = full width)
  final double? vegaLiteDefaultWidth;

  /// The list of components.
  ///  ```dart
  /// List<MarkdownComponent> components = [
  ///   CodeBlockMd(),
  ///   NewLines(),
  ///   BlockQuote(),
  ///   ImageMd(),
  ///   ATagMd(),
  ///   TableMd(),
  ///   HTag(),
  ///   UnOrderedList(),
  ///   OrderedList(),
  ///   RadioButtonMd(),
  ///   CheckBoxMd(),
  ///   HrLine(),
  ///   StrikeMd(),
  ///   BoldMd(),
  ///   ItalicMd(),
  ///   LatexMath(),
  ///   LatexMathMultiLine(),
  ///   HighlightedText(),
  ///   SourceTag(),
  ///   IndentMd(),
  /// ];
  /// ```
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  ///  ```dart
  /// List<MarkdownComponent> inlineComponents = [
  ///   ImageMd(),
  ///   ATagMd(),
  ///   TableMd(),
  ///   StrikeMd(),
  ///   BoldMd(),
  ///   ItalicMd(),
  ///   LatexMath(),
  ///   LatexMathMultiLine(),
  ///   HighlightedText(),
  ///   SourceTag(),
  /// ];
  /// ```
  final List<MarkdownComponent>? inlineComponents;

  /// A method to remove extra lines inside block LaTeX.
  // String _removeExtraLinesInsideBlockLatex(String text) {
  //   return text.replaceAllMapped(
  //     RegExp(r"\\\[(.*?)\\\]", multiLine: true, dotAll: true),
  //     (match) {
  //       String content = match[0] ?? "";
  //       return content.replaceAllMapped(RegExp(r"\n[\n\ ]+"), (match) => "\n");
  //     },
  //   );
  // }

  /// Preprocesses text to fix common LaTeX formatting issues
  String _preprocessLatexText(String text) {
    String result = text;
    
    // Pattern to match isolated backslash-space-content-space-backslash sequences
    // This matches: \ content \ where content is mathematical notation.
    //
    // Guards so this repair does NOT corrupt real LaTeX environments (e.g.
    // matrices), where `\\` is a row separator and `\begin`/`\end` are commands:
    //   (?<!\\)      opening `\` must not be the 2nd half of a `\\` row separator
    //   (?![a-zA-Z(] closing `\` must not begin a command like `\end`/`\begin`
    // Without these, `... 1 & 1 \\ 12 & 8 \end{bmatrix}` was mis-rewritten to
    // `... 1 & 1 \\(12 & 8\)end{bmatrix}`, breaking the matrix.
    final mainPattern = RegExp(r'(?<!\\)\\ ([^\\]+?) \\(?![a-zA-Z(])');
    
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
      final mathPattern = RegExp(r'[a-zA-Z0-9+\-=^{}_\\\(\)≈~\s]+');
      if (mathPattern.hasMatch(content)) {
        return '\\($content\\)';
      }
      
      return match.group(0) ?? '';
    });
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Upstream normalizes line endings; we then run our LaTeX repair on top.
    String tex = _preprocessLatexText(
      data.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim(),
    );
    if (useDollarSignsForLatex) {
      tex = tex.replaceAllMapped(
        RegExp(r"(?<!\\)\$\$(.*?)(?<!\\)\$\$", dotAll: true),
        (match) => "\\[${match[1] ?? ""}\\]",
      );
      if (!tex.contains(r"\(")) {
        tex = tex.replaceAllMapped(
          RegExp(r"(?<!\\)\$(.*?)(?<!\\)\$"),
          (match) => "\\(${match[1] ?? ""}\\)",
        );
        tex = tex.splitMapJoin(
          RegExp(r"\[.*?\]|\(.*?\)"),
          onNonMatch: (p0) {
            return p0.replaceAll("\\\$", "\$");
          },
        );
      }
    }
    // tex = _removeExtraLinesInsideBlockLatex(tex);
    return ClipRRect(
      child: MdWidget(
        context,
        tex,
        true,
        config: GptMarkdownConfig(
          textDirection: textDirection,
          style: style,
          onLinkTap: onLinkTap,
          textAlign: textAlign,
          textScaler: textScaler,
          followLinkColor: followLinkColor,
          latexWorkaround: latexWorkaround,
          latexBuilder: latexBuilder,
          codeBuilder: codeBuilder,
          maxLines: maxLines,
          overflow: overflow,
          sourceTagBuilder: sourceTagBuilder,
          highlightBuilder: highlightBuilder,
          linkBuilder: linkBuilder,
          imageBuilder: imageBuilder,
          orderedListBuilder: orderedListBuilder,
          unOrderedListBuilder: unOrderedListBuilder,
          components: components,
          inlineComponents: inlineComponents,
          tableBuilder: tableBuilder,
          mermaidBuilder: mermaidBuilder,
          mermaidDefaultHeight: mermaidDefaultHeight,
          mermaidDefaultWidth: mermaidDefaultWidth,
          vegaLiteBuilder: vegaLiteBuilder,
          vegaLiteDefaultHeight: vegaLiteDefaultHeight,
          vegaLiteDefaultWidth: vegaLiteDefaultWidth,
        ),
      ),
    );
  }
}
