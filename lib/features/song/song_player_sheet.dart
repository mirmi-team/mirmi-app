import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../shared/app_colors.dart';

/// 유튜브 주소에서 videoId 를 뽑는다. 형식이 다르면 null.
///
/// 백엔드가 `watch?v=` 형태로 저장하지만, 공유 링크(`youtu.be/ID`)나
/// 임베드 주소도 들어올 수 있어 함께 처리한다.
String? youtubeVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final fromQuery = uri.queryParameters['v'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  // youtu.be/ID, /embed/ID, /shorts/ID
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final last = segments.last;
  return last.isEmpty ? null : last;
}

/// 곡을 앱 안에서 재생한다. 썸네일을 누르면 아래에서 올라온다.
Future<void> showSongPlayerSheet(
  BuildContext context, {
  required String youtubeUrl,
  required String title,
}) {
  final videoId = youtubeVideoId(youtubeUrl);
  if (videoId == null) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SongPlayerSheet(videoId: videoId, title: title),
  );
}

class _SongPlayerSheet extends StatefulWidget {
  const _SongPlayerSheet({required this.videoId, required this.title});

  final String videoId;
  final String title;

  @override
  State<_SongPlayerSheet> createState() => _SongPlayerSheetState();
}

class _SongPlayerSheetState extends State<_SongPlayerSheet> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        // 관련 영상 추천을 줄여 이탈을 막는다.
        showVideoAnnotations: false,
      ),
    );
  }

  @override
  void dispose() {
    // 시트를 닫으면 소리가 이어지지 않도록 확실히 정리한다.
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppColors.mainText,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '일부 영상은 저작권자 설정으로 앱 안에서 재생되지 않을 수 있습니다.',
              style: TextStyle(fontSize: 11, color: AppColors.caption),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
