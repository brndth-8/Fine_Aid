import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'admin_shared_widgets.dart';

/// Date ranges the trend chart can show.
enum TrendRange {
  days7('Last 7 days', 7, false),
  days30('Last 30 days', 30, false),
  months12('Last 12 months', 12, true);

  const TrendRange(this.label, this.buckets, this.monthly);
  final String label;
  final int buckets;
  final bool monthly;

  /// Start of each bucket, oldest first, ending with today / this month.
  List<DateTime> starts(DateTime now) => [
    for (var i = buckets - 1; i >= 0; i--)
      monthly
          ? DateTime(now.year, now.month - i)
          : DateTime(now.year, now.month, now.day - i),
  ];

  DateTime end(DateTime start) => monthly
      ? DateTime(start.year, start.month + 1)
      : DateTime(start.year, start.month, start.day + 1);
}

enum TrendMarker { circle, square, triangle }

enum TrendDash { solid, dashed, dotted }

/// One line on the chart. Colour, marker and dash style are all different per
/// series so the lines stay distinguishable without relying on colour alone.
class TrendSeries {
  const TrendSeries({
    required this.name,
    required this.query,
    required this.color,
    required this.marker,
    required this.dash,
    this.field = 'createdAt',
  });

  final String name;
  final Query<Map<String, dynamic>> query;
  final Color color;
  final TrendMarker marker;
  final TrendDash dash;
  final String field;
}

/// The three series shown on both the Dashboard and Reports & Analytics.
/// AI scans are journal entries the AI Camera flow saved (`source:
/// 'ai_camera'`); there is no separate scan log. That query needs the
/// composite index on journalEntries (source, createdAt).
List<TrendSeries> standardAdminTrendSeries(ColorScheme scheme) {
  final db = FirebaseFirestore.instance;
  return [
    TrendSeries(
      name: 'New users',
      query: db.collection('users'),
      color: scheme.primary,
      marker: TrendMarker.circle,
      dash: TrendDash.solid,
    ),
    TrendSeries(
      name: 'Journal entries',
      query: db.collectionGroup('journalEntries'),
      color: Colors.blueGrey.shade700,
      marker: TrendMarker.square,
      dash: TrendDash.dashed,
    ),
    TrendSeries(
      name: 'AI scans',
      query: db
          .collectionGroup('journalEntries')
          .where('source', isEqualTo: 'ai_camera'),
      color: Colors.orange.shade800,
      marker: TrendMarker.triangle,
      dash: TrendDash.dotted,
    ),
  ];
}

class _TrendData {
  const _TrendData(this.starts, this.range, this.values);
  final List<DateTime> starts;
  final TrendRange range;

  /// values[seriesIndex][bucketIndex]
  final List<List<int>> values;

  bool get isEmpty => values.every((s) => s.every((v) => v == 0));
}

/// One server-side `count()` per bucket per series, all in parallel. Buckets
/// with no documents come back as 0, so the line never skips a day. Nothing
/// is downloaded and only the displayed range is queried.
Future<_TrendData> _fetchTrend(
  List<TrendSeries> series,
  TrendRange range,
) async {
  final starts = range.starts(DateTime.now());
  final results = await Future.wait([
    for (final s in series)
      Future.wait([
        for (final start in starts)
          s.query
              .where(s.field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where(s.field, isLessThan: Timestamp.fromDate(range.end(start)))
              .count()
              .get()
              .then((snap) => snap.count ?? 0),
      ]),
  ]);
  return _TrendData(starts, range, results);
}

/// Card with a range selector, legend and an interactive line chart. Loads
/// by itself, so it never blocks the rest of the screen.
class AdminTrendCard extends StatefulWidget {
  const AdminTrendCard({
    super.key,
    required this.title,
    required this.caption,
    this.initialRange = TrendRange.days30,
  });

  final String title;
  final String caption;
  final TrendRange initialRange;

  @override
  State<AdminTrendCard> createState() => _AdminTrendCardState();
}

class _AdminTrendCardState extends State<AdminTrendCard> {
  // Built on first use (inside build) because the colours come from the theme.
  late final List<TrendSeries> _series = standardAdminTrendSeries(
    Theme.of(context).colorScheme,
  );
  late TrendRange _range = widget.initialRange;
  late Future<_TrendData> _future = _fetchTrend(_series, _range);

  void _load() => _future = _fetchTrend(_series, _range);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    widget.caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              SegmentedButton<TrendRange>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                ),
                segments: [
                  for (final r in TrendRange.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() {
                  _range = s.first;
                  _load();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final s in _series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(30, 12),
                      painter: _LegendPainter(s),
                    ),
                    const SizedBox(width: 6),
                    Text(s.name, style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: FutureBuilder<_TrendData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          adminErrorMessage(snap.error),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setState(_load),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final data = snap.data!;
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'No data yet for ${_range.label.toLowerCase()}.',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                return _TrendChart(
                  data: data,
                  series: _series,
                  textStyle:
                      theme.textTheme.bodySmall ??
                      const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatefulWidget {
  const _TrendChart({
    required this.data,
    required this.series,
    required this.textStyle,
  });

  final _TrendData data;
  final List<TrendSeries> series;
  final TextStyle textStyle;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _hover;

  void _update(Offset local, double width) {
    final n = widget.data.starts.length;
    final plotW = width - _LinesPainter.left - _LinesPainter.right;
    if (plotW <= 0) return;
    final step = n > 1 ? plotW / (n - 1) : plotW;
    final i = ((local.dx - _LinesPainter.left) / step).round().clamp(0, n - 1);
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final totals = [
      for (var i = 0; i < widget.series.length; i++)
        '${widget.series[i].name}: ${widget.data.values[i].fold<int>(0, (a, b) => a + b)}',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Semantics(
          label:
              'Line chart, ${widget.data.range.label.toLowerCase()}. Totals: ${totals.join(', ')}.',
          child: ExcludeSemantics(
            child: MouseRegion(
              onHover: (e) => _update(e.localPosition, w),
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _update(d.localPosition, w),
                onHorizontalDragUpdate: (d) => _update(d.localPosition, w),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LinesPainter(
                    data: widget.data,
                    series: widget.series,
                    textStyle: widget.textStyle,
                    hover: _hover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void _drawMarker(
  Canvas canvas,
  Offset c,
  TrendMarker m,
  Color color,
  double r,
) {
  final fill = Paint()..color = color;
  final ring = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  switch (m) {
    case TrendMarker.circle:
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, ring);
    case TrendMarker.square:
      final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 2);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, ring);
    case TrendMarker.triangle:
      final path = Path()
        ..moveTo(c.dx, c.dy - r - 1)
        ..lineTo(c.dx + r + 1, c.dy + r)
        ..lineTo(c.dx - r - 1, c.dy + r)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, ring);
  }
}

void _drawLine(Canvas canvas, Path path, Color color, TrendDash dash) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  if (dash == TrendDash.solid) {
    canvas.drawPath(path, paint);
    return;
  }
  final on = dash == TrendDash.dashed ? 8.0 : 1.5;
  final off = dash == TrendDash.dashed ? 5.0 : 5.0;
  for (final PathMetric m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
      d += on + off;
    }
  }
}

class _LegendPainter extends CustomPainter {
  _LegendPainter(this.series);
  final TrendSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    _drawLine(canvas, path, series.color, series.dash);
    _drawMarker(
      canvas,
      Offset(size.width / 2, y),
      series.marker,
      series.color,
      3.5,
    );
  }

  @override
  bool shouldRepaint(_LegendPainter old) => old.series != series;
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({
    required this.data,
    required this.series,
    required this.textStyle,
    required this.hover,
  });

  final _TrendData data;
  final List<TrendSeries> series;
  final TextStyle textStyle;
  final int? hover;

  static const left = 40.0;
  static const right = 12.0;
  static const _top = 12.0;
  static const _bottom = 28.0;

  TextPainter _tp(String text, {Color? color, FontWeight? weight}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: color ?? Colors.black54,
          fontWeight: weight,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// A readable top value and step (1/2/5 Ã— 10^k, whole numbers only), so
  /// the axis always starts at 0 and counts are never shown as fractions.
  (int top, int step) _axis(int maxValue) {
    if (maxValue <= 4) return (4, 1);
    final raw = maxValue / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    var step = mag;
    for (final f in [1, 2, 5, 10]) {
      step = f * mag;
      if (step >= raw) break;
    }
    final s = math.max(1, step.round());
    return (((maxValue / s).ceil()) * s, s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      _top,
      size.width - right,
      size.height - _bottom,
    );
    final n = data.starts.length;
    final maxValue = data.values
        .expand((v) => v)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final (top, step) = _axis(maxValue);

    double xAt(int i) =>
        n > 1 ? plot.left + plot.width * i / (n - 1) : plot.center.dx;
    double yAt(int v) => plot.bottom - plot.height * v / top;

    // Y grid + tick labels.
    final grid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    for (var v = 0; v <= top; v += step) {
      final y = yAt(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final t = _tp('$v');
      t.paint(canvas, Offset(plot.left - 8 - t.width, y - t.height / 2));
    }

    // X labels: thin them out so they never overlap.
    final fmt = data.range.monthly
        ? DateFormat("MMM ''yy")
        : DateFormat('MMM d');
    final every = n <= 12 ? 1 : (n / 6).ceil();
    for (var i = 0; i < n; i++) {
      if (i % every != 0 && i != n - 1) continue;
      if (i != n - 1 && n - 1 - i < every / 2) continue;
      final t = _tp(fmt.format(data.starts[i]));
      var x = xAt(i) - t.width / 2;
      x = x.clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(x, plot.bottom + 8));
    }

    // Lines + markers.
    for (var s = 0; s < series.length; s++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(xAt(i), yAt(data.values[s][i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      _drawLine(canvas, path, series[s].color, series[s].dash);

      final stride = n <= 12 ? 1 : 5;
      for (var i = 0; i < n; i++) {
        if (i % stride != 0 && i != n - 1) continue;
        _drawMarker(
          canvas,
          Offset(xAt(i), yAt(data.values[s][i])),
          series[s].marker,
          series[s].color,
          3.5,
        );
      }
    }

    // Hover / tap: guide line, enlarged markers, tooltip.
    final h = hover;
    if (h == null || h >= n) return;
    final hx = xAt(h);
    canvas.drawLine(
      Offset(hx, plot.top),
      Offset(hx, plot.bottom),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
    for (var s = 0; s < series.length; s++) {
      _drawMarker(
        canvas,
        Offset(hx, yAt(data.values[s][h])),
        series[s].marker,
        series[s].color,
        5,
      );
    }

    final dateText = data.range.monthly
        ? DateFormat('MMMM y').format(data.starts[h])
        : DateFormat('EEE, MMM d, y').format(data.starts[h]);
    final head = _tp(dateText, color: Colors.black87, weight: FontWeight.bold);
    final rows = [
      for (var s = 0; s < series.length; s++)
        _tp('${series[s].name}: ${data.values[s][h]}', color: Colors.black87),
    ];
    final w =
        [head.width, ...rows.map((r) => r.width + 18)].reduce(math.max) + 20;
    final hgt =
        10 + head.height + 4 + rows.length * (rows.first.height + 3) + 6;
    var bx = hx + 12;
    if (bx + w > size.width) bx = hx - 12 - w;
    bx = math.max(0, bx);
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, plot.top, w, hgt),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      box.shift(const Offset(0, 2)),
      Paint()..color = Colors.black12,
    );
    canvas.drawRRect(box, Paint()..color = Colors.white);
    canvas.drawRRect(
      box,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke,
    );
    head.paint(canvas, Offset(bx + 10, plot.top + 8));
    var y = plot.top + 8 + head.height + 4;
    for (var s = 0; s < rows.length; s++) {
      _drawMarker(
        canvas,
        Offset(bx + 15, y + rows[s].height / 2),
        series[s].marker,
        series[s].color,
        3.5,
      );
      rows[s].paint(canvas, Offset(bx + 25, y));
      y += rows[s].height + 3;
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.data != data || old.hover != hover || old.series != series;
}
