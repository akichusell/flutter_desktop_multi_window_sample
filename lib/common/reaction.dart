/// 이미지에 붙이는 리액션 5종.
/// 채널로는 [name] 문자열만 오간다 (enum 객체는 엔진 경계를 넘지 못한다).
enum Reaction {
  heart('❤️', '하트'),
  like('👍', '좋아요'),
  dislike('👎', '싫어요'),
  laugh('😂', '웃김'),
  wow('😮', '놀람');

  const Reaction(this.emoji, this.label);

  final String emoji;
  final String label;

  static Reaction fromName(String name) => Reaction.values.byName(name);
}
