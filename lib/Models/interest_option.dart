/// `/interests/list-localized` yanıtındaki tek satır (slug kayıtta kullanılır).
class InterestOption {
  const InterestOption({
    required this.id,
    required this.slug,
    required this.emoji,
    required this.sortOrder,
    required this.label,
  });

  final int id;
  final String slug;
  final String emoji;
  final int sortOrder;
  final String label;

  factory InterestOption.fromJson(Map<String, dynamic> json) {
    return InterestOption(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      slug: json['slug']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse('${json['sort_order']}') ?? 0,
      label: json['label']?.toString() ?? json['slug']?.toString() ?? '',
    );
  }
}
