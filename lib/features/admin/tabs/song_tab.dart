import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/song_service.dart';
import '../../../shared/app_banner.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/app_dialog.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_refresh.dart';
import '../../../shared/app_skeleton.dart';
import '../../song/song_row.dart';
import '../admin_player.dart';

/// 기상송 관리. 내일 나갈 플레이리스트를 확인하고, 이어 재생하고, 지운다.
class AdminSongTab extends StatefulWidget {
  const AdminSongTab({super.key});

  @override
  State<AdminSongTab> createState() => _AdminSongTabState();
}

class _AdminSongTabState extends State<AdminSongTab> with AppBannerMixin {
  bool _loading = true;
  List<MorningSong> _songs = const [];

  /// 삭제 처리 중인 항목. 버튼을 잠가 중복 요청을 막는다.
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final songs = await SongService.getTomorrow();
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
    final playDate = _songs.isNotEmpty
        ? _songs.first.playDate
        : SongService.tomorrowKst;
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
                    '$_dateLabel (내일)',
                    style: TextStyle(fontSize: 13, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 전체 재생 ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: _PlayAllButton(
                // 곡이 없으면 재생할 것도 없다.
                // 플레이어는 AdminScreen 에 상주한다. 탭을 옮겨도 안 끊긴다.
                onTap: _songs.isEmpty
                    ? null
                    : () => AdminPlayerScope.of(context).play(_songs),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: _songs.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '신청된 곡이 없습니다.',
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
                      actionLabel: '삭제',
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

/// 목록 전체를 순서대로 이어 재생하는 버튼.
class _PlayAllButton extends StatelessWidget {
  const _PlayAllButton({required this.onTap});

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
        padding: const EdgeInsets.symmetric(vertical: 11),
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
