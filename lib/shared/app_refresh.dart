import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 로딩 스피너 공통 규격.
const double _indicatorSize = 22.0;
const double _strokeWidth = 2.2;

/// 앱 공통 로딩 스피너.
///
/// 기본 생성자는 화면 전체 로딩용으로, 가운데에 테마 색으로 표시한다.
/// [AppLoadingIndicator.onButton]은 컬러 버튼 위에 얹는 작은 흰색 스피너다.
///
/// ```dart
/// if (_loading) return const AppLoadingIndicator();
///
/// ElevatedButton(
///   child: _loading ? const AppLoadingIndicator.onButton() : const Text('로그인'),
/// )
/// ```
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size, this.strokeWidth})
    : color = AppColors.mainColor,
      _centered = true;

  /// 컬러 버튼 위에 얹는 작은 흰색 스피너.
  ///
  /// 버튼이 이미 자식을 가운데 정렬하므로 [Center]로 감싸지 않는다.
  /// (감싸면 버튼의 콘텐츠 크기 계산이 달라진다.)
  const AppLoadingIndicator.onButton({super.key})
    : size = _indicatorSize,
      strokeWidth = 2,
      color = Colors.white,
      _centered = false;

  /// null이면 Material 기본 크기.
  final double? size;
  final double? strokeWidth;
  final Color color;
  final bool _centered;

  @override
  Widget build(BuildContext context) {
    Widget indicator = CircularProgressIndicator(
      strokeWidth: strokeWidth ?? 4.0,
      color: color,
    );
    if (size != null) {
      indicator = SizedBox(width: size, height: size, child: indicator);
    }
    return _centered ? Center(child: indicator) : indicator;
  }
}

/// 당겨서 새로고침이 되는 공통 스크롤뷰.
///
/// Material [RefreshIndicator]는 스피너를 목록 위에 겹쳐 띄우고 목록은 곧바로
/// 제자리로 돌려보낸다. 여기서는 [CupertinoSliverRefreshControl]을 써서 새로고침이
/// 끝날 때까지 목록을 내려둔 채 유지한다.
///
/// ```dart
/// AppRefreshScrollView(
///   onRefresh: () => _load(silent: true),
///   slivers: [
///     SliverPadding(
///       padding: const EdgeInsets.all(20),
///       sliver: SliverList(delegate: SliverChildListDelegate([...])),
///     ),
///   ],
/// )
/// ```
class AppRefreshScrollView extends StatefulWidget {
  const AppRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.triggerPullDistance = 110,
    this.indicatorExtent = 62,
    this.minSpinDuration = const Duration(milliseconds: 800),
  });

  /// 새로고침 작업. 이 Future가 끝나면 목록이 제자리로 돌아간다.
  final Future<void> Function() onRefresh;

  /// 인디케이터 아래에 올 sliver들.
  final List<Widget> slivers;

  /// 새로고침이 걸리는 당김 거리.
  final double triggerPullDistance;

  /// 새로고침 중 목록이 내려가 있는 높이.
  final double indicatorExtent;

  /// 최소 회전 시간.
  ///
  /// [CupertinoSliverRefreshControl]은 손을 뗀 뒤 목록이 [indicatorExtent]로
  /// 돌아오는 동안에도 armed 상태이고, 그 사이에 작업이 끝나면 refresh 단계를
  /// 건너뛰고 곧장 done으로 간다. 응답이 빠른 API에서는 회전이 한 번도 보이지
  /// 않으므로 최소 시간을 두어 refresh 단계를 반드시 거치게 한다.
  final Duration minSpinDuration;

  @override
  State<AppRefreshScrollView> createState() => _AppRefreshScrollViewState();
}

class _AppRefreshScrollViewState extends State<AppRefreshScrollView> {
  /// 손가락이 화면에 닿아있는 동안만 true.
  ///
  /// 드래그 중에는 알림에 dragDetails가 실려오고, 손을 뗀 뒤 튕겨 돌아가는
  /// (ballistic) 구간에서는 null이므로 이것으로 릴리즈 시점을 알 수 있다.
  /// [CupertinoSliverRefreshControl]의 builder는 LayoutBuilder 안에서 매 프레임
  /// 다시 도므로 setState 없이 필드만 갱신하면 된다. (스크롤 알림은 레이아웃 도중에
  /// 올 수 있어 setState를 호출하면 예외가 난다.)
  bool _dragging = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      final details = notification is ScrollStartNotification
          ? notification.dragDetails
          : (notification as ScrollUpdateNotification).dragDetails;
      _dragging = details != null;
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
    }
    return false; // 알림은 계속 위로 전파
  }

  Future<void> _handleRefresh() async {
    await Future.wait<void>([
      widget.onRefresh(),
      Future<void>.delayed(widget.minSpinDuration),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: CustomScrollView(
        // Android 기본값인 ClampingScrollPhysics는 오버스크롤을 막아
        // CupertinoSliverRefreshControl이 아예 뜨지 않는다.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            refreshTriggerPullDistance: widget.triggerPullDistance,
            refreshIndicatorExtent: widget.indicatorExtent,
            onRefresh: _handleRefresh,
            builder: _buildIndicator,
          ),
          ...widget.slivers,
        ],
      ),
    );
  }

  /// 당기는 중에는 당긴 만큼 차오르고, 손을 놓은 뒤부터 회전한다.
  Widget _buildIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    // done은 인디케이터 높이가 0으로 접히는 구간이다. 이때 스피너를 계속 그리면
    // 원이 납작하게 눌려 가로줄 같은 잔상이 남으므로 아예 그리지 않는다.
    //
    // 손이 닿아있지 않은데 drag인 경우는 사용자가 당기는 게 아니라, 새로고침이
    // 끝나고 목록이 제자리로 튕겨 돌아오는 반동 구간이다. (인디케이터가 접히면서
    // 스크롤이 보정될 때 높이가 잠깐 0보다 커져 inactive → drag로 되돌아간다.)
    // 여기서 그리면 스피너가 올라간 목록 틈으로 잠깐 비친다.
    if (mode == RefreshIndicatorMode.inactive ||
        mode == RefreshIndicatorMode.done ||
        (mode == RefreshIndicatorMode.drag && !_dragging)) {
      return const SizedBox.shrink();
    }

    // armed는 "트리거를 넘긴 채 아직 당기는 중"과 "손을 떼고 되돌아가는 중"을
    // 모두 포함한다. 후자는 이미 새로고침이 도는 구간이므로 손을 뗐는지로 갈라서,
    // 놓는 즉시 회전이 시작되고 꽉 찬 채 멈춰있는 구간이 없도록 한다.
    final spinning =
        mode == RefreshIndicatorMode.refresh ||
        (mode == RefreshIndicatorMode.armed && !_dragging);

    final Widget spinner;
    if (spinning) {
      spinner = const CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        color: AppColors.mainColor,
      );
    } else {
      // armed에서 pulledExtent로 계산하면 되돌아가는 동안 진행률이
      // indicatorExtent / triggerPullDistance로 줄어 원이 절반으로 되돌아가므로
      // 꽉 찬 값으로 고정한다.
      final progress = mode == RefreshIndicatorMode.armed
          ? 1.0
          : (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
      spinner = CircularProgressIndicator(
        value: progress,
        strokeWidth: _strokeWidth,
        color: AppColors.mainColor,
        backgroundColor: AppColors.border,
      );
    }

    // 인디케이터 영역은 가로가 tight, 세로는 남은 높이로 제한되어 들어온다.
    // 양축을 모두 풀어줘야 스피너가 가로로 늘어나거나 세로로 눌리지 않는다.
    return ClipRect(
      child: OverflowBox(
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: Alignment.center,
        child: SizedBox(
          width: _indicatorSize,
          height: _indicatorSize,
          child: spinner,
        ),
      ),
    );
  }
}
