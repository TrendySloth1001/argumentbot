class ChatMessage {
  final String content;
  final bool isUser;
  final String? model; // To track which model replied

  ChatMessage({required this.content, required this.isUser, this.model});
}
