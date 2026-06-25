import 'package:flutter/material.dart';

class SongScreen extends StatelessWidget {
  const SongScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '기상송',
        style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
      ),
    );
  }
}
