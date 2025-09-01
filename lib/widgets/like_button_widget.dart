import 'package:flutter/material.dart';
import 'package:social_space/models/post.dart';

class LikeButtonWidget extends StatefulWidget {
  final Post post;
  final Future<void> Function(Post) onToggle;

  const LikeButtonWidget({
    super.key,
    required this.post,
    required this.onToggle,
  });

  @override
  State<LikeButtonWidget> createState() => _LikeButtonWidgetState();
}

class _LikeButtonWidgetState extends State<LikeButtonWidget>
    with SingleTickerProviderStateMixin {
  late bool isLiked;
  late int likeCount;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    likeCount = widget.post.likes.length;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _handleLike() async {
    await widget.onToggle(widget.post);
    setState(() {
      isLiked = widget.post.isLiked;
      likeCount = widget.post.likes.length;
    });

    // Trigger bounce effect when liked
    if (isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleLike,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$likeCount",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isLiked ? Colors.red : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
