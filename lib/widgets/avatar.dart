import 'dart:io';
import 'package:flutter/material.dart';

class Avatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool isTitanElite;

  const Avatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 50,
    this.isTitanElite = false,
  });

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isTitanElite) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTitanElite && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isTitanElite && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      if (widget.imageUrl!.startsWith('http')) {
        imageProvider = NetworkImage(widget.imageUrl!);
      } else {
        final file = File(widget.imageUrl!);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    Widget avatarCore = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isTitanElite ? Colors.transparent : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        image: imageProvider != null
            ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageProvider == null
          ? Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.size / 2.2,
              ),
            )
          : null,
    );

    if (!widget.isTitanElite) return avatarCore;

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _animation,
          child: Container(
            width: widget.size + 4,
            height: widget.size + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Colors.blue, Colors.purple, Colors.cyan, Colors.blue],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ),
        avatarCore,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.blue,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}
