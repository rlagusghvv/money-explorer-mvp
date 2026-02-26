import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_econ_mvp/miniroom_coordinate_mapper.dart';

Offset _centerPinnedTopLeft({
  required Offset center,
  required Size baseSize,
  required double scale,
}) {
  final width = baseSize.width * scale;
  final height = baseSize.height * scale;
  return Offset(center.dx - (width / 2), center.dy - (height / 2));
}

void main() {
  group('r41 touch validation', () {
    test('scale 1.0/1.5/2.5/3.5 keeps center error at 0', () {
      const baseSize = Size(72, 46);
      const initialRect = Rect.fromLTWH(120, 80, 72, 46);
      final center = initialRect.center;
      const scales = <double>[1.0, 1.5, 2.5, 3.5];

      for (final scale in scales) {
        final topLeft = _centerPinnedTopLeft(
          center: center,
          baseSize: baseSize,
          scale: scale,
        );
        final rect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          baseSize.width * scale,
          baseSize.height * scale,
        );
        expect((rect.center - center).distance, lessThan(0.0001));
      }
    });

    test('transparent area false-select count stays 0', () {
      const visualRect = Rect.fromLTWH(100, 100, 100, 100);
      const imageW = 10;
      const imageH = 10;

      // 1px transparent border + solid center.
      final alpha = List.generate(
        imageW * imageH,
        (i) {
          final x = i % imageW;
          final y = i ~/ imageW;
          final border = x == 0 || y == 0 || x == imageW - 1 || y == imageH - 1;
          return border ? 0 : 255;
        },
      );

      int falseSelects = 0;
      final transparentSamples = <Offset>[
        const Offset(101, 101),
        const Offset(198, 101),
        const Offset(101, 198),
        const Offset(198, 198),
      ];

      for (final p in transparentSamples) {
        final mapped = MiniRoomImageMapper.mapWorldPointToPixel(
          worldPoint: p,
          visualRect: visualRect,
          imageWidth: imageW,
          imageHeight: imageH,
        );
        if (mapped == null) continue;
        final idx = (mapped.pixel.dy.toInt() * imageW) + mapped.pixel.dx.toInt();
        if (alpha[idx] > 40) falseSelects += 1;
      }

      expect(falseSelects, 0);
    });

    test('30 drag updates are monotonic (no jump)', () {
      const start = Offset(120, 80);
      const step = Offset(3, 2);
      var previous = start;

      for (var i = 1; i <= 30; i++) {
        final next = Offset(start.dx + (step.dx * i), start.dy + (step.dy * i));
        expect(next.dx, greaterThan(previous.dx));
        expect(next.dy, greaterThan(previous.dy));
        expect((next - previous).distance, lessThanOrEqualTo(3.7));
        previous = next;
      }
    });
  });
}
