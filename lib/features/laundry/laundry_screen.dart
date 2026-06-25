import 'package:flutter/material.dart';

class LaundryScreen extends StatelessWidget {
  const LaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '세탁기',
        style: TextStyle(fontSize: 18, color: Color(0xFF888888)),
      ),
    );
  }
}
