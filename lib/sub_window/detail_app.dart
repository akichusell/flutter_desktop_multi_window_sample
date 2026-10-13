import 'package:flutter/material.dart';

import '../common/channels.dart';
import '../common/reaction.dart';
import '../common/ui.dart';
import 'sub_window_state.dart';

/// 상세 창: 이미지를 크게 보여 주고, 우클릭 메뉴로 리액션을 토글한다.
class DetailApp extends StatelessWidget {
  const DetailApp({super.key, required this.state, required this.args});

  final SubWindowState state;
  final DetailArgs args;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF16161D),
        body: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final reactions = state.reactions.of(args.imageId);
            return Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onSecondaryTapDown: (details) => _showReactionMenu(context, details.globalPosition, reactions),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(args.imageId, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                _ReactionBar(reactions),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 리액션 5종 메뉴. 현재 붙어 있는 리액션은 체크 표시.
  Future<void> _showReactionMenu(BuildContext context, Offset position, List<Reaction> current) async {
    final picked = await showMenu<Reaction>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        for (final reaction in Reaction.values)
          CheckedPopupMenuItem(
            value: reaction,
            checked: current.contains(reaction),
            child: Text('${reaction.emoji}  ${reaction.label}'),
          ),
      ],
    );
    if (picked == null) return;
    await state.toggle(args.imageId, picked);
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar(this.reactions);

  final List<Reaction> reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      child: reactions.isEmpty
          ? const Text('이미지 위에서 우클릭해 리액션을 붙여 보세요', style: TextStyle(color: Colors.white60))
          : ReactionBadges(reactions, size: 20),
    );
  }
}
