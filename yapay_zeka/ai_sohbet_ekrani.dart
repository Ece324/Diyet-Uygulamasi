import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiSohbetEkrani extends StatefulWidget {
  const AiSohbetEkrani({super.key});

  @override
  State<AiSohbetEkrani> createState() => _AiSohbetEkraniState();
}

class _AiSohbetEkraniState extends State<AiSohbetEkrani> {
  final TextEditingController _mesajController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // UI'da göstermek için mesaj listesi
  final List<UIMesaj> _uiMesajlar = [];
  
  bool _isLoading = false;

  // --- GROQ API ANAHTARI VE MODEL ---
  static const String _apiKey = "GROQ_API_ANAHTARINIZI_BURAYA_YAPISTIRIN"; // Groq API anahtarı
  static const String _model = "llama-3.1-8b-instant"; // Güncellenmiş model adı
  
  // Konuşma geçmişini tutmak için
  List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    // Sistem mesajını basitleştirmek için
    _chatHistory.add({
      'role': 'system',
      'content': 'Sen bir diyet ve beslenme asistanısın. Kullanıcılara sağlıklı beslenme, diyet, su tüketimi ve egzersiz konularında arkadaşça tavsiyeler ver. Asla tıbbi teşhis koyma veya ilaç önerme. Cevapların motive edici, kısa ve Türkçe olsun. En fazla 3-4 cümle ile cevap ver.'
    });
    
    debugPrint('Groq API Anahtarı başlangıcı: ${_apiKey.substring(0, min(8, _apiKey.length))}...');
    debugPrint('Model: $_model');
  }

  Future<void> _mesajGonder() async {
    final text = _mesajController.text.trim();
    if (text.isEmpty) return;

    _mesajController.clear();

    // 1. Kullanıcı mesajını ekrana ekleme
    setState(() {
      _uiMesajlar.add(UIMesaj(rol: 'kullanici', mesaj: text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // 2. Kullanıcı mesajını geçmişe ekleme
      _chatHistory.add({
        'role': 'user',
        'content': text
      });

      // 3. Groq API'ye istek gönderme + DEBUG EKLENDİ
      debugPrint('--- DEBUG BAŞLANGIÇ ---');
      debugPrint('API Anahtarı: ${_apiKey.substring(0, min(10, _apiKey.length))}...');
      debugPrint('Model: $_model');
      debugPrint('Geçmiş uzunluğu: ${_chatHistory.length}');
      
      final requestBody = jsonEncode({
        'model': _model,
        'messages': _chatHistory,
        'temperature': 0.7,
        'max_tokens': 500,
      });
      
      debugPrint('İstek Gövdesi: $requestBody');
      debugPrint('İstek URL: https://api.groq.com/openai/v1/chat/completions');

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      debugPrint('Yanıt Durum Kodu: ${response.statusCode}');
      debugPrint('Yanıt Gövdesi: ${response.body}');
      debugPrint('--- DEBUG SONU ---');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseBody = jsonDecode(response.body);
          final String responseText = responseBody['choices'][0]['message']['content'];

          // 4. AI cevabını geçmişe ekleme
          _chatHistory.add({
            'role': 'assistant',
            'content': responseText
          });

          // 5. Gelen cevabı ekrana ekleme
          setState(() {
            _uiMesajlar.add(UIMesaj(rol: 'model', mesaj: responseText));
          });
        } catch (e) {
          debugPrint('JSON parse hatası: $e');
          throw Exception('Yanıt işlenirken hata: $e');
        }
      } else {
        String errorMessage = 'API hatası: ${response.statusCode}';
        
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] != null) {
            errorMessage += ' - ${errorBody['error']['message'] ?? errorBody['error']}';
          }
        } catch (_) {
          errorMessage += ' - ${response.body}';
        }
        
        debugPrint('Hata detayı: $errorMessage');
        throw Exception(errorMessage);
      }
      
    } catch (e) {
      debugPrint("API Hatası (catch): $e");
      debugPrint("Hata tipi: ${e.runtimeType}");
      
      String errorMessage;
      if (e is FormatException) {
        errorMessage = "API yanıtı beklenen formatta değil";
      } else if (e is http.ClientException) {
        errorMessage = "İnternet bağlantı hatası: $e";
      } else {
        errorMessage = "Hata: $e";
      }
      
      setState(() {
        _uiMesajlar.add(UIMesaj(
          rol: 'hata', 
          mesaj: errorMessage
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Diyet Asistanı"),
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: Column(
        children: [
          // Mesaj Listesi
          Expanded(
            child: _uiMesajlar.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _uiMesajlar.length,
                    itemBuilder: (context, index) {
                      final msg = _uiMesajlar[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          
          // Yükleniyor Göstergesi
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Asistan yazıyor...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Mesaj Yazma Alanı
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco, size: 80, color: Colors.green.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            "Merhaba! Ben senin diyet asistanınım.\nBana sağlıklı beslenme hakkında\nher şeyi sorabilirsin.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(UIMesaj msg) {
    final isMe = msg.rol == 'kullanici';
    final isError = msg.rol == 'hata';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isError 
              ? Colors.red[100] 
              : (isMe ? Colors.green : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.mesaj,
              style: TextStyle(
                color: isMe ? Colors.white : (isError ? Colors.red[900] : Colors.black87),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _mesajController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _mesajGonder(),
              decoration: InputDecoration(
                hintText: "Bir şeyler sor...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.green,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _isLoading ? null : _mesajGonder,
            ),
          ),
        ],
      ),
    );
  }
}

// Mesajları tutmak için basit bir model sınıfı
class UIMesaj {
  final String rol; // 'kullanici', 'model' veya 'hata'
  final String mesaj;

  UIMesaj({required this.rol, required this.mesaj});
}