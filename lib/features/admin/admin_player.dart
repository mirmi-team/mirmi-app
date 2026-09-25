import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/services/song_service.dart';
import '../../shared/app_colors.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/app_palette.dart';
import '../song/song_player_sheet.dart' show youtubeVideoId;

/// 기상송 이어 재생 상태.
///
/// 플레이어(WebView)는 화면이 바뀌어도 살아 있어야 하므로 [AdminScreen] 의
/// Stack 에 상주한다. 시트로 띄우면 내리는 순간 dispose 되어 소리가 끊긴다.
/// 이 컨트롤러는 그 플레이어를 어느 탭에서든 켜고 끌 수 있게 해준다.
class AdminPlayerController extends ChangeNotifier {
  /// 재생 목록. 비어 있으면 플레이어를 띄우지 않는다.
  List<MorningSong> songs = const [];

  /// 재생 목록에 실제로 올라간 videoId. songs 와 같은 순서다.
  List<String> videoIds = const [];

  /// 큰 화면인지. false 면 네비게이션 바 위 작은 바로 접힌다.
  bool expanded = false;

  /// 지금 재생 중인 곡의 위치.
  int current = 0;

  /// 재생 중인지. 재생/일시정지 버튼 모양을 정한다.
  bool isPlaying = false;

  YoutubePlayerController? youtube;
  StreamSubscription<YoutubePlayerValue>? _sub;

  bool get isOpen => songs.isNotEmpty;

  MorningSong? get currentSong =>
      current < songs.length ? songs[current] : null;

  /// 목록을 걸고 1번 곡부터 이어 재생한다.
  void play(List<MorningSong> list) {
    final playable = [
      for (final song in list)
        if (youtubeVideoId(song.youtubeUrl) != null) song,
    ];
    if (playable.isEmpty) return;

    songs = playable;
    videoIds = [for (final s in playable) youtubeVideoId(s.youtubeUrl)!];
    current = 0;
    // 큰 창을 바로 띄우지 않는다. 작은 바로 시작해서 필요할 때 펼친다.
    expanded = false;

    // 이미 플레이어가 떠 있으면 목록만 갈아 끼우고 1번 곡부터 다시 튼다.
    // 컨트롤러를 새로 만들면 WebView 가 다시 생성되면서 재생이 멈춰버린다.
    final existing = youtube;
    if (existing != null) {
      existing.loadPlaylist(
        list: videoIds,
        listType: ListType.playlist,
        index: 0,
      );
      WakelockPlus.enable();
      notifyListeners();
      return;
    }

    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        // 유튜브 기본 컨트롤은 끄고 아래 버튼으로만 조작한다.
        // 작게 접었을 때 영상 위에 재생 버튼이 겹쳐 보이는 걸 막는다.
        showControls: false,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        // 영상 위 터치를 iframe 안에서부터 막는다. Flutter 쪽 AbsorbPointer
        // 만으로는 플랫폼 뷰가 터치를 먼저 받아 유튜브 오버레이(정지·다음·
        // 전체화면)가 떠버린다.
        pointerEvents: PointerEvents.none,
      ),
    );
    youtube = controller;

    _sub = controller.listen((value) {
      var changed = false;

      final id = value.metaData.videoId;
      if (id.isNotEmpty) {
        final index = videoIds.indexOf(id);
        if (index >= 0 && index != current) {
          current = index;
          changed = true;
        }
      }

      final playing = value.playerState == PlayerState.playing;
      if (playing != isPlaying) {
        isPlaying = playing;
        changed = true;
      }

      if (changed) notifyListeners();
    });

    // 재생 중 화면이 꺼지면 방송이 끊긴다.
    WakelockPlus.enable();
    controller.loadPlaylist(list: videoIds, listType: ListType.playlist);
    notifyListeners();
  }

  void setExpanded(bool value) {
    if (expanded == value) return;
    expanded = value;
    notifyListeners();
  }

  void togglePlay() {
    final controller = youtube;
    if (controller == null) return;
    isPlaying ? controller.pauseVideo() : controller.playVideo();
  }

  /// 재생을 끝내고 플레이어를 내린다.
  void close() {
    _disposePlayer();
    songs = const [];
    videoIds = const [];
    current = 0;
    expanded = false;
    notifyListeners();
  }

  void _disposePlayer() {
    _sub?.cancel();
    _sub = null;
    youtube?.close();
    youtube = null;
    isPlaying = false;
    WakelockPlus.disable();
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}

/// 하위 탭이 재생을 요청할 수 있도록 컨트롤러를 내려보낸다.
class AdminPlayerScope extends InheritedNotifier<AdminPlayerController> {
  const AdminPlayerScope({
    super.key,
    required AdminPlayerController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminPlayerController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AdminPlayerScope>();
    assert(scope != null, 'AdminPlayerScope 안에서만 쓸 수 있다');
    return scope!.notifier!;
  }
}

/// 화면 위에 떠 있는 플레이어. 접으면 네비게이션 바 위 작은 바가 된다.
///
/// 펼치든 접든 [YoutubePlayer] 는 아래 하나뿐인 무대(stage) 안에 머문다.
/// 부모가 바뀌면 WebView 가 새로 만들어져 처음부터 다시 재생되기 때문이다.
class AdminPlayerOverlay extends StatefulWidget {
  const AdminPlayerOverlay({super.key, required this.controller});

  final AdminPlayerController controller;

  @override
  State<AdminPlayerOverlay> createState() => _AdminPlayerOverlayState();
}

class _AdminPlayerOverlayState extends State<AdminPlayerOverlay>
    with SingleTickerProviderStateMixin {
  /// 접혔을 때 영상 크기. 목록 썸네일처럼 정사각형으로 잘라 보여준다.
  static const _miniVideoSize = 34.0;
  static const _miniBarHeight = 58.0;

  /// 접힌 바의 좌우 여백. 네비게이션 바와 같은 값이라 세로로 줄이 맞는다.
  static const _miniSideMargin = 20.0;

  /// 알약 모양이라 왼쪽 끝이 둥글다. 영상이 테두리에 닿지 않도록 띄운다.
  static const _miniVideoLeft = 15.0;

  /// 작은 바와 네비게이션 바 사이 간격.
  static const _miniBarGap = 12.0;

  /// 펼쳤을 때 영상 위에 남겨두는 손잡이 높이.
  static const _handleHeight = 40.0;

  /// 이만큼 아래로 당기면 접는다.
  static const _collapseThreshold = 70.0;

  static const _duration = Duration(milliseconds: 460);
  static const _curve = Curves.easeOutCubic;

  final _scroll = ScrollController();

  /// 목록을 올린 만큼 영상도 같이 올라간다.
  double _offset = 0;

  /// 맨 위에서 아래로 당긴 거리. 창 전체가 이만큼 내려간다.
  double _dragDown = 0;

  /// 덜 내렸을 때 제자리로 돌아가는 시간.
  static const _settleBackDuration = Duration(milliseconds: 240);

  /// 손을 놓았을 때 드래그 보정을 되돌리는 애니메이션.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: _settleBackDuration,
  );
  double _settleFrom = 0;

  /// 당겨서 접는 처리를 한 번만 하도록.
  bool _collapsing = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final next = _scroll.hasClients ? _scroll.offset : 0.0;
      if ((next - _offset).abs() > 0.5) setState(() => _offset = next);
    });
    _settle.addListener(() {
      final t = _curve.transform(_settle.value);
      setState(() => _dragDown = _settleFrom * (1 - t));
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 당기던 손을 놓았을 때. 충분히 내렸으면 접고, 아니면 제자리로.
  void _releaseDrag() {
    if (_dragDown <= 0) return;
    _settleFrom = _dragDown;

    if (_dragDown > _collapseThreshold) {
      // 여기서 _dragDown 을 0 으로 되돌리면 창이 원래 자리로 한 번 튕긴 뒤
      // 작은 바로 내려간다. 접히는 애니메이션과 같은 시간에 걸쳐 서서히
      // 녹여 없애야 손을 놓은 자리에서 그대로 이어진다.
      _settle.duration = _duration;
      _collapsing = true;
      widget.controller.setExpanded(false);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _collapsing = false);
    } else {
      _settle.duration = _settleBackDuration;
    }
    _settle.forward(from: 0);
  }

  void _collapse() {
    if (_collapsing) return;
    _collapsing = true;
    _dragDown = 0;
    widget.controller.setExpanded(false);
    // 다시 펼쳤을 때 맨 위부터 보이도록 되돌린다.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _collapsing = false);
  }

  /// 목록 맨 위에서 더 당기면 창 전체가 손을 따라 움직인다.
  ///
  /// ScrollNotification 으로는 내리는 것만 잡힌다. 누른 채 다시 올리면
  /// 목록이 먼저 스크롤돼서 창이 안 따라오므로 포인터를 직접 본다.
  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.controller.expanded) return;
    final atTop = !_scroll.hasClients || _scroll.position.pixels <= 0;
    final dy = event.delta.dy;

    // 이미 내려와 있으면 방향과 상관없이 손을 따라간다.
    if (_dragDown <= 0 && !(atTop && dy > 0)) return;

    _settle.stop();
    setState(() => _dragDown = (_dragDown + dy).clamp(0.0, double.infinity));

    // 창을 끌고 있는 동안에는 목록이 같이 움직이지 않게 묶어 둔다.
    if (_dragDown > 0 && _scroll.hasClients && _scroll.offset != 0) {
      _scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final youtube = controller.youtube;
    if (!controller.isOpen || youtube == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;

    final expanded = controller.expanded;
    final navTotal = appNavBarTotalHeight(context);

    // 무대(패널) 자리. 펼치면 화면 아래 85%, 접으면 네비게이션 바 위 작은 바.
    final stageH = expanded ? screenH * 0.85 : _miniBarHeight;
    final stageTop = expanded
        ? screenH - stageH
        : screenH - navTotal - _miniBarHeight - _miniBarGap;
    final stageW = expanded ? screenW : screenW - _miniSideMargin * 2;

    // 무대 안에서의 영상 자리.
    //
    // 접히면 1px 로 줄인다. WebView 는 플랫폼 뷰라 Flutter 위젯보다 위에
    // 그려져서, 썸네일로 덮어도 영상이 비친다. 크기를 없애는 게 확실하다.
    // (0 으로 만들면 재생이 멈출 수 있어 1px 은 남겨 둔다)
    final videoW = expanded ? stageW : 1.0;
    final videoH = expanded ? stageW * 9 / 16 : 1.0;
    final videoLeft = expanded ? 0.0 : _miniVideoLeft + _miniVideoSize / 2;
    final videoTop = expanded ? _handleHeight : _miniBarHeight / 2;

    return Stack(
      children: [
        // ── 어두운 배경 (펼쳤을 때만) ─────────────────────────
        Positioned.fill(
          key: const ValueKey('admin-player-scrim'),
          child: IgnorePointer(
            ignoring: !expanded,
            child: GestureDetector(
              onTap: _collapse,
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: _duration,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),

        // ── 무대 ──────────────────────────────────────────────
        // 영상과 내용이 전부 이 안에 있다. 자리만 움직이고 안은 그대로다.
        AnimatedPositioned(
          key: const ValueKey('admin-player-stage'),
          duration: _duration,
          curve: _curve,
          left: expanded ? 0 : _miniSideMargin,
          width: stageW,
          top: stageTop,
          height: stageH,
          // top 을 직접 바꾸면 AnimatedPositioned 가 손가락보다 늦게 따라온다.
          child: Transform.translate(
            offset: Offset(0, _dragDown),
            // 목록이 아니라 창 전체가 손을 따라 움직여야 해서 포인터를
            // 직접 받는다. Listener 는 이벤트를 가로채지 않아 목록 스크롤과
            // 버튼은 그대로 동작한다.
            child: Listener(
              onPointerMove: _onPointerMove,
              onPointerUp: (_) => _releaseDrag(),
              onPointerCancel: (_) => _releaseDrag(),
              child: _Stage(
                controller: controller,
                expanded: expanded,
                scroll: _scroll,
                onCollapse: _collapse,
                videoRect: Rect.fromLTWH(videoLeft, videoTop, videoW, videoH),
                // 스크롤은 애니메이션 없이 그대로 따라가야 목록과 같이 움직인다.
                scrollOffset: expanded ? _offset : 0,
                miniRadius: _miniBarHeight / 2,
                // 영상 오른쪽부터 제목이 시작한다. 펼쳐도 값이 흔들리지
                // 않도록 접힌 상태 기준으로 고정한다.
                miniContentLeft: _miniVideoLeft + _miniVideoSize + 10,
                // 썸네일은 영상과 따로 논다. (영상은 접히면 1px 로 줄어든다)
                thumbnailRect: Rect.fromLTWH(
                  _miniVideoLeft,
                  (_miniBarHeight - _miniVideoSize) / 2,
                  _miniVideoSize,
                  _miniVideoSize,
                ),
                handleHeight: _handleHeight,
                duration: _duration,
                curve: _curve,
                onExpand: () => controller.setExpanded(true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 플레이어가 머무는 하나뿐인 무대.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.expanded,
    required this.scroll,
    required this.onCollapse,
    required this.videoRect,
    required this.scrollOffset,
    required this.miniRadius,
    required this.miniContentLeft,
    required this.thumbnailRect,
    required this.handleHeight,
    required this.duration,
    required this.curve,
    required this.onExpand,
  });

  final AdminPlayerController controller;
  final bool expanded;
  final ScrollController scroll;
  final VoidCallback onCollapse;
  final Rect videoRect;

  /// 목록을 올린 높이. 영상도 같은 만큼 올라간다.
  final double scrollOffset;

  /// 접혔을 때 모서리 반경. 높이의 절반이라 완전한 알약이 된다.
  final double miniRadius;

  /// 접혔을 때 제목이 시작하는 x 좌표.
  final double miniContentLeft;

  /// 접혔을 때 썸네일이 놓이는 자리.
  final Rect thumbnailRect;

  final double handleHeight;
  final Duration duration;
  final Curve curve;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final youtube = controller.youtube!;
    final nav = appNavColors(context);
    final thumbnail = controller.currentSong?.thumbnail;
    final radius = BorderRadius.vertical(
      top: Radius.circular(expanded ? 20 : miniRadius),
      bottom: Radius.circular(expanded ? 0 : miniRadius),
    );

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      decoration: BoxDecoration(
        // 접히면 네비게이션 바와 똑같은 반투명 유리색이 된다.
        color: expanded ? palette.bgSurface : nav.bar,
        borderRadius: radius,
        border: expanded ? null : Border.all(color: nav.barBorder, width: 1.0),
        boxShadow: expanded
            ? null
            : [
                BoxShadow(
                  color: nav.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // ── 펼쳤을 때의 내용 (영상 자리는 비워 둔다) ─────
            Positioned.fill(
              key: const ValueKey('admin-player-body'),
              child: IgnorePointer(
                ignoring: !expanded,
                child: AnimatedOpacity(
                  opacity: expanded ? 1 : 0,
                  duration: duration,
                  child: _ExpandedBody(
                    controller: controller,
                    scroll: scroll,
                    onCollapse: onCollapse,
                    topSpace: handleHeight + videoRect.height,
                  ),
                ),
              ),
            ),

            // ── 영상 ─────────────────────────────────────────
            // 무대 안에서 자리만 바뀐다. 부모가 그대로라 WebView 가 산다.
            AnimatedPositioned(
              key: const ValueKey('admin-player-video'),
              duration: duration,
              curve: curve,
              left: videoRect.left,
              top: videoRect.top,
              width: videoRect.width,
              height: videoRect.height,
              child: Transform.translate(
                // top 을 직접 바꾸면 AnimatedPositioned 가 그것마저 애니메이션해
                // 목록보다 한 박자 늦게 따라온다. 변환은 즉시 반영된다.
                offset: Offset(0, -scrollOffset),
                child: GestureDetector(
                  // 접힌 상태에서 영상을 누르거나 위로 쓸어올리면 펼친다.
                  onTap: expanded ? null : onExpand,
                  onVerticalDragEnd: expanded
                      ? null
                      : (d) {
                          if ((d.primaryVelocity ?? 0) < -100) onExpand();
                        },
                  child: AbsorbPointer(
                    child: YoutubePlayer(
                      controller: youtube,
                      aspectRatio: 16 / 9,
                    ),
                  ),
                ),
              ),
            ),

            // ── 접힌 바의 썸네일 ────────────────────────────
            // 영상 대신 보여준다. 소리는 1px 로 줄어든 영상이 계속 낸다.
            Positioned(
              key: const ValueKey('admin-player-thumb'),
              left: thumbnailRect.left,
              top: thumbnailRect.top,
              width: thumbnailRect.width,
              height: thumbnailRect.height,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: expanded ? 0 : 1,
                  duration: duration,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbnail == null || thumbnail.isEmpty
                        ? ColoredBox(color: palette.borderSubtle)
                        : Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: palette.borderSubtle),
                          ),
                  ),
                ),
              ),
            ),

            // ── 접힌 바의 제목·버튼 ──────────────────────────
            Positioned(
              key: const ValueKey('admin-player-mini'),
              left: miniContentLeft,
              right: 10,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: expanded,
                child: AnimatedOpacity(
                  opacity: expanded ? 0 : 1,
                  duration: duration,
                  child: _MiniControls(
                    controller: controller,
                    onExpand: onExpand,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 펼쳤을 때 한 덩어리로 스크롤되는 본문.
///
/// 맨 위 [topSpace] 는 손잡이와 영상이 겹쳐 그려지는 자리라 비워 둔다.
/// 스크롤하면 영상도 같이 올라간다.
class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.controller,
    required this.scroll,
    required this.onCollapse,
    required this.topSpace,
  });

  final AdminPlayerController controller;
  final ScrollController scroll;
  final VoidCallback onCollapse;
  final double topSpace;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final youtube = controller.youtube!;

    return CustomScrollView(
      controller: scroll,
      // 내용이 짧아도 당겨서 접을 수 있도록 항상 스크롤을 허용한다.
      // 튕기면 목록만 늘어난다. 당긴 만큼 창 전체가 내려가도록
      // overscroll 알림을 주는 Clamping 을 쓴다.
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        // 손잡이 + 영상이 놓이는 자리
        SliverToBoxAdapter(
          child: SizedBox(
            height: topSpace,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCollapse,
                child: SizedBox(
                  height: 40,
                  width: 80,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 재생 위치 ────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ProgressBar(
            // 곡이 바뀌면 길이를 다시 읽어야 한다.
            key: ValueKey(controller.current),
            youtube: youtube,
          ),
        ),

        // ── 이동 버튼 ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIconButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: youtube.previousVideo,
                ),
                const SizedBox(width: 12),
                _RoundIconButton(
                  icon: controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 34,
                  onTap: controller.togglePlay,
                ),
                const SizedBox(width: 12),
                _RoundIconButton(
                  icon: Icons.skip_next_rounded,
                  onTap: youtube.nextVideo,
                ),
                const SizedBox(width: 16),
                Text(
                  '${controller.current + 1} / ${controller.songs.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Divider(color: palette.borderSubtle, height: 1),
        ),

        // ── 재생 목록 ────────────────────────────────────────
        SliverList.builder(
          itemCount: controller.songs.length,
          itemBuilder: (context, i) {
            final playing = i == controller.current;
            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 24,
                child: playing
                    ? const Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: AppBrand.primary,
                      )
                    : Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textTertiary,
                        ),
                      ),
              ),
              title: Text(
                controller.songs[i].songName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: playing ? FontWeight.w700 : FontWeight.w400,
                  color: playing ? AppBrand.primary : palette.textPrimary,
                ),
              ),
              // 재생 중인 곡을 다시 누르면 처음으로 돌아가버린다.
              onTap: playing ? null : () => youtube.playVideoAt(i),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

/// 재생 위치와 영상 길이. 끌어서 원하는 지점으로 보낼 수 있다.
///
/// 유튜브 기본 컨트롤을 껐기 때문에(작은 바에서 재생 버튼이 겹쳐 보여서)
/// 길이 표시가 같이 사라졌다. 그 자리를 대신한다.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({super.key, required this.youtube});

  final YoutubePlayerController youtube;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  StreamSubscription<YoutubeVideoState>? _sub;

  Duration _position = Duration.zero;

  /// 영상 전체 길이(초). 아직 못 읽었으면 0.
  double _duration = 0;

  /// 손으로 끄는 중인 값. 놓을 때까지 재생 위치 대신 이걸 보여준다.
  double? _dragging;

  @override
  void initState() {
    super.initState();
    _sub = widget.youtube.videoStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _position = state.position);
      // 곡이 막 바뀌면 길이가 0 으로 오므로 값이 잡힐 때까지 다시 묻는다.
      if (_duration <= 0) _readDuration();
    });
  }

  Future<void> _readDuration() async {
    final value = await widget.youtube.duration;
    if (mounted && value > 0 && value != _duration) {
      setState(() => _duration = value);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// '4:05' / '1:02:03'
  static String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final total = _duration;
    final current = _dragging ?? _position.inSeconds.toDouble();
    final value = total > 0 ? current.clamp(0.0, total) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppBrand.primary,
              inactiveTrackColor: palette.borderSubtle,
              thumbColor: AppBrand.primary,
              overlayColor: AppBrand.primary.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              max: total > 0 ? total : 1,
              // 길이를 아직 못 읽었으면 끌 수 없다.
              onChanged: total > 0
                  ? (v) => setState(() => _dragging = v)
                  : null,
              onChangeEnd: (v) {
                widget.youtube.seekTo(seconds: v, allowSeekAhead: true);
                setState(() => _dragging = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(Duration(seconds: value.round())),
                  style: TextStyle(fontSize: 11, color: palette.textTertiary),
                ),
                Text(
                  total > 0
                      ? _format(Duration(seconds: total.round()))
                      : '--:--',
                  style: TextStyle(fontSize: 11, color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 접힌 바에 들어가는 곡 제목과 버튼.
class _MiniControls extends StatelessWidget {
  const _MiniControls({required this.controller, required this.onExpand});

  final AdminPlayerController controller;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final youtube = controller.youtube;
    final song = controller.currentSong;
    if (youtube == null || song == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onExpand,
            // 위로 쓸어올려도 펼쳐진다.
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -100) onExpand();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.songName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${controller.current + 1} / ${controller.songs.length}',
                  style: TextStyle(fontSize: 11, color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ),
        _RoundIconButton(
          icon: controller.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 26,
          onTap: controller.togglePlay,
        ),
        _RoundIconButton(
          icon: Icons.skip_next_rounded,
          size: 26,
          onTap: youtube.nextVideo,
        ),
        _RoundIconButton(
          icon: Icons.close_rounded,
          size: 22,
          onTap: controller.close,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.size = 30,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(
          icon,
          size: size,
          color: AppPalette.of(context).textPrimary,
        ),
      ),
    );
  }
}
