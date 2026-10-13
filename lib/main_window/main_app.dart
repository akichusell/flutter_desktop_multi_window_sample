import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../common/demo_flags.dart';
import '../common/gallery_images.dart';
import '../common/log.dart';
import '../common/reaction.dart';
import '../common/ui.dart';
import 'reaction_store.dart';
import 'window_pool.dart';

/// 메인 엔진 초기화. 채널 핸들러는 여기서 한 번만 등록한다.
Future<MainApp> setUpMainWindow() async {
  final store = ReactionStore();
  final pool = WindowPool(store);
  final (images, _, _) = await (loadGalleryImages(), store.serve(), pool.serve()).wait;

  // 리액션이 바뀌면 서브 창들에 push.
  store.addListener(kPushToHiddenWindows ? pool.pushToAll : pool.pushToVisible);

  await windowManager.ensureInitialized();
  await windowManager.setTitle('Multi Window Sample');
  await windowManager.setSize(kMainWindowSize);
  await windowManager.setMinimumSize(kMainWindowMinSize);
  await windowManager.setPreventClose(true); // 닫기 전에 서브 엔진부터 정리한다
  windowManager.addListener(_QuitOnMainClose(pool));

  return MainApp(images: images, store: store, pool: pool);
}

/// 메인 창을 닫으면 앱 전체를 종료한다. 숨겨 둔 서브 창이 있어도 프로세스가 남지 않게.
class _QuitOnMainClose with WindowListener {
  _QuitOnMainClose(this._pool);

  final WindowPool _pool;

  @override
  Future<void> onWindowClose() async {
    log('lifecycle', 'X on main -> quit app');
    await _pool.shutdownAll();
    log('lifecycle', 'exit process (windowManager.destroy)');
    await windowManager.destroy(); // macOS: NSApp.terminate, Windows: PostQuitMessage
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.images, required this.store, required this.pool});

  final List<String> images;
  final ReactionStore store;
  final WindowPool pool;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              _Header(store: store, onReactionTap: pool.openCategory),
              Expanded(
                child: ImageGrid(
                  itemCount: images.length,
                  itemBuilder: (context, i) => _GridTile(imageId: images[i], store: store, pool: pool),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 좌측 제목 + 우측 상단 리액션 5종과 개수. 클릭하면 카테고리 창.
class _Header extends StatelessWidget {
  const _Header({required this.store, required this.onReactionTap});

  final ReactionStore store;
  final ValueChanged<Reaction> onReactionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
      child: Row(
        children: [
          Text('Gallery', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          for (final reaction in Reaction.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: '${reaction.label} 카테고리 열기',
                child: ActionChip(
                  avatar: Text(reaction.emoji),
                  label: Text('${store.countOf(reaction)}'),
                  onPressed: () => onReactionTap(reaction),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.imageId, required this.store, required this.pool});

  final String imageId;
  final ReactionStore store;
  final WindowPool pool;

  @override
  Widget build(BuildContext context) {
    final isLast = store.lastReactedImageId == imageId;
    return ImageCard(
      imageId: imageId,
      reactions: store.reactionsOf(imageId),
      onTap: () => pool.openDetail(imageId),
      // 마지막으로 반응한 이미지가 바뀌면 이 위젯이 옛 타일에서 새 타일로 "교체"된다.
      overlay: isLast ? _LastReactedHighlight(imageId: imageId, store: store) : null,
    );
  }
}

/// 마지막으로 반응한 이미지 강조. 슬롯에 리스너를 등록해 리액션이 올 때마다 펄스를 그린다.
/// 교체 순서: 새 위젯 initState(register) → 옛 위젯 dispose(unregister). 로그로 확인한다.
class _LastReactedHighlight extends StatefulWidget {
  const _LastReactedHighlight({required this.imageId, required this.store});

  final String imageId;
  final ReactionStore store;

  @override
  State<_LastReactedHighlight> createState() => _LastReactedHighlightState();
}

class _LastReactedHighlightState extends State<_LastReactedHighlight> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Reaction? _reaction;

  @override
  void initState() {
    super.initState();
    log('widget', 'initState $this');
    widget.store.lastReactedSlot.register(this, _onReaction);
  }

  @override
  void dispose() {
    log('widget', 'dispose $this');
    widget.store.lastReactedSlot.unregister(this); // 가드가 없으면 방금 등록된 새 리스너를 지운다
    _pulse.dispose();
    super.dispose();
  }

  void _onReaction(Reaction reaction) {
    setState(() => _reaction = reaction);
    _pulse.forward(from: 0);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'highlight:${fileNameOf(widget.imageId)}#${shortHash(this)}';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => _pulse.isAnimating
              ? Center(
                  child: Opacity(
                    opacity: 1 - _pulse.value,
                    child: Transform.scale(
                      scale: 1 + _pulse.value * 1.5,
                      child: Text(_reaction?.emoji ?? '', style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
