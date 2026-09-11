import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/song_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_refresh.dart';
import 'my_songs_screen.dart';
import 'song_row.dart';

/// 기상송 화면. 검색해서 신청한다.
/// 신청분은 서버가 KST 기준 '내일' 곡으로 잡는다. (하루 10곡 마감)
///
/// 내 신청 내역은 아래 버튼으로 올라오는 [MySongsScreen] 에서 본다.
class SongScreen extends StatefulWidget {
  const SongScreen({super.key});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> with AppBannerMixin {
  static const _textColor = AppColors.mainText;

  final _queryController = TextEditingController();

  bool _searching = false;
  bool _searched = false;
  List<SongSearchResult> _results = const [];

  /// 신청 처리 중인 항목. 버튼을 잠가 중복 요청을 막는다.
  final Set<String> _busy = {};

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final results = await SongService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
        _searching = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      showErrorBanner(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
      showErrorBanner('검색에 실패했습니다.');
    }
  }

  Future<void> _request(SongSearchResult song) async {
    final key = song.youtubeUrl;
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await SongService.request(song);
      if (mounted) showSuccessBanner('내일 기상송으로 신청했습니다.');
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      // 그 날짜가 10곡을 채웠으면 여기로 온다.
      if (mounted) showErrorBanner(e.message);
    } catch (_) {
      if (mounted) showErrorBanner('신청에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── 검색 바 ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: AppColors.caption,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: '음악 찾아보기',
                                hintStyle: TextStyle(
                                  color: AppColors.caption,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _search,
                    child: Container(
                      height: 48,
                      width: 59,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _searching
                          ? const AppLoadingIndicator(size: 18, strokeWidth: 2)
                          : const Text(
                              '검색',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(child: _buildResults()),

            // ── 내 신청 목록 보기 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(110, 8, 110, 130),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMySongsSheet(context),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '내 신청 목록 보기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        buildBanner(),
      ],
    );
  }

  Widget _buildResults() {
    if (!_searched) {
      return const _CenterMessage(text: '듣고 싶은 노래를 검색해 보세요.');
    }
    if (_results.isEmpty) {
      return const _CenterMessage(text: '검색 결과가 없습니다.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        final song = _results[i];
        return SongRow(
          thumbnail: song.thumbnail,
          title: song.title,
          subtitle: song.channel,
          actionLabel: '신청',
          busy: _busy.contains(song.youtubeUrl),
          onAction: () => _request(song),
        );
      },
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.caption),
      ),
    );
  }
}
