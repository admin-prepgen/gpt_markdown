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

  // Web, non-fit only: after mermaid renders we measure the diagram's real
  // height and size the widget to it, so a tall flowchart shows in full and the
  // surrounding PAGE scrolls — instead of relying on an inner scroll inside the
  // Flutter platform view (which is unreliable) or clipping the bottom.
  web.HTMLDivElement? _containerEl;
  double? _contentHeight;

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
          mermaid.initialize({
            startOnLoad: false,
            theme: '${widget.theme}',
            securityLevel: 'loose',
            suppressErrorRendering: false,
            // Top-level htmlLabels:false forces native SVG <text> labels. Mermaid
            // v11 IGNORES flowchart.htmlLabels:false and keeps using HTML
            // foreignObject labels, whose width it measures with its own font —
            // when the host app's font (e.g. Poppins) renders wider, the label
            // overflows and is clipped. SVG <text> is measured and drawn as the
            // same element, so it never mismatches or clips.
            htmlLabels: false,
            // Larger, more legible text in the small diagram viewport.
            themeVariables: {
              fontSize: '18px',
              pieTitleTextSize: '24px',
              pieSectionTextSize: '19px',
              pieLegendTextSize: '17px'
            },
            flowchart: {
              useMaxWidth: ${widget.fitContainer ? 'true' : 'false'},
              htmlLabels: false,
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
            // Render ONLY this view's diagram (scope to its id) so concurrent
            // diagrams don't interfere with each other.
            var node = document.querySelector('#mermaid-diagram-$_viewId');
            var runOpts = node ? { nodes: [node] } : undefined;
            mermaid.run(runOpts).then(function() {
              // Safari-safe sizing: cap the SVG to the container but do NOT force
              // width/height:auto or object-fit — on WebKit that collapses an
              // inline SVG inside a flexbox to zero size (the "renders then whites
              // out" bug). Keep mermaid's own width:100% + viewBox aspect ratio.
              var svg = document.querySelector('#mermaid-diagram-$_viewId svg');
              if (svg) {
                svg.style.removeProperty('object-fit');
                // Only fit-mode caps the SVG to the container. In non-fit mode we
                // keep the SVG at its natural size and let the container scroll, so
                // resizing the panel changes the viewport instead of zooming the
                // diagram (which ballooned + clipped the labels).
                ${widget.fitContainer ? "svg.style.maxWidth = '100%'; svg.style.maxHeight = '100%';" : ''}
                svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
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
    _containerEl = container;
    container.id = _viewId!;
    // Non-fit fills the Flutter-provided height (which we grow to the measured
    // diagram height); horizontal scroll only if the diagram is wider than the
    // panel. Fit mode keeps its own 100%/hidden behaviour.
    container.style.width = '100%';
    container.style.height = '100%';
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
      // Measure the rendered diagram and size the widget to it (non-fit).
      if (!widget.fitContainer) {
        _scheduleAutoHeight();
      }
    }).catchError((error) {
      if (kDebugMode) {
        print('Error loading Mermaid: $error');
      }
      container.innerText = 'Error loading Mermaid: $error';
    });

    return container;
  }

  /// Poll the rendered SVG height a few times (mermaid renders asynchronously,
  /// ~100ms after init) and grow the widget to fit, so the whole diagram is
  /// visible and the page scrolls rather than the diagram clipping or depending
  /// on an inner platform-view scroll.
  void _scheduleAutoHeight() {
    if (!kIsWeb) return;
    for (final ms in const [250, 500, 1000, 1800]) {
      Future<void>.delayed(Duration(milliseconds: ms), () {
        if (!mounted || _containerEl == null) return;
        final svg = _containerEl!.querySelector('svg');
        if (svg == null) return;
        final h = svg.getBoundingClientRect().height;
        if (h <= 0) return;
        // add the div's vertical padding so nothing is trimmed
        final target = h + 24;
        if (_contentHeight == null || (_contentHeight! - target).abs() > 2) {
          setState(() => _contentHeight = target);
        }
      });
    }
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
    
    // Build inline styles for the mermaid div.
    // Fit mode: fill + center the container. Non-fit: size to the diagram's
    // natural width (max-content) so the parent container can scroll it, instead
    // of squeezing/zooming it to the container width.
    final mermaidStyles = widget.fitContainer
        ? 'width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; overflow: hidden; padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;'
        : 'display: inline-block; width: max-content; height: auto; padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;';

    return '''
      <style>
        #mermaid-diagram-$_viewId svg {
          ${widget.fitContainer ? 'max-width: 100%; height: auto; max-height: 100%;' : 'height: auto;'}
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
                // Top-level htmlLabels:false => native SVG <text> labels (v11
                // ignores flowchart.htmlLabels:false). Avoids foreignObject label
                // clipping from host-font width mismatch.
                htmlLabels: false,
                // Larger, more legible text in the small diagram viewport.
                themeVariables: {
                    fontSize: '18px',
                    pieTitleTextSize: '24px',
                    pieSectionTextSize: '19px',
                    pieLegendTextSize: '17px'
                },
                flowchart: {
                    useMaxWidth: true,
                    htmlLabels: false,
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
      // Non-fit: prefer an explicit height, else the measured diagram height.
      // Until the first measurement arrives we fall back to a bounded, scrollable
      // starter box so nothing overflows unbounded.
      final double? effectiveHeight =
          widget.fitContainer ? height : (height ?? _contentHeight);
      return Container(
        height: effectiveHeight,
        width: width,
        constraints: effectiveHeight == null && !widget.fitContainer
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