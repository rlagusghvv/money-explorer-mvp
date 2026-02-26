import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kid_econ_mvp/miniroom_coordinate_mapper.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

Matrix4 _worldToObject({
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final objectToWorld = Matrix4.identity()
    ..translateByDouble(left, top, 0, 1)
    ..scaleByDouble(width, height, 1, 1);
  final inverted = Matrix4.copy(objectToWorld);
  final ok = inverted.invert();
  expect(ok, isNonZero);
  return inverted;
}

void main() {
  group('r42 oss touch engine', () {
    test(
      'inverse-transform hit mapping keeps center error stable over scale',
      () {
        const center = Offset(220, 140);
        const baseSize = Size(72, 46);
        const scales = <double>[1.0, 1.5, 2.5, 3.5];
        const imageW = 100;
        const imageH = 100;

        for (final scale in scales) {
          final width = baseSize.width * scale;
          final height = baseSize.height * scale;
          final left = center.dx - (width / 2);
          final top = center.dy - (height / 2);
          final worldToObject = _worldToObject(
            left: left,
            top: top,
            width: width,
            height: height,
          );

          final mapped = MiniRoomImageMapper.mapWorldPointToPixelWithTransform(
            worldPoint: center,
            worldToObject: worldToObject,
            imageWidth: imageW,
            imageHeight: imageH,
          );

          expect(mapped, isNotNull);
          final normalized = mapped!.normalized;
          expect((normalized.dx - 0.5).abs(), lessThan(0.0001));
          expect((normalized.dy - 0.5).abs(), lessThan(0.0001));
        }
      },
    );

    test('transparent border is never selected', () {
      const imageW = 10;
      const imageH = 10;
      final worldToObject = _worldToObject(
        left: 100,
        top: 100,
        width: 100,
        height: 100,
      );
      final alpha = List.generate(imageW * imageH, (i) {
        final x = i % imageW;
        final y = i ~/ imageW;
        final border = x == 0 || y == 0 || x == imageW - 1 || y == imageH - 1;
        return border ? 0 : 255;
      });

      int falseSelects = 0;
      final transparentSamples = <Offset>[
        const Offset(101, 101),
        const Offset(198, 101),
        const Offset(101, 198),
        const Offset(198, 198),
      ];

      for (final p in transparentSamples) {
        final mapped = MiniRoomImageMapper.mapWorldPointToPixelWithTransform(
          worldPoint: p,
          worldToObject: worldToObject,
          imageWidth: imageW,
          imageHeight: imageH,
        );
        if (mapped == null) continue;
        final idx =
            (mapped.pixel.dy.toInt() * imageW) + mapped.pixel.dx.toInt();
        if (alpha[idx] > 40) falseSelects += 1;
      }

      expect(falseSelects, 0);
    });
  });
}
