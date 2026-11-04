// SPDX-FileCopyrightText: 2026 New York Footbag Association
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

/// Fades the edges of a horizontal row that scrolls, where there is more.
///
/// A chip row cut off at the screen edge reads as a layout bug -- "Schedule a
/// sess" -- unless something says it continues. The fade is that something,
/// and it only appears on a side with more to scroll to, so a row that fits
/// looks exactly as it did.
class EdgeFade extends StatefulWidget {
  final Widget child;

  /// How far in from each edge the fade reaches.
  final double width;

  const EdgeFade({required this.child, this.width = 32, super.key});

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  bool _before = false;
  bool _after = false;

  bool _update(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    final before = m.extentBefore > 0.5;
    final after = m.extentAfter > 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _update(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _update(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final edge = bounds.width == 0
                  ? 0.0
                  : (widget.width / bounds.width).clamp(0.0, 0.5);
              return LinearGradient(
                colors: [
                  _before ? Colors.transparent : Colors.black,
                  Colors.black,
                  Colors.black,
                  _after ? Colors.transparent : Colors.black,
                ],
                stops: [0, edge, 1 - edge, 1],
              ).createShader(bounds);
            },
            child: widget.child,
          ),
        ),
      );
}
