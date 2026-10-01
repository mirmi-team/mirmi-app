import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/song_service.dart';
import '../../../shared/app_banner.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/app_dialog.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_refresh.dart';
import '../../../shared/app_segmented_tabs.dart';
import '../../../shared/app_skeleton.dart';
import '../../song/song_row.dart';
import '../admin_player.dart';

/// 기상송 관리.
///
/// 오늘 곡은 틀기만 하고, 내일 곡은 미리 확인하고 부적절한 것을 지운다.
/// (내일 곡은 아직 나갈 차례가 아니라 재생하지 않는다)
class AdminSongTab extends StatefulWidget {
  const AdminSongTab({super.key});

  @override
  State<AdminSongTab> createState() => _AdminSongTabState();
}

class _AdminSongTabState extends State<AdminSongTab> with AppBannerMixin {
  /// 0 = 오늘, 1 = 내일
  int _tabIndex = 0;

  bool _loading = true;
  List<MorningSong> _today = const [];
  List<MorningSong> _tomorrow = const [];

  /// 삭제 처리 중인 항목. 버튼을 잠가 중복 요청을 막는다.
  final Set<int> _busy = {};

  bool get _isToday => _tabIndex == 0;

  /// 지금 탭에서 보여줄 목록.
  List<MorningSong> get _songs => _isToday ? _today : _tomorrow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      // 탭을 옮길 때마다 다시 부르지 않도록 둘 다 받아 둔다.
      final results = await Future.wait([
        SongService.getToday(),
        SongService.getTomorrow(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0];
        _tomorrow = results[1];
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('플레이리스트를 불러오지 못했습니다.');
    }
  }

  Future<void> _delete(MorningSong song) async {
    if (_busy.contains(song.id)) return;

    final ok = await showConfirmDialog(
      context,
      title: '이 곡을 삭제할까요?',
      message: song.songName,
      confirmText: '삭제하기',
      destructive: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(song.id));
    try {
      await SongService.deleteByAdmin(song.id);
      if (!mounted) return;
      showSuccessBanner('곡을 삭제했습니다.');
      await _load(silent: true);
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (mounted) showErrorBanner(e.message);
    } catch (_) {
      if (mounted) showErrorBanner('삭제에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy.remove(song.id));
    }
  }

  /// '2026년 9월 26일' — 서버가 정한 재생 날짜를 그대로 보여준다.
  String get _dateLabel {
    final fallback = _isToday ? SongService.todayKst : SongService.tomorrowKst;
    final playDate = _songs.isNotEmpty ? _songs.first.playDate : fallback;
    final parts = playDate.split('-');
    if (parts.length != 3) return playDate;
    return '${parts[0]}년 ${int.parse(parts[1])}월 ${int.parse(parts[2])}일';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 머리말 ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          '기상송 관리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (!_loading)
                        Text(
                          '총 ${_songs.length}곡',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_dateLabel (${_isToday ? '오늘' : '내일'})',
                    style: TextStyle(fontSize: 13, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 오늘 / 내일 ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSegmentedTabs(
                index: _tabIndex,
                labels: const ['오늘 기상송', '내일 기상송'],
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 40),

            // ── 오늘만 재생, 내일은 확인용 ─────────────────────
            // 탭을 옮겨도 아래 목록이 흔들리지 않게 높이를 맞춘다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: SizedBox(
                height: _PlayAllButton.height,
                child: _isToday
                    // 버튼만 더 좁게. 안내 문구는 바깥 여백을 그대로 쓴다.
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: _PlayAllButton(
                          // 곡이 없으면 재생할 것도 없다. 플레이어는
                          // AdminScreen 에 상주해서 탭을 옮겨도 안 끊긴다.
                          onTap: _songs.isEmpty
                              ? null
                              : () => AdminPlayerScope.of(context).play(_songs),
                        ),
                      )
                    : const _TomorrowNotice(),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(child: _buildList(palette)),
          ],
        ),
        buildBanner(),
      ],
    );
  }

  Widget _buildList(AppPalette palette) {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (_, _) => const AppSkeleton(height: 56, radius: 6),
      );
    }

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          // 하단 네비게이션 바에 가리지 않도록 넉넉히 비운다.
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          sliver: _songs.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _isToday ? '오늘 나갈 곡이 없습니다.' : '내일 신청된 곡이 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                )
              : SliverList.separated(
                  itemCount: _songs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, i) {
                    final song = _songs[i];
                    return SongRow(
                      thumbnail: song.thumbnail,
                      title: song.songName,
                      // play_order 는 삭제로 구멍이 생기므로 목록 위치로 센다.
                      subtitle: '${i + 1}번째 재생',
                      // 오늘 곡은 이미 나가는 중이라 지울 일이 없다.
                      actionLabel: _isToday ? null : '삭제',
                      destructive: true,
                      busy: _busy.contains(song.id),
                      onAction: () => _delete(song),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 내일 곡은 아직 재생하지 않는다는 안내.
class _TomorrowNotice extends StatelessWidget {
  const _TomorrowNotice();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: palette.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '내일 나갈 곡입니다. 재생은 당일에 할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// 목록 전체를 순서대로 이어 재생하는 버튼.
class _PlayAllButton extends StatelessWidget {
  const _PlayAllButton({required this.onTap});

  /// 내일 탭의 안내 문구와 자리를 맞추는 데도 쓴다.
  static const height = 46.0;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppBrand.primary : palette.disabledButton,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 24,
              color: palette.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              '전체 재생',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
