import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  final bool isListening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      onPressed: onPressed,
      child: Icon(isListening ? Icons.stop : Icons.mic),
    );
  }
}