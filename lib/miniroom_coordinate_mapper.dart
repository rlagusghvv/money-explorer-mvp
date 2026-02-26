import 'dart:ui';

class MiniRoomMappedPoint {
  const MiniRoomMappedPoint({
    required this.pixel,
    required this.normalized,
    required this.drawRect,
  });

  final Offset pixel;
  final Offset normalized;
  final Rect drawRect;
}

class MiniRoomImageMapper {
  const MiniRoomImageMapper._();

  static Rect? containDrawRect({
    required Rect visualRect,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0 || visualRect.isEmpty) return null;

    final imageAspect = imageWidth / imageHeight;
    final viewAspect = visualRect.width / visualRect.height;

    if (imageAspect > viewAspect) {
      final drawWidth = visualRect.width;
      final drawHeight = drawWidth / imageAspect;
      final drawTop = visualRect.top + ((visualRect.height - drawHeight) / 2);
      return Rect.fromLTWH(visualRect.left, drawTop, drawWidth, drawHeight);
    }

    final drawHeight = visualRect.height;
    final drawWidth = drawHeight * imageAspect;
    final drawLeft = visualRect.left + ((visualRect.width - drawWidth) / 2);
    return Rect.fromLTWH(drawLeft, visualRect.top, drawWidth, drawHeight);
  }

  static MiniRoomMappedPoint? mapWorldPointToPixel({
    required Offset worldPoint,
    required Rect visualRect,
    required int imageWidth,
    required int imageHeight,
  }) {
    final drawRect = containDrawRect(
      visualRect: visualRect,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    if (drawRect == null || !drawRect.contains(worldPoint)) return null;

    final nx = (worldPoint.dx - drawRect.left) / drawRect.width;
    final ny = (worldPoint.dy - drawRect.top) / drawRect.height;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return null;

    final px = (nx * (imageWidth - 1)).round().clamp(0, imageWidth - 1);
    final py = (ny * (imageHeight - 1)).round().clamp(0, imageHeight - 1);

    return MiniRoomMappedPoint(
      pixel: Offset(px.toDouble(), py.toDouble()),
      normalized: Offset(nx, ny),
      drawRect: drawRect,
    );
  }
}
