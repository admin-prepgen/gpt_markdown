import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A widget that renders Vega-Lite specifications using vega-embed
class VegaLiteWidget extends StatefulWidget {
  const VegaLiteWidget({
    super.key,
    required this.vegaSpec,
    this.cssWidth,
    this.maxWidth,
    this.maxHeight,
    this.backgroundColor,
    this.constrainHeight = false,
    this.internalPadding,
  });

  final String vegaSpec;
  final String? cssWidth;
  final double? maxWidth;
  final double? maxHeight;
  final Color? backgroundColor;
  final bool constrainHeight;
  final EdgeInsets? internalPadding;

  @override
  State<VegaLiteWidget> createState() => _VegaLiteWidgetState();
}

class _VegaLiteWidgetState extends State<VegaLiteWidget> {
  WebViewController? controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void didUpdateWidget(VegaLiteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.vegaSpec != widget.vegaSpec ||
        oldWidget.cssWidth != widget.cssWidth ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.maxHeight != widget.maxHeight ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.constrainHeight != widget.constrainHeight ||
        oldWidget.internalPadding != widget.internalPadding) {
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
    final backgroundColor = widget.backgroundColor != null 
        ? '${((widget.backgroundColor!.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
          '${((widget.backgroundColor!.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
          '${((widget.backgroundColor!.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
        : 'ffffff';
    
    final paddingTop = widget.internalPadding?.top ?? 16.0;
    final paddingRight = widget.internalPadding?.right ?? 16.0;
    final paddingBottom = widget.internalPadding?.bottom ?? 16.0;
    final paddingLeft = widget.internalPadding?.left ?? 16.0;
    
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
            ${widget.constrainHeight ? 'height: 100vh;' : ''}
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: #$backgroundColor;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;
        }
        
        #vis {
            width: ${widget.cssWidth ?? '100%'};
            ${widget.maxWidth != null ? 'max-width: ${widget.maxWidth}px;' : ''}
            ${widget.constrainHeight && widget.maxHeight != null ? 'max-height: ${widget.maxHeight}px;' : ''}
        }
        
        .vega-embed {
            width: 100%;
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
    <div id="vis"></div>
    <script type="text/javascript">
        try {
            const spec = ${widget.vegaSpec};
            
            // Apply responsive defaults for container sizing
            if (!spec.width) {
              spec.width = "container";
            }
            if (!spec.height) {
              spec.height = ${widget.maxHeight != null ? widget.maxHeight : '"container"'};
            }
            
            // Ensure autosize is set for responsive behavior
            if (!spec.autosize) {
              spec.autosize = {
                type: "fit",
                resize: true,
                contains: "padding"
              };
            }
            
            // Ensure proper padding for legends and axes visibility
            if (!spec.padding) {
              spec.padding = {
                left: 20,
                top: 20,
                right: 20,
                bottom: 20
              };
            }
            
            vegaEmbed('#vis', spec, {
                actions: false,
                renderer: 'canvas',
                defaultStyle: true
            }).catch(function(error) {
                console.error('Vega-Lite error:', error);
                document.body.innerHTML = '<div class="error">Error rendering chart: ' + error.message + '</div>';
            });
        } catch (error) {
            console.error('Initialization error:', error);
            document.body.innerHTML = '<div class="error">Initialization Error: ' + error.message + '</div>';
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return _buildWidget(context);
  }
  
  Widget _buildWidget(BuildContext context) {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return _buildFallback();
    }
    
    final chartWidth = widget.maxWidth;
    final chartHeight = widget.maxHeight ?? 400;
    
    return Container(
      height: chartHeight,
      width: chartWidth,
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
                      'Loading chart...',
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
              'Error loading chart',
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
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final chartWidth = widget.maxWidth;
    final chartHeight = widget.maxHeight ?? 400;
    
    return Container(
      height: chartHeight,
      width: chartWidth,
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
            'Vega-Lite charts require a web environment to render.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
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
            ),
          ),
        ],
      ),
    );
  }
}
