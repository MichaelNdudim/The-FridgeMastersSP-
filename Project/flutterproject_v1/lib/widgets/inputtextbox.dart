import 'package:flutter/material.dart';

class InputTextBox extends StatelessWidget {
  final bool isPassword;
  final String hint;
  final TextEditingController controller; // Add this line

  // Define the width and height for the InputTextBox
  final double width = 300.0;
  final double height = 50.0;

  InputTextBox({required this.isPassword, required this.hint, required this.controller}); // Modify this line

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: TextField(
        controller: controller, // Add this line
        obscureText: isPassword, // If true, the text will be obscured with dots
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          hintText: hint,
        ),
      ),
    );
  }
}
