import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_banner.dart';

class MeritLogScreen extends StatefulWidget {
  const MeritLogScreen({super.key});

  @override
  State<MeritLogScreen> createState() => _MeritLogScreenState();
}

class _MeritLogScreenState extends State<MeritLogScreen> with AppBannerMixin {
  int? _totalScore;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  // 0=전체 1=상점 2=벌점
  int _tabIndex = 0;

  static const _bgColor = AppColors.backB;
  static const _textColor = AppColors.mainText;
  static const _captionColor = AppColors.caption;
  static const _surfaceColor = AppColors.surfaceHover;
  static const _cardColor = AppColors.card;
  static const _bodyColor = AppColors.body;
  static const _teal = AppColors.mainColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthService.getMeritLogs(),
        AuthService.getMeritSummary(),
      ]);
      if (mounted) {
        setState(() {
          _logs = (results[0] as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _totalScore = results[1] as int;
          _loading = false;
        });
      }
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorBanner('불러오기 실패: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_tabIndex == 1)
      return _logs.where((l) => l['type'] == 'REWARD').toList();
    if (_tabIndex == 2)
      return _logs.where((l) => l['type'] == 'PENALTY').toList();
    return _logs;
  }

  // 날짜별로 연/월 그룹핑: {"2026-07": [log, ...], ...}
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final log in _filteredLogs) {
      final dt = DateTime.parse(log['created_at'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      (map[key] ??= []).add(log);
    }
    return map;
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    return '${parts[0]}년 ${int.parse(parts[1])}월';
  }

  String _dateLabel(String isoDate) {
    final dt = DateTime.parse(isoDate);
    final yy = dt.year.toString().substring(2);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: _textColor,
                size: 22,
              ),
            ),
          ),
        ),
        title: const Text(
          '상벌점 내역',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _teal))
          else
            Column(
              children: [
                // ── 현재 상벌점 카드 ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    height: 190,
                    padding: const EdgeInsets.fromLTRB(15, 25, 15, 15),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 10),
                            const Text(
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
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: _teal,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 15),
                        SizedBox(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  '상벌점 기준 안내',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _captionColor,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ],
                            ),
                          ),
                        ),
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
                        const Positioned(
                          left: 10,
                          right: 10,
                          bottom: 0,
                          child: Divider(
                            color: AppColors.body,
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
                            color: AppColors.mainColor,
                          ),
                        ),
                        // 탭 버튼들
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              _Tab(
                                label: '전체',
                                selected: _tabIndex == 0,
                                onTap: () => setState(() => _tabIndex = 0),
                              ),
                              _Tab(
                                label: '상점',
                                selected: _tabIndex == 1,
                                onTap: () => setState(() => _tabIndex = 1),
                              ),
                              _Tab(
                                label: '벌점',
                                selected: _tabIndex == 2,
                                onTap: () => setState(() => _tabIndex = 2),
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
                  child: _filteredLogs.isEmpty
                      ? Center(
                          child: Text(
                            '내역이 없습니다.',
                            style: TextStyle(color: _bodyColor, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
                          itemCount: _buildItems().length,
                          itemBuilder: (context, i) {
                            final item = _buildItems()[i];
                            if (item is String) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 34,
                                  bottom: 4,
                                ),
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _bodyColor,
                                  ),
                                ),
                              );
                            }
                            final log = item as Map<String, dynamic>;
                            final score = log['score'] as int;
                            final isReward = log['type'] == 'REWARD';
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log['reason'] as String,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: _textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _dateLabel(
                                                log['created_at'] as String,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _bodyColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            if (isReward)
                                              Text(
                                                '+$score점',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: _teal,
                                                ),
                                              )
                                            else
                                              Text(
                                                '$score점',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          buildBanner(),
        ],
      ),
    );
  }

  // 월 헤더 문자열과 로그를 섞은 flat list 생성
  List<dynamic> _buildItems() {
    final grouped = _grouped;
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <dynamic>[];
    for (final key in keys) {
      items.add(_monthLabel(key));
      items.addAll(grouped[key]!);
    }
    return items;
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
                  color: selected ? AppColors.mainColor : AppColors.body,
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
