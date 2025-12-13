import 'package:flutter/material.dart';


class SmoothSlide extends StatefulWidget {
 final Widget child;
  const SmoothSlide({super.key, required this.child});

  @override
  // ignore: library_private_types_in_public_api
  _SmoothSlideState createState() => _SmoothSlideState();
}

class _SmoothSlideState extends State<SmoothSlide> with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // AnimationController tanımı
    _controller = AnimationController(
      duration: const Duration(seconds: 1,milliseconds: 5), // Süre
      vsync: this,
    );

    // Pozisyon animasyonu
    _positionAnimation = Tween<Offset>(
      begin: Offset(0, 0.5), // Aşağıdan biraz yukarı çıkış
      end: Offset(0, 0),     // Orijinal konum
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Yumuşak geçiş
    ));

    // Opaklık animasyonu
    _opacityAnimation = Tween<double>(
      begin: 0.0, // Başta tamamen görünmez
      end: 1.0,   // Sonunda tamamen görünür
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Aynı eğri
    ));

    // Animasyonu başlat
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value, // Opaklık animasyonu
            child: SlideTransition(
              position: _positionAnimation, // Pozisyon animasyonu
              child: child,
            ),
          );
        },
        child: widget.child
      ),
    );
  }
}