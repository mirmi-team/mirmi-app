import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 알약이 미끄러지는 공통 세그먼트 탭.
///
/// ```dart
/// AppSegmentedTabs(
///   index: _tabIndex,
///   labels: const ['공지 사항', '건의사항'],
///   onChanged: (i) => setState(() => _tabIndex = i),
/// )
/// ```
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  static const _height = 50.0;
  static const _margin = 0.0;
  static const _borderWidth = 1.0;

  /// 선택된 탭 배경. 브랜드색 06B6D4 의 50%.
  static const _pillColor = Color(0x8006B6D4);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: palette.borderSubtle, width: _borderWidth),
      ),
      // LayoutBuilder 를 Container 안에 둔다. 바깥에 두면 테두리 두께만큼
      // 좁아진 실제 너비를 모르고 탭 폭을 계산해, 마지막 알약이 잘린다.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: index * tabWidth + _margin,
                top: _margin,
                bottom: _margin,
                width: tabWidth - _margin * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: _pillColor,
                    borderRadius: BorderRadius.circular(_height / 2 - _margin),
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final selected = index == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? palette.textPrimary
                                : palette.textTertiary,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
