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

/// A widget that renders Vega-Lite specifications using vega-embed
class VegaLiteWidget extends StatefulWidget {
  const VegaLiteWidget({
    super.key,
    required this.vegaSpec,
    this.height,
    this.width,
    this.backgroundColor,
    this.fitToHeight = false,
  });

  final String vegaSpec;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final bool fitToHeight;

  @override
  State<VegaLiteWidget> createState() => _VegaLiteWidgetState();
}

class _VegaLiteWidgetState extends State<VegaLiteWidget> {
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
  void didUpdateWidget(VegaLiteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If fitToHeight or other rendering params changed, rebuild
    if (oldWidget.fitToHeight != widget.fitToHeight ||
        oldWidget.vegaSpec != widget.vegaSpec ||
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
      // Update overflow style based on fitToHeight
      container.style.overflow = widget.fitToHeight ? 'hidden' : 'auto';
      
      // Re-render the chart
      _ensureVegaLoaded().then((_) {
        final html = _generateWebHtml();
        container.innerHTML = html.toJS;
        
        // Re-initialize vega with new config
        _initializeVegaChart();
      });
    }
  }

  void _registerWebView() {
    if (!kIsWeb) return;
    
    _viewId = 'vega-${DateTime.now().millisecondsSinceEpoch}';
    
    if (kDebugMode) {
      print('Registering Vega-Lite view with ID: $_viewId');
    }
    
    // Register the view factory for web
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId!,
      (int viewId) {
        if (kDebugMode) {
          print('Creating Vega-Lite HTML element for view ID: $viewId');
        }
        return _createHtmlElement();
      },
    );
  }

  web.HTMLDivElement _createHtmlElement() {
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.id = _viewId!;
    container.style.width = widget.width != null ? '${widget.width}px' : '100%';
    container.style.height = widget.height != null ? '${widget.height}px' : 'auto';
    container.style.minHeight = widget.height != null ? '${widget.height}px' : '200px';
    container.style.overflow = widget.fitToHeight ? 'hidden' : 'auto';
    container.style.position = 'relative';
    container.style.border = '1px solid #ccc';
    
    if (kDebugMode) {
      print('Created Vega-Lite container element with height: ${widget.height ?? "auto"}px, width: ${widget.width ?? "100%"}');
      print('Vega spec length: ${widget.vegaSpec.length}');
      print('Vega spec preview: ${widget.vegaSpec.substring(0, widget.vegaSpec.length > 50 ? 50 : widget.vegaSpec.length)}...');
    }
    
    // Load Vega.js and render the chart
    _ensureVegaLoaded().then((_) {
      if (kDebugMode) {
        print('Vega-Lite loaded, generating HTML...');
      }
      final html = _generateWebHtml();
      container.innerHTML = html.toJS;
      
      if (kDebugMode) {
        print('HTML set, executing JavaScript...');
      }
      
      // Run initialization script
      _initializeVegaChart();
    }).catchError((error) {
      if (kDebugMode) {
        print('Error loading Vega-Lite: $error');
      }
      container.innerText = 'Error loading Vega-Lite: $error';
    });
    
    return container;
  }

  void _initializeVegaChart() {
    final scriptCode = '''
      setTimeout(function() {
        if (typeof vegaEmbed !== 'undefined') {
          try {
            var spec = ${widget.vegaSpec};
            var opts = {
              actions: {
                export: false,
                source: false,
                editor: false
              },
              hover: true
              ${widget.fitToHeight ? ',downloadFileName: "chart.svg"' : ''}
            };
            vegaEmbed('#vega-container-$_viewId', spec, opts).catch(console.error);
          } catch (e) {
            console.error('Vega-Lite error:', e);
            document.body.innerHTML = '<div style="color: red; padding: 10px; border: 1px solid red; background: #ffe0e0;">Vega Error: ' + e.message + '</div>';
          }
        } else {
          console.error('vegaEmbed not loaded');
        }
      }, 100);
    ''';
    
    web.window.callMethod('eval'.toJS, scriptCode.toJS);
  }

  Future<void> _ensureVegaLoaded() async {
    if (!kIsWeb) return;

    // Check if Vega is already loaded
    try {
      final result = web.window.callMethod('eval'.toJS, 'typeof vegaEmbed'.toJS);
      if (result.toString() != 'undefined') {
        return;
      }
    } catch (e) {
      // Continue to load if check fails
    }

    // Load Vega, Vega-Lite, and vega-embed from CDN
    final scripts = [
      'https://cdn.jsdelivr.net/npm/vega@5.28.0/build/vega.min.js',
      'https://cdn.jsdelivr.net/npm/vega-lite@5.18.0/build/vega-lite.min.js',
      'https://cdn.jsdelivr.net/npm/vega-embed@6.26.0/build/vega-embed.min.js',
    ];

    for (final scriptUrl in scripts) {
      await _loadScript(scriptUrl);
    }
  }

  Future<void> _loadScript(String url) async {
    final completer = Completer<void>();
    
    final script = web.HTMLScriptElement()
      ..src = url
      ..type = 'text/javascript';

    script.addEventListener('load', (web.Event event) {
      completer.complete();
    }.toJS);
    
    script.addEventListener('error', (web.Event event) {
      completer.completeError('Failed to load script: $url');
    }.toJS);

    web.document.head?.appendChild(script);
    
    await completer.future;
  }

  String _generateWebHtml() {
    if (kDebugMode) {
      print('Raw vega spec: ${widget.vegaSpec}');
    }
    
    // Build inline styles for the vega container
    final vegaStyles = widget.fitToHeight
        ? 'width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; overflow: hidden; padding: 16px 0;'
        : 'width: 100%; max-width: 100%; height: auto; display: flex; align-items: center; justify-content: center; padding: 16px 0;';
    
    return '''
      <div id="vega-container-$_viewId" class="vega" style="background-color: ${widget.backgroundColor ?? 'transparent'}; $vegaStyles">
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
    <script src="https://cdn.jsdelivr.net/npm/vega@5.28.0/build/vega.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/vega-lite@5.18.0/build/vega-lite.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/vega-embed@6.26.0/build/vega-embed.min.js"></script>
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
        
        .vega-container {
            width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 16px;
            box-sizing: border-box;
            overflow: auto;
        }
        
        /* Default behavior: natural sizing */
        .vega {
            width: 100%;
            max-width: 100%;
            height: auto;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 16px 0;
        }
        
        /* Fit to height mode: constrained sizing */
        .vega.fit-to-height {
            width: 100%;
            height: calc(100% - 32px);
            max-width: none;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            padding: 16px 0;
        }
        
        .vega svg {
            max-width: 100%;
            height: auto;
        }
        
        .vega.fit-to-height svg {
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
    <div class="vega-container">
        <div class="vega${widget.fitToHeight ? ' fit-to-height' : ''}" id="vega-chart">
        </div>
    </div>
    
    <script>
        try {
            var spec = ${widget.vegaSpec};
            var opts = {
              actions: {
                export: false,
                source: false,
                editor: false
              },
              hover: true
            };
            vegaEmbed('#vega-chart', spec, opts).catch(console.error);
        } catch (error) {
            console.error('Vega-Lite initialization error:', error);
            document.body.innerHTML = '<div class="error">Initialization Error: ' + error.message + '</div>';
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    // For web platform, use HtmlElementView with vega-embed
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
      height: widget.height ?? 400,
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
                      'Loading Vega-Lite chart...',
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
              'Error loading Vega-Lite chart',
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
      height: widget.height ?? 400,
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
                Icons.bar_chart,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Vega-Lite Chart',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vega-Lite charts require a web environment to render. Here\'s the chart specification:',
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
          widget.vegaSpec,
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
