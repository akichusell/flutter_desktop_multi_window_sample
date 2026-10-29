import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'log.dart';
import 'reaction.dart';

/// 모든 창이 같은 테마를 쓴다. (엔진마다 따로 만들어지지만 코드는 같다)
ThemeData buildAppTheme() => ThemeData(
  colorSchemeSeed: const Color(0xFF5B5BD6),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF6F6FA),
);

/// 둥근 모서리 이미지 카드. [overlay]는 이미지 위에 겹친다.
class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    required this.imageId,
    required this.reactions,
    this.onTap,
    this.onSecondaryTapUp,
    this.overlay,
  });

  final String imageId;
  final List<Reaction> reactions;
  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapUp: onSecondaryTapUp,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Ink.image(image: ResizeImage(AssetImage(imageId), width: 600), fit: BoxFit.cover),
            ?overlay,
            if (reactions.isNotEmpty) Positioned(left: 8, bottom: 8, child: ReactionBadges(reactions)),
          ],
        ),
      ),
    );
  }
}

/// 이미지에 붙은 리액션 배지.
class ReactionBadges extends StatelessWidget {
  const ReactionBadges(this.reactions, {super.key, this.size = 15});

  final List<Reaction> reactions;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
      child: Text(reactions.map((r) => r.emoji).join(' '), style: TextStyle(fontSize: size)),
    );
  }
}

/// 우클릭 리액션 메뉴. 5종을 가로로 늘어놓고, 이미 붙은 리액션은 버튼 배경색으로 표시한다.
/// 고른 리액션을 돌려주고, 바깥을 누르거나 창이 포커스를 잃어 닫히면 null.
Future<Reaction?> showReactionPicker(BuildContext context, Offset globalPosition, List<Reaction> current) async {
  // macOS는 비활성 창을 우클릭해도 창을 활성화하지 않는다. 직접 활성화해야 다른 창이 blur를 받아 자기 메뉴를 닫는다.
  await windowManager.focus();
  if (!context.mounted) return null;
  return showMenu<Reaction>(
    context: context,
    position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
    menuPadding: EdgeInsets.zero,
    // showMenu는 폭을 56 단위로 올림하므로, 내용 폭으로 상한을 둬 오른쪽 여백이 남지 않게 한다.
    constraints: BoxConstraints(maxWidth: _pickerWidth),
    items: [_ReactionPickerRow(current)],
  );
}

const _kPickerButtonSize = 40.0;
const _kPickerGap = 6.0;
const _kPickerPadding = 8.0;
final _pickerWidth = Reaction.values.length * (_kPickerButtonSize + _kPickerGap) - _kPickerGap + _kPickerPadding * 2;

class _ReactionPickerRow extends PopupMenuEntry<Reaction> {
  const _ReactionPickerRow(this.current);

  final List<Reaction> current;

  @override
  double get height => _kPickerButtonSize + _kPickerPadding * 2;

  @override
  bool represents(Reaction? value) => false;

  @override
  State<_ReactionPickerRow> createState() => _ReactionPickerRowState();
}

/// 창이 포커스를 잃으면 메뉴를 닫는다. window_manager는 엔진마다 자기 창 이벤트만 받는다.
class _ReactionPickerRowState extends State<_ReactionPickerRow> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowBlur() {
    // 닫히는 애니메이션 중이면 이미 pop된 상태라, 다시 pop하면 아래 화면이 닫힌다.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    log('menu', 'window blur -> close reaction menu');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_kPickerPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _kPickerGap,
        children: [
          for (final reaction in Reaction.values)
            _ReactionPickerButton(
              reaction: reaction,
              selected: widget.current.contains(reaction),
              onTap: () => Navigator.pop(context, reaction),
            ),
        ],
      ),
    );
  }
}

class _ReactionPickerButton extends StatelessWidget {
  const _ReactionPickerButton({required this.reaction, required this.selected, required this.onTap});

  final Reaction reaction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: _kPickerButtonSize,
          child: Center(child: Text(reaction.emoji, style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }
}

/// 창 크기는 모두 4:3이고 메인 > 카테고리 > 상세 순으로 작다. 서브 창은 최소 크기로 연다.
/// 최소 크기는 타일이 너무 작아지지 않게 정한다.
const kMainWindowSize = Size(840, 630);
const kMainWindowMinSize = Size(600, 450);
const kCategoryWindowMinSize = Size(560, 420);
const kDetailWindowMinSize = Size(400, 300);

/// 이미지 그리드. 열 수를 고정해 창 크기에 비례해서 타일이 연속적으로 커지고 작아진다.
class ImageGrid extends StatelessWidget {
  const ImageGrid({super.key, required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 4 / 3,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
