import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Listing attachments are session-only until the shared backend stores them.
class ProductMedia {
  const ProductMedia({
    required this.name,
    required this.isVideo,
    this.bytes,
    this.url,
  });
  final String name;
  final bool isVideo;
  final Uint8List? bytes;
  final String? url;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': isVideo ? 'video' : 'image',
    if (bytes != null) 'data': base64Encode(bytes!),
    if (url != null) 'url': url,
  };

  static List<ProductMedia> fromProduct(Map<String, dynamic> product) {
    final rows = product['media'] as List?;
    if (rows != null) {
      return rows
          .map(
            (row) => ProductMedia(
              name: row['name'] as String? ?? 'Product media',
              isVideo: row['type'] == 'video',
              url: row['url'] as String?,
              bytes: row['data'] == null
                  ? null
                  : base64Decode(row['data'] as String),
            ),
          )
          .toList();
    }
    return (product['images'] as List? ?? [])
        .whereType<String>()
        .map(
          (url) =>
              ProductMedia(name: 'Product photo', isVideo: false, url: url),
        )
        .toList();
  }

  static Future<ProductMedia?> pick({
    required bool video,
    required List<ProductMedia> existing,
  }) async {
    if (video
        ? existing.any((m) => m.isVideo)
        : existing.where((m) => !m.isVideo).length >= 5) {
      throw const FormatException(
        'Use up to 5 photos and 1 video per product.',
      );
    }
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: video ? ['mp4'] : ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (selected == null) return null;
    final extension = selected.extension?.toLowerCase();
    if (!(video ? ['mp4'] : ['jpg', 'jpeg', 'png', 'webp']).contains(
      extension,
    )) {
      throw const FormatException(
        'Choose a JPG, PNG, WEBP photo or an MP4 video.',
      );
    }
    final limit = (video ? 20 : 5) * 1024 * 1024;
    final size = await selected.length();
    if (size == null || size <= 0 || size > limit) {
      throw FormatException(
        'Choose a nonempty ${video ? 'video up to 20 MB' : 'photo up to 5 MB'}.',
      );
    }
    final bytes = await selected.readAsBytes();
    if (bytes.isEmpty || bytes.length > limit) {
      throw const FormatException('This attachment is empty or too large.');
    }
    return ProductMedia(name: selected.name, isVideo: video, bytes: bytes);
  }
}

class ProductMediaGallery extends StatelessWidget {
  const ProductMediaGallery({super.key, required this.media, this.onRemove});
  final List<ProductMedia> media;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < media.length; i++)
        SizedBox(
          width: 104,
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => _MediaPreview(media: media[i]),
                        ),
                        child: SizedBox(
                          width: 104,
                          height: 92,
                          child: media[i].isVideo
                              ? const Icon(Icons.play_circle_outline, size: 40)
                              : _photo(media[i], BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove ${media[i].name}',
                        onPressed: () => onRemove!(i),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                ],
              ),
              Text(
                media[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
    ],
  );
}

Widget _photo(ProductMedia media, BoxFit fit) {
  Widget error(BuildContext context, Object error, StackTrace? stack) =>
      const Center(child: Icon(Icons.broken_image_outlined));
  return media.bytes != null
      ? Image.memory(media.bytes!, fit: fit, errorBuilder: error)
      : media.url != null
      ? Image.network(media.url!, fit: fit, errorBuilder: error)
      : const Icon(Icons.image_outlined);
}

class _MediaPreview extends StatefulWidget {
  const _MediaPreview({required this.media});
  final ProductMedia media;
  @override
  State<_MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<_MediaPreview> {
  VideoPlayerController? player;
  Directory? temporaryDirectory;
  String? error;
  late final Future<void> initialized;

  @override
  void initState() {
    super.initState();
    initialized = widget.media.isVideo ? initializeVideo() : Future.value();
  }

  Future<void> initializeVideo() async {
    try {
      final media = widget.media;
      if (media.bytes != null) {
        final directory = await Directory.systemTemp.createTemp(
          'lumear-video-',
        );
        temporaryDirectory = directory;
        final file = await File('${directory.path}/preview.mp4')
            .writeAsBytes(media.bytes!);
        if (!mounted) return;
        player = VideoPlayerController.file(file);
      } else if (media.url != null) {
        player = VideoPlayerController.networkUrl(Uri.parse(media.url!));
      } else {
        throw const FormatException('No video source.');
      }
      await player!.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to play this video. Try another MP4 file.',
        );
      }
    }
  }

  Future<void> cleanUp() async {
    final controller = player;
    player = null;
    await controller?.dispose();
    final directory = temporaryDirectory;
    temporaryDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    initialized.then((_) => cleanUp());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.media.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    content: SizedBox(
      width: 480,
      height: 280,
      child: !widget.media.isVideo
          ? _photo(widget.media, BoxFit.contain)
          : error != null
          ? Center(child: Text(error!))
          : player?.value.isInitialized != true
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: player!.value.aspectRatio,
                      child: VideoPlayer(player!),
                    ),
                  ),
                ),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: player!,
                  builder: (context, value, _) => IconButton(
                    tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () async {
                      if (value.isPlaying) {
                        await player!.pause();
                      } else {
                        if (value.position >= value.duration) {
                          await player!.seekTo(Duration.zero);
                        }
                        await player!.play();
                      }
                    },
                  ),
                ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
