import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../app/theme.dart';
import '../../data/models/family_models.dart';
import '../../domain/root_tree_forest.dart';

/// Web-parity Root tree: embeds the same `parivaar-root.html` living-tree
/// (playback dock, timeline, moonlit canvas) used by the web panel iframe.
class RootTreeView extends StatefulWidget {
  const RootTreeView({
    super.key,
    required this.members,
    required this.relationships,
    this.onSelect,
    this.selectedId,
    this.familyName = 'Family',
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final ValueChanged<FamilyMember>? onSelect;
  final String? selectedId;
  final String familyName;

  @override
  State<RootTreeView> createState() => RootTreeViewState();
}

class RootTreeViewState extends State<RootTreeView> {
  WebViewController? _controller;
  bool _ready = false;
  bool _pageLoaded = false;
  bool _loadingHtml = true;
  bool _openingProfile = false;
  String? _loadError;
  String? _focusName;

  late List<RootTreeNode> _forest;
  late int _people;

  @override
  void initState() {
    super.initState();
    _rebuildForest();
    _initWebView();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RootTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members ||
        oldWidget.relationships != widget.relationships) {
      _rebuildForest();
      if (_ready) _pushForest();
    }
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Widget _buildWebView() {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    // Hybrid composition avoids Texture-layer black surfaces when the
    // Root tree is remounted after a profile route on Android.
    if (_isAndroid && controller.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform as AndroidWebViewController,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  void _rebuildForest() {
    _forest = buildRootForest(widget.members, widget.relationships);
    _people = countForestPeople(_forest);
  }

  Future<void> _initWebView() async {
    try {
      final raw = await rootBundle.loadString('assets/web/parivaar-root.html');
      // Force embed mode inside Flutter WebView (parent === window otherwise).
      final html = raw.replaceFirst(
        'const EMBED=!!(window.parent&&window.parent!==window);',
        'const EMBED=true;'
        'window.parent={postMessage:function(d){'
        'try{if(window.ParivaarBridge)ParivaarBridge.postMessage(JSON.stringify(d));}'
        'catch(e){}}};',
      );

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF060B12))
        ..addJavaScriptChannel(
          'ParivaarBridge',
          onMessageReceived: _onBridgeMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) async {
              await Future<void>.delayed(const Duration(milliseconds: 160));
              if (!mounted) return;
              setState(() {
                _pageLoaded = true;
                _ready = true;
              });
              await _pushForest();
            },
          ),
        );

      await controller.loadHtmlString(
        html,
        baseUrl: 'https://local.parivaar/',
      );

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loadingHtml = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHtml = false;
        _loadError = e.toString();
      });
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data is! Map) return;
      final type = data['type']?.toString();
      if (type == 'parivaar-ready') {
        if (mounted) {
          setState(() {
            _ready = true;
            _pageLoaded = true;
          });
        } else {
          _ready = true;
          _pageLoaded = true;
        }
        _pushForest();
        return;
      }
      if (type == 'parivaar-cleared') {
        if (mounted) setState(() => _focusName = null);
        return;
      }
      if (type == 'parivaar-select') {
        final id = data['memberId']?.toString() ?? '';
        if (id.isEmpty || _openingProfile) return;
        FamilyMember? member;
        for (final m in widget.members) {
          if (m.id == id) {
            member = m;
            break;
          }
        }
        if (member == null) return;
        if (mounted) setState(() => _focusName = member!.name);
        _openingProfile = true;
        // Host must unmount this WebView while profile is open.
        widget.onSelect?.call(member);
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          _openingProfile = false;
        });
      }
    } catch (_) {
      // Ignore malformed bridge payloads.
    }
  }

  Future<void> _pushForest() async {
    final c = _controller;
    if (c == null || (!_ready && !_pageLoaded)) return;
    final rootsJson = jsonEncode(_forest.map((e) => e.toJson()).toList());
    final js = '''
(function(){
  try {
    window.postMessage({ type: 'parivaar-bootstrap', roots: $rootsJson }, '*');
  } catch (e) {}
})();
''';
    try {
      await c.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _clearFocus() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.runJavaScript(
        "window.postMessage({ type: 'parivaar-clear' }, '*');",
      );
    } catch (_) {}
    if (mounted) setState(() => _focusName = null);
  }

  Future<void> _zoomBy(double factor) async {
    final c = _controller;
    if (c == null || !_pageLoaded) return;
    // Zoom-out after profile select: clear person focus so the camera can
    // actually pull back (selP locks framing on the face).
    final clearFocus = factor > 1.0;
    try {
      await c.runJavaScript('''
(function(){
  var f=$factor;
  if($clearFocus && typeof select==='function'){ try{select(null);}catch(e){} }
  window.postMessage({ type: 'parivaar-zoom-by', factor: f }, '*');
})();
''');
    } catch (_) {}
    if (clearFocus && mounted && _focusName != null) {
      setState(() => _focusName = null);
    }
  }

  Future<void> _resetView() async {
    final c = _controller;
    if (c == null || !_pageLoaded) return;
    try {
      await c.runJavaScript('''
(function(){
  try{ if(typeof select==='function') select(null); }catch(e){}
  try{ baseAz=0; baseEl=0.08; userZoom=1; idleT=10; }catch(e){}
  window.postMessage({ type: 'parivaar-zoom', zoom: 1 }, '*');
})();
''');
    } catch (_) {}
    if (mounted && _focusName != null) {
      setState(() => _focusName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forest.isEmpty) {
      return Container(
        color: const Color(0xFF060B12),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_outlined, size: 36, color: Colors.amber.shade300),
            const SizedBox(height: 10),
            Text(
              'Root tree is not ready yet',
              style: AppTheme.body(
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add first-generation members and parent/child relations — then the living tree will grow from oldest to newest.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        color: const Color(0xFF060B12),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load root tree preview.\n$_loadError',
          textAlign: TextAlign.center,
          style: AppTheme.body(color: Colors.redAccent, size: 13),
        ),
      );
    }

    final showLoader = _loadingHtml || _controller == null || !_pageLoaded;

    return ColoredBox(
      color: const Color(0xFF060B12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null) _buildWebView(),
          if (showLoader)
            const ColoredBox(
              color: Color(0xFF060B12),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFE9B95F)),
              ),
            ),
          // Keep overlays left-only and intrinsic width so they never steal
          // taps from the HTML zoom tools (top-right) — especially after a
          // profile select when the "Focused" chip used to go full-width.
          Positioned(
            left: 12,
            top: 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.52,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '$_people people · tap person for profile',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_focusName != null) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _clearFocus,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.38,
                                ),
                                child: Text(
                                  'Focused · $_focusName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Native Flutter zoom — reliable taps above the WebView PlatformView.
          Positioned(
            right: 10,
            top: 12,
            child: Material(
              color: const Color(0xE6080F18),
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _zoomBy(1.25),
                    icon: const Icon(Icons.zoom_out, size: 20, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _zoomBy(1 / 1.25),
                    icon: const Icon(Icons.zoom_in, size: 20, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Reset view',
                    visualDensity: VisualDensity.compact,
                    onPressed: _resetView,
                    icon: const Icon(Icons.filter_center_focus, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
