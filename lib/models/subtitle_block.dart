class SubtitleBlock {
  int index;
  String timecode;
  String text;

  SubtitleBlock({
    required this.index,
    required this.timecode,
    required this.text,
  });

  Map<String, dynamic> toJson() =>
      {'index': index, 'timecode': timecode, 'text': text};

  factory SubtitleBlock.fromJson(Map<String, dynamic> json) {
    return SubtitleBlock(
        index: int.tryParse(json['index']?.toString() ?? "0") ?? 0,
        timecode: json['timecode'] ?? "",
        text: json['text'] ?? "");
  }
}