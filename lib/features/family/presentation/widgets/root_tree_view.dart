import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  State<RootTreeView> createState() => _RootTreeViewState();
}

class _RootTreeViewState extends State<RootTreeView> {
  WebViewController? _controller;
  bool _ready = false;
  bool _pageLoaded = false;
  bool _loadingHtml = true;
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
  void didUpdateWidget(covariant RootTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members ||
        oldWidget.relationships != widget.relationships) {
      _rebuildForest();
      if (_ready) _pushForest();
    }
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
              _pageLoaded = true;
              // HTML already posts parivaar-ready; also push after a beat.
              await Future<void>.delayed(const Duration(milliseconds: 160));
              if (!mounted) return;
              _ready = true;
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
        _ready = true;
        _pushForest();
        return;
      }
      if (type == 'parivaar-cleared') {
        if (mounted) setState(() => _focusName = null);
        return;
      }
      if (type == 'parivaar-select') {
        final id = data['memberId']?.toString() ?? '';
        if (id.isEmpty) return;
        FamilyMember? member;
        for (final m in widget.members) {
          if (m.id == id) {
            member = m;
            break;
          }
        }
        if (member == null) return;
        if (mounted) {
          setState(() => _focusName = member!.name);
        }
        widget.onSelect?.call(member);
      }
    } catch (_) {
      // Ignore malformed bridge payloads.
    }
  }

  Future<void> _pushForest() async {
    final c = _controller;
    if (c == null || (!_ready && !_pageLoaded)) return;
    final rootsJson = jsonEncode(_forest.map((e) => e.toJson()).toList());
    // Same channel the HTML embed listener expects.
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

    return ColoredBox(
      color: const Color(0xFF060B12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else if (_loadingHtml)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE9B95F)),
            ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '$_people people · living root tree · tap person for profile',
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
                            Flexible(
                              child: Text(
                                'Focused · $_focusName',
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
        ],
      ),
    );
  }
}
