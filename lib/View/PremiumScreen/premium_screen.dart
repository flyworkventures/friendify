import 'dart:io';
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    // Android'de close butonu gözükmediği için Scaffold ile wrap ediyoruz
    if (Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: PaywallView(
            displayCloseButton: false, // Android'de kendi AppBar'ımızı kullanıyoruz
          ),
        ),
      );
    } else {
      // iOS'ta normal şekilde çalışıyor
      return PaywallView(displayCloseButton: true);
    }
  }
}