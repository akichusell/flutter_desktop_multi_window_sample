import 'package:flutter/material.dart';

import '../common/channels.dart';
import '../common/title_bar.dart';
import '../common/ui.dart';
import 'sub_bootstrap.dart';
import 'sub_window_state.dart';

/// 카테고리 창: 한 리액션이 붙은 이미지만 모아 본다. 창 1개를 재사용하므로 리액션은 init으로 바뀐다.
class CategoryApp extends StatelessWidget {
  const CategoryApp({super.key, required this.state});

  final SubWindowState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final reaction = (state.args as CategoryArgs).reaction;
            final images = state.imagesWith(reaction);
            return WindowFrame(
              title: windowTitleOf(state.args), // 재사용 창이라 init 때마다 바뀐다
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Text(
                      '${reaction.emoji}  ${reaction.label} · ${images.length}장',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: images.isEmpty
                        ? Center(child: Text('아직 ${reaction.label} 리액션이 붙은 이미지가 없습니다'))
                        : ImageGrid(
                            itemCount: images.length,
                            itemBuilder: (context, i) => ImageCard(
                              imageId: images[i],
                              reactions: state.reactions.of(images[i]),
                              onTap: () => state.openDetail(images[i]), // 창 생성은 메인에게 요청
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
