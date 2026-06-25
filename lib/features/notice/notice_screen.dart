import 'package:flutter/material.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '공지/건의',
        style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
      ),
    );
  }
}
