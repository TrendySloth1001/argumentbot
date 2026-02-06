import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';

class ChatService {
  Future<String> sendMessage(
    String message, {
    String model = 'llama3.2',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message, 'model': model}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to communicate with AI: $e');
    }
  }
}
