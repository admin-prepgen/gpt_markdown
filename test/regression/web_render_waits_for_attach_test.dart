// Vega-Lite charts drew blank in background tabs: the embed ran on a timer
// before Flutter had attached the platform view's element, so vega-embed
// failed with "#vega-container-… does not exist" and never retried.
//
// Browser-only; run with: flutter test --platform chrome test/regression/web_render_waits_for_attach_test.dart
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/src/render_when_attached.dart';
import 'package:web/web.dart' as web;

web.HTMLDivElement _detachedDiv() =>
    web.document.createElement('div') as web.HTMLDivElement
      ..style.width = '300px';

/// Lets microtasks, MutationObserver callbacks and a few timers run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('does not render until the element is attached, then renders', () async {
    final el = _detachedDiv();
    var renders = 0;
    bool? connectedAtRender;
    final renderer = RenderWhenAttached(el, () async {
      renders++;
      connectedAtRender = el.isConnected;
    });

    final done = renderer.run();
    await _settle();
    expect(renders, 0, reason: 'must not render into a detached element');

    // Attach it the way Flutter does: inside a wrapper inserted later.
    final wrapper = web.document.createElement('flt-platform-view')
      ..appendChild(el);
    web.document.body!.appendChild(wrapper);

    expect(await done, isTrue);
    expect(renders, 1);
    expect(connectedAtRender, isTrue);
    wrapper.remove();
  });

  test('renders immediately when already attached', () async {
    final el = _detachedDiv();
    web.document.body!.appendChild(el);
    var renders = 0;
    final ok = await RenderWhenAttached(el, () async => renders++).run();
    expect(ok, isTrue);
    expect(renders, 1);
    el.remove();
  });

  test('re-renders after a failed attempt', () async {
    final el = _detachedDiv();
    web.document.body!.appendChild(el);
    var renders = 0;
    final ok =
        await RenderWhenAttached(el, () async {
          renders++;
          if (renders == 1) throw StateError('first embed failed');
        }).run();
    expect(ok, isTrue);
    expect(renders, 2);
    el.remove();
  });

  test('gives up after maxAttempts failures', () async {
    final el = _detachedDiv();
    web.document.body!.appendChild(el);
    var renders = 0;
    final renderer = RenderWhenAttached(el, () async {
      renders++;
      throw StateError('always fails');
    }, maxAttempts: 3);
    expect(await renderer.run(), isFalse);
    expect(renders, 3);
    expect(renderer.attempts, 3);
    el.remove();
  });

  test('waits for re-attachment before retrying a detached element', () async {
    final el = _detachedDiv();
    web.document.body!.appendChild(el);
    var renders = 0;
    final renderer = RenderWhenAttached(el, () async {
      renders++;
      if (renders == 1) {
        el.remove(); // detached mid-render, e.g. Flutter moved the view
        throw StateError('detached');
      }
    });
    final done = renderer.run();
    await _settle();
    expect(renders, 1, reason: 'retry must wait until attached again');

    web.document.body!.appendChild(el);
    expect(await done, isTrue);
    expect(renders, 2);
    el.remove();
  });

  test('cancel stops a pending render', () async {
    final el = _detachedDiv();
    var renders = 0;
    final renderer = RenderWhenAttached(el, () async => renders++);
    final done = renderer.run();
    await _settle();
    renderer.cancel();
    expect(await done, isFalse);

    web.document.body!.appendChild(el);
    await _settle();
    expect(renders, 0);
    el.remove();
  });
}
