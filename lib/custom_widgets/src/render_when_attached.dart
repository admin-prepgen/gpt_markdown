import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Runs a web chart/diagram [render] only once [element] is attached to the
/// document and laid out, retrying when an attempt fails.
///
/// Flutter web hands a platform view's element to the page only when it
/// composites a frame, and frames are driven by requestAnimationFrame, which
/// browsers pause in background tabs. Rendering on a timer could therefore run
/// against an element that is not in the document yet (vega-embed: "#… does
/// not exist"), leaving the chart blank for good. Waiting for attachment makes
/// the render happen whenever the element really appears.
class RenderWhenAttached {
  RenderWhenAttached(
    this.element,
    this.render, {
    this.maxAttempts = 3,
    this.maxLayoutFrames = 30,
  });

  /// The platform view's root element.
  final web.Element element;

  /// Draws into [element]. A thrown error or rejected future counts as a
  /// failed attempt.
  final Future<void> Function() render;

  /// Total render attempts, including the first.
  final int maxAttempts;

  /// After attachment, at most this many animation frames are spent waiting
  /// for the element to get a non-zero width before rendering anyway.
  final int maxLayoutFrames;

  int _attempts = 0;
  bool _cancelled = false;
  web.MutationObserver? _observer;
  Completer<void>? _waiting;

  /// Number of render attempts made so far.
  int get attempts => _attempts;

  /// Waits for attachment and renders, retrying failed attempts. Completes
  /// with true once an attempt succeeds, false when every attempt failed or
  /// [cancel] was called.
  Future<bool> run() async {
    while (_attempts < maxAttempts) {
      await _attached();
      if (_cancelled) return false;
      await _laidOut();
      if (_cancelled) return false;
      if (!element.isConnected) continue; // detached again; wait once more
      _attempts++;
      try {
        await render();
        return !_cancelled;
      } catch (e) {
        if (kDebugMode) {
          print('Render attempt $_attempts/$maxAttempts failed: $e');
        }
        if (_cancelled) return false;
      }
    }
    return false;
  }

  /// Stops waiting and prevents further attempts.
  void cancel() {
    _cancelled = true;
    _stopObserving();
  }

  Future<void> _attached() {
    if (element.isConnected) return Future<void>.value();
    final waiting = _waiting = Completer<void>();
    // Platform views are slotted into the light DOM of <flt-glass-pane>, so a
    // document-wide observer sees them arrive.
    _observer = web.MutationObserver(
      (JSArray<web.MutationRecord> _, web.MutationObserver _) {
        if (element.isConnected) _stopObserving();
      }.toJS,
    )..observe(
      web.document,
      web.MutationObserverInit(childList: true, subtree: true),
    );
    return waiting.future;
  }

  void _stopObserving() {
    _observer?.disconnect();
    _observer = null;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  Future<void> _laidOut() async {
    for (
      var frame = 0;
      frame < maxLayoutFrames && !_cancelled && element.clientWidth == 0;
      frame++
    ) {
      final next = Completer<void>();
      web.window.requestAnimationFrame(((double _) => next.complete()).toJS);
      await next.future;
    }
  }
}
