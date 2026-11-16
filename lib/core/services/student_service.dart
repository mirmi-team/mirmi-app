import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/server_time.dart';
import '../constants/api.dart';
import 'auth_service.dart';

/// 서버에 아직 없는 엔드포인트를 가짜 데이터로 대신할지.
///
/// 호실별 학생 목록(`GET /rooms/admin`)과 특정 학생의 상벌점 내역
/// (`GET /merit-logs/admin/:userId`)은 요청만 해 둔 상태다. 나오면
/// 이 상수만 false 로 내리면 된다. 나머지 호출은 지금도 진짜 서버를 탄다.
const bool kUseMockStudents = true;

/// 학생 정보 관리 API. 전부 관리자 전용.
class StudentService {
  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// 호실별 학생 목록. [floor] 를 주면 그 층만.
  ///
  /// 학생이 없는 호실도 빈 채로 내려온다. 호실을 옮길 자리를 고르려면
  /// 비어 있는 방도 보여야 한다.
  static Future<List<DormRoom>> getRooms({int? floor}) async {
    if (kUseMockStudents) return _mockRooms(floor);

    final query = floor == null ? '' : '?floor=$floor';
    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/rooms/admin$query'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => DormRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상벌점 사유 목록. 상점·벌점이 섞여 오고 각자 [MeritReason.type] 을 달고 있다.
  static Future<List<MeritReason>> getReasons() async {
    if (kUseMockStudents) return _mockReasons;

    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/merit-logs/reasons'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => MeritReason.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 한 학생의 상벌점 내역 (최신순).
  static Future<List<MeritLogEntry>> getMeritLogs(int userId) async {
    if (kUseMockStudents) return _mockLogs(userId);

    final res = await AuthService.authorized(
      (token) => http.get(
        Uri.parse('$kBaseUrl/merit-logs/admin/$userId'),
        headers: _headers(token),
      ),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .map((e) => MeritLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상벌점 부여. 총점을 덮어쓰는 게 아니라 더한다.
  ///
  /// [score] 는 크기만 보내고 부호는 서버가 [type] 을 보고 정한다.
  /// 두 번 부르면 두 번 들어가므로 버튼을 눌린 채로 두면 안 된다.
  static Future<void> giveMerit({
    required int userId,
    required MeritType type,
    required int score,
    required String reason,
  }) async {
    if (kUseMockStudents) return _pretend();

    final res = await AuthService.authorized(
      (token) => http.post(
        Uri.parse('$kBaseUrl/merit-logs/admin'),
        headers: _headers(token),
        body: jsonEncode({
          'user_id': userId,
          'type': type.wire,
          'score': score.abs(),
          'reason': reason,
        }),
      ),
    );
    _checkStatus(res);
  }

  /// 호실 이동. 서버가 방 번호로 방을 찾아 [room_id] 를 바꾼다.
  static Future<void> changeRoom(int userId, int roomNumber) async {
    if (kUseMockStudents) return _pretend();

    final res = await AuthService.authorized(
      (token) => http.patch(
        Uri.parse('$kBaseUrl/users/admin/$userId'),
        headers: _headers(token),
        body: jsonEncode({'room_number': roomNumber}),
      ),
    );
    _checkStatus(res);
  }

  /// 목업일 때는 서버를 건드리지 않는다. 가짜 학생 id 로 진짜 부여를 날리면
  /// 404 가 날 뿐이고, 운 나쁘면 실제 학생에게 들어간다.
  static Future<void> _pretend() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      final message = body['message'];
      throw ApiException(
        message is List ? message.first.toString() : message.toString(),
      );
    } on FormatException {
      throw const ApiException('학생 정보를 불러오지 못했습니다.');
    }
  }
}

/// 상점과 벌점. [wire] 는 서버가 쓰는 값이라 그대로 주고받는다.
enum MeritType {
  penalty('PENALTY'),
  reward('REWARD');

  const MeritType(this.wire);

  final String wire;
}

/// 호실 하나와 그 방 학생들.
class DormRoom {
  const DormRoom({
    required this.roomId,
    required this.roomNumber,
    required this.floor,
    required this.students,
  });

  final int roomId;
  final int roomNumber;
  final int floor;
  final List<Student> students;

  bool get isEmpty => students.isEmpty;

  factory DormRoom.fromJson(Map<String, dynamic> json) {
    final raw = json['students'];
    return DormRoom(
      roomId: json['room_id'] as int,
      roomNumber: json['room_number'] as int,
      floor: (json['floor'] as int?) ?? 0,
      students: raw is List
          ? raw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList()
          : const <Student>[],
    );
  }
}

/// 목록에 뿌리는 학생 한 명.
class Student {
  const Student({
    required this.id,
    required this.username,
    required this.meritScore,
    this.grade,
    this.classNo,
  });

  final int id;
  final String username;

  /// 상점과 벌점을 합친 부호 있는 총점. 벌점이 쌓이면 음수가 된다.
  /// 마이페이지와 같은 값이라 그대로 찍으면 된다.
  final int meritScore;

  final int? grade;
  final int? classNo;

  /// '2-3'. 학년이나 반이 비면 null 이라 그 자리를 비운다.
  String? get classLabel {
    if (grade == null || classNo == null) return null;
    return '$grade-$classNo';
  }

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as int,
    username: (json['username'] ?? '') as String,
    meritScore: (json['total_merit_score'] as int?) ?? 0,
    grade: json['grade'] as int?,
    classNo: json['class_no'] as int?,
  );
}

/// 미리 등록된 상벌점 사유. 고르면 [defaultScore] 가 점수 칸에 들어간다.
class MeritReason {
  const MeritReason({
    required this.id,
    required this.type,
    required this.reason,
    required this.defaultScore,
  });

  final int id;
  final MeritType type;
  final String reason;
  final int defaultScore;

  bool get isReward => type == MeritType.reward;

  /// 목록에 보여줄 부호 붙은 점수. 서버는 사유에 크기만 저장한다.
  int get signedScore => isReward ? defaultScore.abs() : -defaultScore.abs();

  factory MeritReason.fromJson(Map<String, dynamic> json) => MeritReason(
    id: json['id'] as int,
    type: json['type'] == 'REWARD' ? MeritType.reward : MeritType.penalty,
    reason: (json['reason'] ?? '') as String,
    defaultScore: (json['default_score'] as int?) ?? 0,
  );
}

/// 부여 기록 한 줄. [score] 는 서버가 이미 부호를 붙여서 준다.
class MeritLogEntry {
  const MeritLogEntry({
    required this.id,
    required this.type,
    required this.score,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final MeritType type;
  final int score;
  final String reason;
  final DateTime createdAt;

  bool get isReward => type == MeritType.reward;

  factory MeritLogEntry.fromJson(Map<String, dynamic> json) => MeritLogEntry(
    id: json['id'] as int,
    type: json['type'] == 'REWARD' ? MeritType.reward : MeritType.penalty,
    score: (json['score'] as int?) ?? 0,
    reason: (json['reason'] ?? '') as String,
    createdAt: parseServerTime(json['created_at'] as String) ?? DateTime.now(),
  );
}

// ── 서버가 열리기 전까지 쓰는 가짜 데이터 ──────────────────────────

Future<List<DormRoom>> _mockRooms(int? floor) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  final rooms = <DormRoom>[
    _room(11, 401, ['김도윤', '박시우', '이준서', '정하준'], [0, -3, 2, 0]),
    _room(12, 402, ['최은우', '한지호', '오서준'], [-5, 0, 0]),
    _room(13, 403, ['서민재', '신예준', '권도현', '황지후'], [3, 0, -2, 0]),
    _room(14, 404, [], []),
    _room(21, 501, ['이제호', '김민수', '박서준', '최유나'], [-3, 0, 5, -1]),
    _room(22, 502, ['정다은', '윤서연', '강하린'], [0, 2, 0]),
    _room(23, 503, ['임채원', '송지아'], [-7, 0]),
    _room(24, 504, [], []),
  ];
  if (floor == null) return rooms;
  return rooms.where((r) => r.floor == floor).toList();
}

DormRoom _room(int id, int number, List<String> names, List<int> scores) =>
    DormRoom(
      roomId: id,
      roomNumber: number,
      floor: number ~/ 100,
      students: [
        for (var i = 0; i < names.length; i++)
          Student(
            id: id * 10 + i,
            username: names[i],
            meritScore: scores[i],
            grade: (i % 3) + 1,
            classNo: (i % 6) + 1,
          ),
      ],
    );

const _mockReasons = <MeritReason>[
  MeritReason(id: 1, type: MeritType.reward, reason: '청소 우수', defaultScore: 2),
  MeritReason(
    id: 2,
    type: MeritType.reward,
    reason: '기숙사 행사 참여',
    defaultScore: 3,
  ),
  MeritReason(
    id: 3,
    type: MeritType.penalty,
    reason: '분리수거 미흡',
    defaultScore: 2,
  ),
  MeritReason(
    id: 4,
    type: MeritType.penalty,
    reason: '점호 시간 미준수',
    defaultScore: 3,
  ),
  MeritReason(
    id: 5,
    type: MeritType.penalty,
    reason: '취침 시간 미준수',
    defaultScore: 3,
  ),
  MeritReason(id: 6, type: MeritType.penalty, reason: '기물 파손', defaultScore: 5),
];

Future<List<MeritLogEntry>> _mockLogs(int userId) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final now = DateTime.now();
  return [
    MeritLogEntry(
      id: 1,
      type: MeritType.penalty,
      score: -3,
      reason: '점호 시간 미준수',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    MeritLogEntry(
      id: 2,
      type: MeritType.penalty,
      score: -2,
      reason: '분리수거 미흡',
      createdAt: now.subtract(const Duration(days: 14)),
    ),
    MeritLogEntry(
      id: 3,
      type: MeritType.reward,
      score: 2,
      reason: '청소 우수',
      createdAt: now.subtract(const Duration(days: 19)),
    ),
  ];
}
