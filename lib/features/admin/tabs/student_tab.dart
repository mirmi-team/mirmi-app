import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/student_service.dart';
import '../../../shared/app_banner.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_refresh.dart';
import '../../../shared/app_skeleton.dart';
import '../admin_player.dart';
import '../../../shared/merit_style.dart';
import '../student_sheet.dart';

/// 학생 정보 관리.
///
/// 호실을 눌러 펼치면 그 방 학생이 나오고, 학생을 누르면 상벌점과 호실을
/// 손볼 수 있다. 4층·5층을 나눠 보여주지만 세그먼트로 가르지는 않는다.
/// 층이 둘뿐이라 탭으로 만들면 오가는 품만 든다.
class AdminStudentTab extends StatefulWidget {
  const AdminStudentTab({super.key});

  @override
  State<AdminStudentTab> createState() => _AdminStudentTabState();
}

class _AdminStudentTabState extends State<AdminStudentTab> with AppBannerMixin {
  bool _loading = true;
  List<DormRoom> _rooms = const [];

  /// 펼쳐 둔 호실. 한 번에 하나만 연다. 여럿 열어두면 스크롤 중에 어느 방
  /// 학생인지 헷갈린다.
  int? _openRoomId;

  /// 기상송 미니 플레이어가 떠 있으면 그만큼 더 비워 둔다.
  double get _playerInset => AdminPlayerScope.of(context).isOpen ? 70.0 : 0.0;

  EdgeInsets get _listPadding =>
      EdgeInsets.fromLTRB(20, 10, 20, 120 + _playerInset);

  int get _totalStudents =>
      _rooms.fold(0, (sum, room) => sum + room.students.length);

  /// 층 오름차순. 층이 비어 있는 호실은 한 묶음으로 맨 뒤에 둔다.
  List<int?> get _floors {
    final floors = _rooms.map((r) => r.floor).toSet().toList();
    floors.sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });
    return floors;
  }

  /// 호실을 옮길 때 고를 수 있는 방 번호. 빈 방도 들어간다.
  List<int> get _allRoomNumbers =>
      _rooms.map((r) => r.roomNumber).toList()..sort();

  String get _subtitle {
    if (_loading) return '호실을 눌러 학생을 확인하세요.';
    if (_rooms.isEmpty) return '등록된 호실이 없습니다.';
    return '학생을 눌러 상벌점과 호실을 바꿀 수 있습니다.';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final rooms = await StudentService.getRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
        // 사라진 방을 펼친 채로 두지 않는다.
        if (!rooms.any((r) => r.roomId == _openRoomId)) _openRoomId = null;
      });
    } on SessionExpiredException {
      if (mounted) context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorBanner('학생 목록을 불러오지 못했습니다.');
    }
  }

  void _toggleRoom(DormRoom room) {
    if (room.isEmpty) return;
    setState(
      () => _openRoomId = _openRoomId == room.roomId ? null : room.roomId,
    );
  }

  Future<void> _openStudent(DormRoom room, Student student) async {
    var changed = false;
    await showStudentSheet(
      context,
      student: student,
      roomNumber: room.roomNumber,
      roomNumbers: _allRoomNumbers,
      onChanged: () => changed = true,
    );
    // 점수나 호실이 바뀐 경우에만 다시 받는다. 들여다보기만 했으면 그대로 둔다.
    if (changed && mounted) await _load(silent: true);
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
                          '학생 정보 관리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (!_loading)
                        Text(
                          '총 $_totalStudents명',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    style: TextStyle(fontSize: 13, color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildBody(palette)),
          ],
        ),
        buildBanner(),
      ],
    );
  }

  Widget _buildBody(AppPalette palette) {
    if (_loading) {
      return ListView.separated(
        padding: _listPadding,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 28),
        itemBuilder: (_, _) => const AppSkeleton(height: 190, radius: 12),
      );
    }

    return AppRefreshScrollView(
      onRefresh: () => _load(silent: true),
      slivers: [
        SliverPadding(
          padding: _listPadding,
          sliver: _rooms.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '등록된 호실이 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                )
              : SliverList.list(
                  children: [
                    for (final floor in _floors) ...[
                      _FloorHeader(floor: floor, rooms: _roomsOn(floor)),
                      const SizedBox(height: 10),
                      _RoomGroup(
                        rooms: _roomsOn(floor),
                        openRoomId: _openRoomId,
                        onToggle: _toggleRoom,
                        onStudentTap: _openStudent,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  List<DormRoom> _roomsOn(int? floor) =>
      _rooms.where((r) => r.floor == floor).toList()
        ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
}

/// '5층 ──────── 13명'. 층이 바뀌는 자리를 알려준다.
class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.floor, required this.rooms});

  final int? floor;
  final List<DormRoom> rooms;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final count = rooms.fold(0, (sum, room) => sum + room.students.length);
    return Row(
      children: [
        Text(
          floor == null ? '층 미지정' : '$floor층',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: palette.borderSubtle, height: 1)),
        const SizedBox(width: 12),
        Text(
          '$count명',
          style: TextStyle(fontSize: 12, color: palette.textTertiary),
        ),
      ],
    );
  }
}

/// 한 층의 호실을 한 덩어리로 묶는다.
///
/// 호실마다 카드를 따로 띄우면 간격이 붙어 스크롤이 두 배로 길어진다.
class _RoomGroup extends StatelessWidget {
  const _RoomGroup({
    required this.rooms,
    required this.openRoomId,
    required this.onToggle,
    required this.onStudentTap,
  });

  final List<DormRoom> rooms;
  final int? openRoomId;
  final void Function(DormRoom) onToggle;
  final void Function(DormRoom, Student) onStudentTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rooms.length; i++) ...[
            if (i > 0) Divider(color: palette.borderSubtle, height: 1),
            _RoomTile(
              room: rooms[i],
              expanded: rooms[i].roomId == openRoomId,
              onToggle: () => onToggle(rooms[i]),
              onStudentTap: (student) => onStudentTap(rooms[i], student),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.expanded,
    required this.onToggle,
    required this.onStudentTap,
  });

  final DormRoom room;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Student> onStudentTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Text(
                  '${room.roomNumber}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    // 빈 방은 눌러도 펼쳐지지 않으니 글자도 한 단계 죽인다.
                    color: room.isEmpty
                        ? palette.textTertiary
                        : palette.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  room.isEmpty ? '비어 있음' : '${room.students.length}명',
                  style: TextStyle(fontSize: 13, color: palette.textTertiary),
                ),
                const SizedBox(width: 8),
                // 빈 방에는 펼칠 것이 없어 화살표도 두지 않는다.
                SizedBox(
                  width: 22,
                  child: room.isEmpty
                      ? null
                      : AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 22,
                            color: palette.textSecondary,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  children: [
                    Divider(
                      color: palette.borderSubtle,
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                    ),
                    for (final student in room.students)
                      _StudentRow(
                        student: student,
                        onTap: () => onStudentTap(student),
                      ),
                    const SizedBox(height: 6),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final classLabel = student.classLabel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Text(
              student.username,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            if (classLabel != null) ...[
              const SizedBox(width: 10),
              Text(
                classLabel,
                style: TextStyle(fontSize: 12, color: palette.textTertiary),
              ),
            ],
            const Spacer(),
            // 색이 상점인지 벌점인지 말해주므로 '벌점' 같은 글자는 붙이지 않는다.
            Text(
              meritLabel(student.meritScore),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: meritColor(student.meritScore, palette),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
