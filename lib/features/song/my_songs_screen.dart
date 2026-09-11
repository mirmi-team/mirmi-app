import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/song_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_dialog.dart';
import '../../shared/app_refresh.dart';
import '../../shared/app_skeleton.dart';
import 'song_row.dart';

/// 내 신청 목록을 아래에서 위로 올린다. (건의사항 카테고리 선택과 같은 방식)
///
/// 검색 입력창이 가려지지 않는 높이까지만 올라오고, 목록이 스크롤을 가져가므로
/// 시트를 잡아 내릴 수 있는 곳은 맨 위 손잡이 영역뿐이다.
Future<void> showMySongsSheet(BuildContext context) {
  final media = MediaQuery.of(context);
  // 상단바 + 검색창(위 여백 16 + 높이 48 + 아래 여백 16) 만큼은 비워둔다.
  const searchAreaExtent = 180.0;
  final maxHeight =
      media.size.height - media.padding.top - kToolbarHeight - searchAreaExtent;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    constraints: BoxConstraints(maxHeight: maxHeight),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const MySongsScreen(),
  );
}

/// 내 신청 목록. 기상송 화면에서 아래에서 위로 올라온다.
///
/// 재생 날짜(play_date)로 묶어서 보여주고, 아직 나가지 않은 곡에만
/// 취소 버튼이 붙는다. 지나간 곡은 '재생완료'로 표시만 한다.
class MySongsScreen extends StatefulWidget {
  const MySongsScreen({super.key});

  @override
  State<MySongsScreen> createState() => _MySongsScreenState();
}

class _MySongsScreenState extends State<MySongsScreen> with AppBannerMixin {
  static const _textColor = AppColors.mainText;

  bool _loading = true;
  List<MorningSong> _songs = const [];

  /// 취소 처리 중인 항목. 버튼을 잠가 중복 요청을 막는다.
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final songs = await SongService.getMine();
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('목록을 불러오지 못했습니다.');
    }
  }

  Future<void> _cancel(MorningSong song) async {
    if (_busy.contains(song.id)) return;

    final ok = await showConfirmDialog(
      context,
      title: '신청을 취소할까요?',
      message: song.songName,
      confirmText: '취소하기',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(song.id));
    try {
      await SongService.cancel(song.id);
      if (!mounted) return;
      showSuccessBanner('신청을 취소했습니다.');
      await _load(silent: true);
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (mounted) showErrorBanner(e.message);
    } catch (_) {
      if (mounted) showErrorBanner('취소에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy.remove(song.id));
    }
  }

  /// 재생 날짜별로 묶는다. 최근 날짜가 위로.
  List<MapEntry<String, List<MorningSong>>> get _grouped {
    final map = <String, List<MorningSong>>{};
    for (final song in _songs) {
      (map[song.playDate] ??= []).add(song);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  /// '2026-09-14' → '09.14'
  String _dateLabel(String playDate) {
    final parts = playDate.split('-');
    if (parts.length != 3) return playDate;
    return '${parts[1]}.${parts[2]}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시트를 잡아 내릴 수 있는 유일한 영역
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
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '내 신청 목록',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildBody()),
          ],
        ),
        buildBanner(),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (_, _) => const AppSkeleton(height: 56, radius: 6),
      );
    }

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: _songs.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '신청한 곡이 없습니다.',
                      style: TextStyle(fontSize: 13, color: AppColors.caption),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildListDelegate([
                    for (final group in _grouped) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          _dateLabel(group.key),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.caption,
                          ),
                        ),
                      ),
                      for (final song in group.value) ...[
                        SongRow(
                          thumbnail: song.thumbnail,
                          title: song.songName,
                          // 이미 나간 곡은 순번 대신 상태를 보여준다.
                          subtitle: song.isUpcoming
                              ? (song.playOrder == null
                                    ? ''
                                    : '${song.playOrder}번째 재생')
                              : '재생 완료',
                          // 지나간 곡은 버튼 없이 상태만 보여준다.
                          actionLabel: song.isUpcoming ? '취소' : null,
                          destructive: true,
                          busy: _busy.contains(song.id),
                          onAction: () => _cancel(song),
                        ),
                        const SizedBox(height: 18),
                      ],
                      const SizedBox(height: 14),
                    ],
                  ]),
                ),
        ),
      ],
    );
  }
}
