import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A widget that renders Mermaid diagrams using WebView
class MermaidWidget extends StatefulWidget {
  const MermaidWidget({
    super.key,
    required this.mermaidCode,
    this.height,
    this.width,
    this.backgroundColor,
    this.theme = MermaidTheme.default_,
    this.fitContainer = false,
    this.internalPadding,
  });

  final String mermaidCode;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final MermaidTheme theme;
  final bool fitContainer;
  final EdgeInsets? internalPadding;

  @override
  State<MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<MermaidWidget> {
  WebViewController? controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void didUpdateWidget(MermaidWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.fitContainer != widget.fitContainer ||
        oldWidget.internalPadding != widget.internalPadding ||
        oldWidget.theme != widget.theme ||
        oldWidget.mermaidCode != widget.mermaidCode ||
        oldWidget.height != widget.height ||
        oldWidget.width != widget.width ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(_generateHtml());
  }

  String _generateHtml() {
    final themeConfig = _getThemeConfig();
    final backgroundColor = widget.backgroundColor != null 
        ? '${((widget.backgroundColor!.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
          '${((widget.backgroundColor!.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
          '${((widget.backgroundColor!.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
        : 'ffffff';
    
    final containerPaddingTop = widget.internalPadding?.top ?? 16.0;
    final containerPaddingRight = widget.internalPadding?.right ?? 16.0;
    final containerPaddingBottom = widget.internalPadding?.bottom ?? 16.0;
    final containerPaddingLeft = widget.internalPadding?.left ?? 16.0;
    
    final mermaidPaddingTop = widget.internalPadding?.top ?? 16.0;
    final mermaidPaddingRight = widget.internalPadding?.right ?? 0.0;
    final mermaidPaddingBottom = widget.internalPadding?.bottom ?? 16.0;
    final mermaidPaddingLeft = widget.internalPadding?.left ?? 0.0;
    
    final fitContainerPaddingTop = widget.internalPadding?.top ?? 16.0;
    final fitContainerPaddingRight = widget.internalPadding?.right ?? 16.0;
    final fitContainerPaddingBottom = widget.internalPadding?.bottom ?? 16.0;
    final fitContainerPaddingLeft = widget.internalPadding?.left ?? 16.0;
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
            width: 100%;
            height: 100%;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: #$backgroundColor;
        }
        
        .mermaid-container {
            width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: ${containerPaddingTop}px ${containerPaddingRight}px ${containerPaddingBottom}px ${containerPaddingLeft}px;
            box-sizing: border-box;
            overflow: auto;
        }
        
        .mermaid {
            width: auto;
            max-width: 100%;
            height: auto;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: ${mermaidPaddingTop}px ${mermaidPaddingRight}px ${mermaidPaddingBottom}px ${mermaidPaddingLeft}px;
        }
        
        .mermaid.fit-container {
            width: 100%;
            height: 100%;
            max-width: none;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            padding: ${fitContainerPaddingTop}px ${fitContainerPaddingRight}px ${fitContainerPaddingBottom}px ${fitContainerPaddingLeft}px;
        }
        
        .mermaid svg {
            max-width: 100%;
            height: auto;
        }
        
        .mermaid.fit-container svg {
            max-width: 100%;
            max-height: 100%;
            width: auto;
            height: auto;
            object-fit: contain;
        }
        
        .error {
            color: #d32f2f;
            padding: 16px;
            background-color: #ffebee;
            border-radius: 4px;
            border: 1px solid #ffcdd2;
        }
    </style>
</head>
<body>
    <div class="mermaid-container">
        <div class="mermaid${widget.fitContainer ? ' fit-container' : ''}" id="mermaid-diagram">
            ${widget.mermaidCode}
        </div>
    </div>
    
    <script>
        try {
            mermaid.initialize({
                startOnLoad: true,
                theme: '$themeConfig',
                securityLevel: 'loose',
                suppressErrorRendering: false,
                fontFamily: 'inherit',
                flowchart: {
                    useMaxWidth: true,
                    htmlLabels: true,
                    ${widget.fitContainer ? 'useMaxHeight: true,' : ''}
                    curve: 'basis'
                },
                sequence: {
                    useMaxWidth: true,
                    ${widget.fitContainer ? 'useMaxHeight: true,' : ''}
                },
                gantt: {
                    useMaxWidth: true,
                    ${widget.fitContainer ? 'useMaxHeight: true,' : ''}
                },
                pie: {
                    useMaxWidth: true
                },
                xychart: {
                    useMaxWidth: true,
                    ${widget.fitContainer ? 'useMaxHeight: true' : ''}
                }
            });
        } catch (error) {
            console.error('Mermaid initialization error:', error);
            document.body.innerHTML = '<div class="error">Initialization Error: ' + error.message + '</div>';
        }
        
        window.addEventListener('error', function(e) {
            console.error('Window error:', e);
            document.body.innerHTML = '<div class="error">Error rendering diagram: ' + e.message + '</div>';
        });
        
        mermaid.parseError = function(err, hash) {
            console.error('Mermaid parse error:', err);
            document.body.innerHTML = '<div class="error">Mermaid syntax error: ' + err + '</div>';
        };
    </script>
</body>
</html>
    ''';
  }

  String _getThemeConfig() {
    switch (widget.theme) {
      case MermaidTheme.default_:
        return 'default';
      case MermaidTheme.dark:
        return 'dark';
      case MermaidTheme.forest:
        return 'forest';
      case MermaidTheme.neutral:
        return 'neutral';
      case MermaidTheme.base:
        return 'base';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fitContainer) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite 
              ? constraints.maxWidth 
              : (constraints.minWidth > 0 ? constraints.minWidth : 800.0);
          final availableHeight = constraints.maxHeight.isFinite 
              ? constraints.maxHeight 
              : (constraints.minHeight > 0 ? constraints.minHeight : 400.0);
          
          return _buildWidget(
            context,
            width: availableWidth,
            height: availableHeight,
          );
        },
      );
    }
    
    return _buildWidget(
      context,
      width: widget.width,
      height: widget.height,
    );
  }
  
  Widget _buildWidget(BuildContext context, {double? width, double? height}) {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return _buildFallback();
    }
    
    return Container(
      height: height ?? 300,
      width: width,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            if (!_isLoading && _error == null && controller != null)
              WebViewWidget(controller: controller!),
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Mermaid diagram...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            if (_error != null)
              _buildError(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading Mermaid diagram',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            _buildFallbackCode(),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      height: widget.height ?? 300,
      width: widget.width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Mermaid Diagram',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mermaid diagrams require a web environment to render. Here\'s the diagram source:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildFallbackCode()),
        ],
      ),
    );
  }

  Widget _buildFallbackCode() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: SingleChildScrollView(
        child: Text(
          widget.mermaidCode,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

enum MermaidTheme {
  default_,
  dark,
  forest,
  neutral,
  base,
}
