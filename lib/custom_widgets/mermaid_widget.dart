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
  });

  final String mermaidCode;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final MermaidTheme theme;

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
    container.style.width = widget.width != null ? '${widget.width}px' : '100%';
    container.style.height = widget.height != null ? '${widget.height}px' : 'auto';
    container.style.minHeight = widget.height != null ? '${widget.height}px' : '200px';
    container.style.overflow = 'auto';
    container.style.position = 'relative';
    container.style.border = '1px solid #ccc';
    
    if (kDebugMode) {
      print('Created container element with height: ${widget.height ?? "auto"}px, width: ${widget.width ?? "100%"}');
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
      final scriptCode = '''
        setTimeout(function() {
          if (typeof mermaid !== 'undefined') {
            mermaid.initialize({ 
              startOnLoad: false,
              theme: '${widget.theme}',
              securityLevel: 'loose',
              suppressErrorRendering: false
            });
            try {
              mermaid.run().then(function() {
                // Diagram rendered successfully
              }).catch(function(error) {
                var container = document.querySelector('div[style*="position: relative"]');
                if (container) {
                  container.innerHTML = '<div style="color: red; padding: 10px; border: 1px solid red; background: #ffe0e0;">Mermaid Error: ' + error.message + '</div>';
                }
              });
            } catch (e) {
              var container = document.querySelector('div[style*="position: relative"]');
              if (container) {
                container.innerHTML = '<div style="color: red; padding: 10px; border: 1px solid red; background: #ffe0e0;">Mermaid Error: ' + e.message + '</div>';
              }
            }
          } else {
            var container = document.querySelector('div[style*="position: relative"]');
            if (container) {
              container.innerHTML = '<div style="color: red; padding: 10px; border: 1px solid red; background: #ffe0e0;">Mermaid library not loaded</div>';
            }
          }
        }, 100);
      ''';
      
      web.window.callMethod('eval'.toJS, scriptCode.toJS);
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
    
    return '''
      <div id="mermaid-diagram-$_viewId" class="mermaid" style="background-color: ${widget.backgroundColor ?? 'transparent'};">
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
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <style>
        body {
            margin: 0;
            padding: 16px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: #$backgroundColor;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: calc(100vh - 32px);
        }
        
        .mermaid-container {
            width: 100%;
            text-align: center;
        }
        
        .mermaid {
            max-width: 100%;
            height: auto;
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
        <div class="mermaid" id="mermaid-diagram">
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
                    htmlLabels: true
                },
                sequence: {
                    useMaxWidth: true
                },
                gantt: {
                    useMaxWidth: true
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
        
        // Auto-resize content
        function resizeContent() {
            const diagram = document.querySelector('.mermaid svg');
            if (diagram) {
                const rect = diagram.getBoundingClientRect();
                // Send height to Flutter if possible
                console.log('Diagram height:', rect.height);
            }
        }
        
        // Wait for diagram to render then resize
        setTimeout(resizeContent, 1000);
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
    // For web platform, use HtmlElementView with Mermaid.js
    if (kIsWeb) {
      return Container(
        height: widget.height,
        width: widget.width,
        constraints: widget.height == null 
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
      height: widget.height ?? 300,
      width: widget.width,
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