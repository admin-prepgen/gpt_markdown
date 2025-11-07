import 'dart:io';
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Web-specific imports with conditional compilation
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

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
  
  /// If true, the widget will automatically fit to its parent container's size.
  /// This takes precedence over explicit width/height parameters.
  /// Works with LayoutBuilder to determine available space.
  final bool fitContainer;
  
  /// Custom padding around the diagram content.
  /// Defaults to EdgeInsets.all(16.0) if not specified.
  final EdgeInsets? internalPadding;

  @override
  State<MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<MermaidWidget> {
  WebViewController? controller;
  bool _isLoading = true;
  String? _error;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebView();
    } else {
      _initializeWebView();
    }
  }

  @override
  void didUpdateWidget(MermaidWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If fitContainer or other rendering params changed, rebuild
    if (oldWidget.fitContainer != widget.fitContainer ||
        oldWidget.internalPadding != widget.internalPadding ||
        oldWidget.theme != widget.theme ||
        oldWidget.mermaidCode != widget.mermaidCode ||
        oldWidget.height != widget.height ||
        oldWidget.width != widget.width ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      
      if (kIsWeb && _viewId != null) {
        // For web, update the existing container element
        _updateWebElement();
      } else {
        // For mobile, reload the WebView
        setState(() {
          _isLoading = true;
          _error = null;
        });
        _initializeWebView();
      }
    }
  }

  void _updateWebElement() {
    if (!kIsWeb || _viewId == null) return;
    
    // Find the existing container and update its CSS
    final container = web.document.querySelector('#$_viewId') as web.HTMLDivElement?;
    if (container != null) {
      // Update overflow style based on fitContainer
      container.style.overflow = widget.fitContainer ? 'hidden' : 'auto';
      
      // Re-render the diagram
      _ensureMermaidLoaded().then((_) {
        final html = _generateWebHtml();
        container.innerHTML = html.toJS;
        
        // Re-initialize mermaid with new config
        _initializeMermaidDiagram();
      });
    }
  }

  void _initializeMermaidDiagram() {
    final scriptCode = '''
      setTimeout(function() {
        if (typeof mermaid !== 'undefined') {
          // Clear previous diagrams
          mermaid.contentLoaded();
          
          mermaid.initialize({ 
            startOnLoad: false,
            theme: '${widget.theme}',
            securityLevel: 'loose',
            suppressErrorRendering: false,
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
          try {
            mermaid.run().then(function() {
              // Optimize SVG sizing after render
              var svg = document.querySelector('[id*="mermaid-diagram"] svg');
              if (svg) {
                if (${widget.fitContainer.toString()}) {
                  svg.style.maxWidth = '100%';
                  svg.style.maxHeight = '100%';
                  svg.style.width = 'auto';
                  svg.style.height = 'auto';
                  svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
                }
              }
            }).catch(function(error) {
              console.error('Mermaid render error:', error);
            });
          } catch (e) {
            console.error('Mermaid error:', e);
          }
        }
      }, 100);
    ''';
    
    web.window.callMethod('eval'.toJS, scriptCode.toJS);
  }

  void _registerWebView() {
    if (!kIsWeb) return;
    
    _viewId = 'mermaid-${DateTime.now().millisecondsSinceEpoch}';
    
    if (kDebugMode) {
      print('Registering Mermaid view with ID: $_viewId');
    }
    
    // Register the view factory for web
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId!,
      (int viewId) {
        if (kDebugMode) {
          print('Creating HTML element for view ID: $viewId');
        }
        return _createHtmlElement();
      },
    );
  }

  web.HTMLDivElement _createHtmlElement() {
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.id = _viewId!;
    container.style.width = widget.fitContainer ? '100%' : (widget.width != null ? '${widget.width}px' : '100%');
    container.style.height = widget.fitContainer ? '100%' : (widget.height != null ? '${widget.height}px' : 'auto');
    container.style.minHeight = widget.fitContainer ? '100%' : (widget.height != null ? '${widget.height}px' : '200px');
    container.style.overflow = widget.fitContainer ? 'hidden' : 'auto';
    container.style.position = 'relative';
    container.style.border = '1px solid #ccc';
    
    if (kDebugMode) {
      print('Created container element with height: ${widget.fitContainer ? "100%" : (widget.height ?? "auto")}px, width: ${widget.fitContainer ? "100%" : (widget.width ?? "100%")}');
      print('Mermaid code length: ${widget.mermaidCode.length}');
      print('Mermaid code preview: ${widget.mermaidCode.substring(0, widget.mermaidCode.length > 50 ? 50 : widget.mermaidCode.length)}...');
    }
    
    // Load Mermaid.js and render the diagram
    _ensureMermaidLoaded().then((_) {
      if (kDebugMode) {
        print('Mermaid loaded, generating HTML...');
      }
      final html = _generateWebHtml();
      container.innerHTML = html.toJS;
      
      if (kDebugMode) {
        print('HTML set, executing JavaScript...');
      }
      
      // Run initialization script
      _initializeMermaidDiagram();
    }).catchError((error) {
      if (kDebugMode) {
        print('Error loading Mermaid: $error');
      }
      container.innerText = 'Error loading Mermaid: $error';
    });
    
    return container;
  }

  Future<void> _ensureMermaidLoaded() async {
    if (!kIsWeb) return;

    // Check if Mermaid is already loaded using eval
    try {
      final result = web.window.callMethod('eval'.toJS, 'typeof mermaid'.toJS);
      if (result.toString() != 'undefined') {
        return;
      }
    } catch (e) {
      // Continue to load if check fails
    }

    // Load Mermaid.js from CDN
    final script = web.HTMLScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'
      ..type = 'text/javascript';

    // Wait for script to load
    final completer = Completer<void>();
    
    script.addEventListener('load', (web.Event event) {
      completer.complete();
    }.toJS);
    
    script.addEventListener('error', (web.Event event) {
      completer.completeError('Failed to load Mermaid.js');
    }.toJS);

    web.document.head?.appendChild(script);
    
    await completer.future;
  }

    String _generateWebHtml() {
    // Don't escape the code - Mermaid needs raw syntax
    if (kDebugMode) {
      print('Raw mermaid code: ${widget.mermaidCode}');
    }
    
    // Calculate padding values
    final paddingTop = widget.internalPadding?.top ?? 16.0;
    final paddingBottom = widget.internalPadding?.bottom ?? 16.0;
    final paddingLeft = widget.internalPadding?.left ?? (widget.fitContainer ? 16.0 : 0.0);
    final paddingRight = widget.internalPadding?.right ?? (widget.fitContainer ? 16.0 : 0.0);
    
    // Build inline styles for the mermaid div
    final mermaidStyles = widget.fitContainer
        ? 'width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; overflow: hidden; padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;'
        : 'width: auto; max-width: 100%; height: auto; display: flex; align-items: center; justify-content: center; padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;';
    
    return '''
      <style>
        .mermaid svg {
          max-width: 100%;
          ${widget.fitContainer ? 'max-height: 100%; width: auto; height: auto; object-fit: contain;' : 'height: auto;'}
        }
      </style>
      <div id="mermaid-diagram-$_viewId" class="mermaid" style="background-color: ${widget.backgroundColor ?? 'transparent'}; $mermaidStyles">
${widget.mermaidCode}
      </div>
    ''';
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
    
    // Calculate padding values
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
        
        /* Default behavior: natural sizing */
        .mermaid {
            width: auto;
            max-width: 100%;
            height: auto;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: ${mermaidPaddingTop}px ${mermaidPaddingRight}px ${mermaidPaddingBottom}px ${mermaidPaddingLeft}px;
        }
        
        /* Fit container mode: constrained sizing */
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
        
        // Handle rendering errors
        window.addEventListener('error', function(e) {
            console.error('Window error:', e);
            document.body.innerHTML = '<div class="error">Error rendering diagram: ' + e.message + '</div>';
        });
        
        // Mermaid error handling
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
    // If fitContainer is true, wrap in LayoutBuilder to get parent constraints
    if (widget.fitContainer) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Use finite constraints, fallback to reasonable defaults
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
    
    // Standard mode - use explicit dimensions
    return _buildWidget(
      context,
      width: widget.width,
      height: widget.height,
    );
  }
  
  Widget _buildWidget(BuildContext context, {double? width, double? height}) {
    // For web platform, use HtmlElementView with Mermaid.js
    if (kIsWeb) {
      return Container(
        height: height,
        width: width,
        constraints: height == null && !widget.fitContainer
            ? const BoxConstraints(minHeight: 200, maxHeight: 600)
            : null,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _viewId != null
              ? HtmlElementView(viewType: _viewId!)
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    // For platforms that don't support WebView, show a fallback
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return _buildFallback();
    }
    
    // For mobile platforms, use WebView
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