import 'package:flutter/material.dart';

import 'reaction.dart';

/// 모든 창이 같은 테마를 쓴다. (엔진마다 따로 만들어지지만 코드는 같다)
ThemeData buildAppTheme() => ThemeData(
  colorSchemeSeed: const Color(0xFF5B5BD6),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF6F6FA),
);

/// 둥근 모서리 이미지 카드. [overlay]는 이미지 위에 겹친다.
class ImageCard extends StatelessWidget {
  const ImageCard({super.key, required this.imageId, required this.reactions, this.onTap, this.overlay});

  final String imageId;
  final List<Reaction> reactions;
  final VoidCallback? onTap;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
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

/// 창 크기. 메인 > 카테고리 > 상세 순으로 작게 열고, 그리드 창의 최소 크기는 4열 타일이 너무 작아지지 않게 정한다.
const kMainWindowSize = Size(1100, 780);
const kMainWindowMinSize = Size(720, 540);
const kCategoryWindowSize = Size(960, 680);
const kCategoryWindowMinSize = Size(640, 480);
const kDetailWindowSize = Size(640, 500);
const kDetailWindowMinSize = Size(480, 400);

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
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 4 / 3,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
