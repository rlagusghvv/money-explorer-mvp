import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_econ_mvp/miniroom_coordinate_mapper.dart';

void main() {
  test('contain mapping keeps round-trip error <= 4px for 20 samples', () {
    const visualRect = Rect.fromLTWH(40, 20, 180, 120);
    const imageWidth = 512;
    const imageHeight = 384;

    final random = Random(42);
    final drawRect = MiniRoomImageMapper.containDrawRect(
      visualRect: visualRect,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    )!;

    var maxErr = 0.0;
    for (var i = 0; i < 20; i++) {
      final p = Offset(
        drawRect.left + (random.nextDouble() * drawRect.width),
        drawRect.top + (random.nextDouble() * drawRect.height),
      );
      final mapped = MiniRoomImageMapper.mapWorldPointToPixel(
        worldPoint: p,
        visualRect: visualRect,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      )!;
      final back = Offset(
        drawRect.left + (mapped.normalized.dx * drawRect.width),
        drawRect.top + (mapped.normalized.dy * drawRect.height),
      );
      final err = (back - p).distance;
      if (err > maxErr) maxErr = err;
    }

    expect(maxErr, lessThanOrEqualTo(4.0));
  });

  test(
    'points outside draw rect are rejected (transparent over-select guard)',
    () {
      const visualRect = Rect.fromLTWH(0, 0, 200, 200);
      const imageWidth = 400;
      const imageHeight = 100;

      final drawRect = MiniRoomImageMapper.containDrawRect(
        visualRect: visualRect,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      )!;

      expect(
        MiniRoomImageMapper.mapWorldPointToPixel(
          worldPoint: Offset(drawRect.center.dx, drawRect.top - 5),
          visualRect: visualRect,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        isNull,
      );
      expect(
        MiniRoomImageMapper.mapWorldPointToPixel(
          worldPoint: Offset(drawRect.left - 3, drawRect.center.dy),
          visualRect: visualRect,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        isNull,
      );
    },
  );
}
