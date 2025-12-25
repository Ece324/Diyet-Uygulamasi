import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MesajlasmaEkrani extends StatefulWidget {
  final String? diyetisyenId;
  final String? diyetisyenAdi;
  final String? sohbetOdasiId;
  final String? hedefKullaniciAdi;

  const MesajlasmaEkrani({
    super.key,
    this.diyetisyenId,
    this.diyetisyenAdi,
    this.sohbetOdasiId,
    this.hedefKullaniciAdi,
  });

  @override
  State<MesajlasmaEkrani> createState() => _MesajlasmaEkraniState();
}

class _MesajlasmaEkraniState extends State<MesajlasmaEkrani> {
  final _mesajController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  late String _chatRoomId;
  late String _hedefKullaniciAdi;
  String _currentUserAdSoyad = 'Kullanıcı';
  bool _isLoading = false;
  bool _hasText = false;
  
  // Stream değişkenini burada tanımla
  late final Stream<QuerySnapshot> _mesajStream;

  @override
  void initState() {
    super.initState();
    _chatRoomId = _getChatRoomId();
    _hedefKullaniciAdi = _getHedefKullaniciAdi();
    _kullaniciAdiniGetir();
    
    // TextController listener'ı (Doğru)
    _mesajController.addListener(_onTextChanged);
    
    // Stream'i SADECE BİR KERE ata
    _mesajStream = _firestore
        .collection('sohbetler')
        .doc(_chatRoomId)
        .collection('mesajlar')
        .orderBy('tarih', descending: false)
        .snapshots();
    
    // Açılışta kaydırma (Doğru)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // _onTextChanged, _scrollToBottom, _kullaniciAdiniGetir, 
  // _getChatRoomId, _getHedefKullaniciAdi, _mesajSil, _formatTime
  // fonksiyonları aynı kalacak...

  // Text değişikliklerini dinle
  void _onTextChanged() {
    final hasText = _mesajController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  // Kaydırma (Scroll) fonksiyonu
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _kullaniciAdiniGetir() async {
    if (_currentUser == null) return;
    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserAdSoyad = userDoc.data()?['adSoyad'] ?? 'Kullanıcı';
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı adı alınırken hata: $e");
    }
  }

  String _getChatRoomId() {
    if (widget.sohbetOdasiId != null) {
      return widget.sohbetOdasiId!;
    }
    if (widget.diyetisyenId != null && _currentUser != null) {
      List<String> ids = [_currentUser!.uid, widget.diyetisyenId!];
      ids.sort();
      return '${ids[0]}_${ids[1]}';
    }
    debugPrint("HATA: Sohbet odası ID'si oluşturulamadı.");
    return 'hata_odasi';
  }

  String _getHedefKullaniciAdi() {
    if (widget.hedefKullaniciAdi != null) {
      return widget.hedefKullaniciAdi!;
    }
    if (widget.diyetisyenAdi != null) {
      return widget.diyetisyenAdi!;
    }
    return 'Kullanıcı';
  }

  // MESAJ SİLME FONKSİYONU
  Future<void> _mesajSil(String messageId, String messageText) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Mesajı Sil'),
          content: Text('"${messageText.length > 30 ? messageText.substring(0, 30) + '...' : messageText}" mesajını silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('sohbetler')
            .doc(_chatRoomId)
            .collection('mesajlar')
            .doc(messageId)
            .delete();

        debugPrint("✅ Mesaj başarıyla silindi: $messageId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mesaj başarıyla silindi"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        debugPrint("❌ Mesaj silme hatası: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Mesaj silinemedi: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // MESAJ GÖNDERME FONKSİYONU
  void _mesajGonder() async {
    if (_mesajController.text.trim().isEmpty || _currentUser == null) {
      return;
    }

    final messageText = _mesajController.text.trim();
    _mesajController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasText = false; 
    });

    try {
      if (_chatRoomId == 'hata_odasi') {
        throw Exception('Sohbet odası IDsi bulunamadı');
      }

      final chatRoomDocRef = _firestore.collection('sohbetler').doc(_chatRoomId);

      String hedefId;
      if (widget.diyetisyenId != null) {
        hedefId = widget.diyetisyenId!;
      } else {
        List<String> ids = _chatRoomId.split('_');
        try {
          hedefId = ids.firstWhere((id) => id != _currentUser!.uid);
        } catch (e) {
          hedefId = ids.isNotEmpty ? ids[0] : '';
        }
      }

      if (hedefId.isEmpty) {
        throw Exception('Hedef kullanıcı IDsi bulunamadı');
      }

      // Ana sohbet dökümanını güncelle
      await chatRoomDocRef.set({
        'katilimcilar': [_currentUser!.uid, hedefId],
        'katilimciAdlari': {
          _currentUser!.uid: _currentUserAdSoyad,
          hedefId: _hedefKullaniciAdi,
        },
        'sonMesaj': messageText,
        'sonMesajGonderen': _currentUserAdSoyad,
        'sonMesajTarihi': Timestamp.now(),
        'olusturulmaTarihi': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mesajı alt koleksiyona ekle
      await chatRoomDocRef.collection('mesajlar').add({
        'text': messageText,
        'gonderenId': _currentUser!.uid,
        'gonderenAdi': _currentUserAdSoyad,
        'tarih': Timestamp.now(),
      });

      debugPrint("✅ Mesaj başarıyla gönderildi: $messageText");

      // Mesaj gönderildikten hemen sonra en alta kaydır.
      _scrollToBottom();
      
    } catch (e) {
      debugPrint("❌ Mesaj gönderme hatası: $e");
      
      if (mounted) {
        _mesajController.text = messageText;
        setState(() {
          _hasText = true; 
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Mesaj gönderilemedi: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(messageTime);
    } else if (difference.inDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(messageTime)}';
    } else {
      return DateFormat('dd MMM HH:mm').format(messageTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_hedefKullaniciAdi)),
        body: const Center(
          child: Text("Lütfen giriş yapın"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hedefKullaniciAdi,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              "Çevrimiçi",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.green,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Stream'i initState'de tanımlanan değişkenden al
              stream: _mesajStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Mesajlar yüklenirken hata oluştu",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz mesaj yok",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "İlk mesajı siz gönderin!",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final messageId = message.id; 
                    final isMe = data['gonderenId'] == _currentUser!.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                radius: 16,
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          
                          GestureDetector(
                            onLongPress: isMe
                                ? () {
                                    _mesajSil(messageId, data['text'] ?? '');
                                  }
                                : null, 
                            
                            child: Flexible( 
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe 
                                      ? const Color(0xFFE8F5E8) 
                                      : Colors.grey[200], 
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isMe 
                                        ? const Radius.circular(20)
                                        : const Radius.circular(4),
                                    bottomRight: isMe 
                                        ? const Radius.circular(4)
                                        : const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          data['gonderenAdi'] ?? 'Kullanıcı',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isMe ? Colors.green[900] : Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                    
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTime(data['tarih']),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMe 
                                              ? Colors.green[700] 
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // MESAJ GÖNDERME ALANI
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _mesajController,
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (_hasText && !_isLoading) {
                          _mesajGonder();
                        }
                      },
                      maxLines: null,
                    ),
                  ),
                ),

                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.green,
                    onPressed: _hasText && !_isLoading ? _mesajGonder : null, 
                  ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mesajController.removeListener(_onTextChanged); 
    _scrollController.dispose();
    _mesajController.dispose();
    super.dispose();
  }
}