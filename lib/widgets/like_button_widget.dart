import 'package:flutter/material.dart';
import 'package:quick_connect/models/post.dart';

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

class _LikeButtonWidgetState extends State<LikeButtonWidget> {
  late bool isLiked;
  late int likeCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    likeCount = widget.post.likes.length;
  }

  Future<void> _handleLike() async {
    await widget.onToggle(widget.post);
    setState(() {
      isLiked = widget.post.isLiked;
      likeCount = widget.post.likes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          onPressed: _handleLike,
        ),
        Text(
          "$likeCount",
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
