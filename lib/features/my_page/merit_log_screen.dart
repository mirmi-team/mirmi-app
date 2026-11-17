import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/student_service.dart';
import '../../shared/app_banner.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_palette.dart';
import '../../shared/app_refresh.dart';
import '../../shared/app_sub_page_bar.dart';
import '../../shared/date_format.dart';
import '../../shared/merit_style.dart';

/// 관리자가 남의 내역을 열 때 넘기는 정보.
///
/// 누적 점수는 서버에 관리자용 요약 엔드포인트가 없어서 호출한 쪽이 들고 온다.
/// (학생 목록에 이미 실려 있는 값이라 한 번 더 받을 이유도 없다)
class MeritLogTarget {
  const MeritLogTarget({
    required this.userId,
    required this.name,
    required this.totalScore,
  });

  final int userId;
  final String name;
  final int totalScore;
}

/// 상벌점 내역.
///
/// [target] 이 없으면 내 내역, 있으면 관리자가 그 학생의 내역을 보는 것이다.
/// 두 경우가 화면이 같아서 한 화면으로 쓴다.
class MeritLogScreen extends StatefulWidget {
  const MeritLogScreen({super.key, this.target});

  final MeritLogTarget? target;

  @override
  State<MeritLogScreen> createState() => _MeritLogScreenState();
}

class _MeritLogScreenState extends State<MeritLogScreen> with AppBannerMixin {
  int? _totalScore;
  List<MeritLogEntry> _logs = const [];
  bool _loading = true;

  /// 0=전체 1=상점 2=벌점
  int _tabIndex = 0;

  AppPalette get _palette => AppPalette.of(context);
  Color get _textColor => _palette.textPrimary;
  Color get _captionColor => _palette.textTertiary;
  Color get _cardColor => _palette.bgSurface;
  Color get _bodyColor => _palette.textSecondary;

  /// 관리자가 남의 내역을 보는 중인지.
  bool get _isAdminView => widget.target != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final target = widget.target;
      if (target != null) {
        final logs = await StudentService.getMeritLogs(target.userId);
        if (!mounted) return;
        setState(() {
          _logs = logs;
          _totalScore = target.totalScore;
          _loading = false;
        });
        return;
      }

      final results = await Future.wait([
        AuthService.getMeritLogs(),
        AuthService.getMeritSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _logs = (results[0] as List<dynamic>)
            .map((e) => MeritLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalScore = results[1] as int;
        _loading = false;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('불러오기 실패: $e');
    }
  }

  List<MeritLogEntry> get _filteredLogs {
    if (_tabIndex == 1) return _logs.where((l) => l.isReward).toList();
    if (_tabIndex == 2) return _logs.where((l) => !l.isReward).toList();
    return _logs;
  }

  /// 날짜별로 연/월 그룹핑: {"2026-07": [log, ...], ...}
  Map<String, List<MeritLogEntry>> get _grouped {
    final map = <String, List<MeritLogEntry>>{};
    for (final log in _filteredLogs) {
      (map[monthKey(log.createdAt)] ??= []).add(log);
    }
    return map;
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    return '${parts[0]}년 ${int.parse(parts[1])}월';
  }

  String _dateLabel(DateTime dt) {
    final yy = dt.year.toString().substring(2);
    return '$yy.${twoDigit(dt.month)}.${twoDigit(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색은 ThemeData.scaffoldBackgroundColor 가 정한다.
      appBar: AppSubPageBar(
        title: widget.target == null ? '상벌점 내역' : widget.target!.name,
      ),
      body: Stack(
        children: [
          if (_loading)
            const AppLoadingIndicator()
          else
            Column(
              children: [
                // ── 현재 상벌점 카드 ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    // 관리자 화면에는 '기준 안내' 줄이 없다. 높이를 따로 박으면
                    // 글꼴 크기에 따라 몇 픽셀씩 넘치므로 내용에 맞춰 늘어나게
                    // 둔다. (학생 화면은 Spacer 로 안내 줄을 바닥에 붙여야 해서
                    // 높이가 정해져 있어야 한다)
                    height: _isAdminView ? null : 190,
                    padding: const EdgeInsets.fromLTRB(15, 25, 15, 15),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      // 높이가 없으면 꽉 채울 수 없다. 학생 화면은 Spacer 가
                      // 있어 max 그대로 둔다.
                      mainAxisSize: _isAdminView
                          ? MainAxisSize.min
                          : MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 10),
                            Text(
                              '현재 상벌점',
                              style: TextStyle(
                                fontSize: 16,
                                color: _textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const SizedBox(width: 10),
                            Text(
                              '${_totalScore ?? 0} 점',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                // 내 화면은 예전부터 청록 한 색이었다. 관리자
                                // 목록은 부호로 색을 갈라 보여주므로 거기서
                                // 넘어왔을 때 색이 달라지지 않도록 맞춘다.
                                color: _isAdminView
                                    ? meritColor(_totalScore ?? 0, _palette)
                                    : AppBrand.primary,
                              ),
                            ),
                          ],
                        ),
                        if (!_isAdminView) ...[
                          const Spacer(),
                          Divider(color: _palette.borderSubtle, height: 1),
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '상벌점 기준 안내',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _captionColor,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: _textColor,
                                  size: 30,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 탭 (전체 / 상점 / 벌점) ──────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = (constraints.maxWidth - 20) / 3;
                    return Stack(
                      children: [
                        // 전체 구분선
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 0,
                          child: Divider(
                            color: _bodyColor,
                            height: 1,
                            thickness: 1,
                          ),
                        ),
                        // 슬라이딩 인디케이터
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          left: 10 + _tabIndex * tabWidth,
                          bottom: 0,
                          child: Container(
                            width: tabWidth,
                            height: 2,
                            color: AppBrand.primary,
                          ),
                        ),
                        // 탭 버튼들
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              for (var i = 0; i < 3; i++)
                                _Tab(
                                  label: const ['전체', '상점', '벌점'][i],
                                  selected: _tabIndex == i,
                                  onTap: () => setState(() => _tabIndex = i),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // ── 내역 리스트 ───────────────────────────────────
                Expanded(
                  child: AppRefreshScrollView(
                    onRefresh: () => _load(silent: true),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
                        sliver: _filteredLogs.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    '내역이 없습니다.',
                                    style: TextStyle(
                                      color: _bodyColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : SliverList.builder(
                                itemCount: _items.length,
                                itemBuilder: (context, i) {
                                  final item = _items[i];
                                  if (item is String) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: 34,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _bodyColor,
                                        ),
                                      ),
                                    );
                                  }
                                  return _logRow(item as MeritLogEntry);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          buildBanner(),
        ],
      ),
    );
  }

  Widget _logRow(MeritLogEntry log) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.reason,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateLabel(log.createdAt),
                    style: TextStyle(fontSize: 12, color: _bodyColor),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                meritLabel(log.score),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: meritColor(log.score, _palette),
                ),
              ),
            ),
          ],
        ),
      ),
      Divider(color: _palette.borderSubtle, height: 1),
    ],
  );

  /// 월 머리글(String)과 내역(MeritLogEntry)을 한 줄로 늘어놓은 목록.
  List<Object> get _items {
    final grouped = _grouped;
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys) ...[_monthLabel(key), ...grouped[key]!],
    ];
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppBrand.primary : palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
