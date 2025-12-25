import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KameraYiyecekTanima extends StatefulWidget {
  const KameraYiyecekTanima({super.key});

  @override
  State<KameraYiyecekTanima> createState() => _KameraYiyecekTanimaBasitState();
}

class _KameraYiyecekTanimaBasitState extends State<KameraYiyecekTanima> {
  File? _selectedImage;
  bool _isLoading = false;
  
  // Metin kontrolcüleri (Elle düzenleme yapabilmek için)
  final TextEditingController _yemekAdiController = TextEditingController();
  final TextEditingController _kaloriController = TextEditingController();
  
  String? _seciliOgun = 'Kahvaltı';
  
  // Groq API Bilgileri
  static const String _apiKey = "GROQ_API_ANAHTARINIZI_BURAYA_YAPISTIRIN"; 
  // Llama 4 Scout modeli, görsel destekli
  static const String _model = "meta-llama/llama-4-scout-17b-16e-instruct";

  final List<String> _ogunler = [
    'Kahvaltı', 'Öğle Yemeği', 'Akşam Yemeği', 'Ara Öğün'
  ];

  @override
  void dispose() {
    _yemekAdiController.dispose();
    _kaloriController.dispose();
    super.dispose();
  }

  // Fotoğraf çekme veya seçme
  Future<void> _resimSec(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 500, // API hızlı çalışsın diye resim küçük olsun
        maxHeight: 600,
        imageQuality: 30, // Kaliteyi düşürüyoruz (Data tasarrufu ve hız için)
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isLoading = true;
          _yemekAdiController.clear();
          _kaloriController.clear();
        });
        
        // AI Analizini Başlat
        await _aiIleYiyecekTanima();
      }
    } catch (e) {
      debugPrint('Resim seçme hatası: $e');
    }
  }

  // Groq API İstek Fonksiyonu
  Future<void> _aiIleYiyecekTanima() async {
    if (_selectedImage == null) return;
    
    setState(() => _isLoading = true); // Yükleniyor'u başlat

    try {
      // 1. GÖRSEL İŞLEME VE TEMİZLİK
      final bytes = await _selectedImage!.readAsBytes();
      // Base64 içindeki yeni satır (\n) karakterlerini silmek ÇOK ÖNEMLİDİR.
      // Yoksa 400 Bad Request hatası alınır.
      String base64Image = base64Encode(bytes).replaceAll('\n', '').replaceAll('\r', '');
      
      final imageUrl = "data:image/jpeg;base64,$base64Image";
      
      // 2. İSTEK GÖVDESİ (Vision 'Low Detail' Modu)
      final body = jsonEncode({
        'model': _model, 
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text', 
                'text': 'What is this food? Return ONLY the name and calories. '
                        'Format: "Food Name: Calories". '
                        'Example: "Doner Kebab: 350". '
                        'If unsure, guess the closest Turkish dish.'
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': imageUrl,
                  'detail': 'low' // BU SATIR 400 Hatasını önler
                }
              }
            ]
          }
        ],
        'max_tokens': 60,
        'temperature': 0.1, 
      });

      // 3. İSTEĞİ GÖNDER
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: body
      );

      debugPrint("API Durum Kodu: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        // BAŞARILI
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // Türkçe karakter sorunu olmasın
        final content = data['choices'][0]['message']['content'].toString();
        
        debugPrint("Gelen Cevap: $content");
        _cevabiAyikla(content);
        
      } else {
        // HATA DETAYI
        debugPrint("HATA GÖVDESİ: ${response.body}");
        final errorData = jsonDecode(response.body);
        String hataMesaji = errorData['error']['message'] ?? 'Bilinmeyen Hata';
        
        // Hatayı kullanıcıya göster ama uygulamayı çökertme
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata (${response.statusCode}): $hataMesaji'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        _manuelSecimListesiniAc(); // Hata olsa bile listeyi aç, kullanıcı devam etsin
      }
      
    } catch (e) {
      debugPrint('Sistem Hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: $e')),
        );
      }
      _manuelSecimListesiniAc();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cevabiAyikla(String text) {
    // Beklenen format: "Yemek Adı: Kalori"
    try {
      final parts = text.split(':');
      if (parts.length >= 2) {
        String yemek = parts[0].trim();
        // Kalori kısmındaki "kcal" vb yazıları temizle, sadece sayıyı al
        String kaloriStr = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        
        setState(() {
          _yemekAdiController.text = yemek;
          _kaloriController.text = kaloriStr;
        });
      } else {
        throw Exception("Format anlaşılamadı");
      }
    } catch (e) {
      _manuelSecimListesiniAc();
    }
  }

  // Manuel Seçim Listesi ve Elle Ekleme Dialogu
  void _manuelSecimListesiniAc() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yiyecek Seç veya Ekle'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // 1. Seçenek: Elle Gir
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Listede Yok / Elle Gir'),
                  subtitle: const Text('İsim ve kaloriyi kendin yaz'),
                  onTap: () {
                    Navigator.pop(context); // Listeyi kapat
                    _elleGirisDialogunuAc(); // Giriş ekranını aç
                  },
                ),
                const Divider(),
                // Diğer Hazır Seçenekler
                ..._yiyecekListesi.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    trailing: Text('${entry.value} kcal'),
                    onTap: () {
                      setState(() {
                        _yemekAdiController.text = entry.key;
                        _kaloriController.text = entry.value.toString();
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  // Manuel Giriş Dialogu
  void _elleGirisDialogunuAc() {
    // Dialog açılmadan önce içi boş olması için temizlenebilir
    // _yemekAdiController.clear();
    // _kaloriController.clear();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yiyecek Bilgilerini Gir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _yemekAdiController,
                decoration: const InputDecoration(
                  labelText: 'Yiyecek Adı',
                  hintText: 'Örn: Mercimek Çorbası',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _kaloriController,
                decoration: const InputDecoration(
                  labelText: 'Kalori (kcal)',
                  hintText: 'Örn: 200',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                // Değerler controller'da zaten var, sadece kapatıyoruz
                // Ekran güncellensin diye setState çağırabiliriz
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _yiyecekKaydet() async {
    if (_yemekAdiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir yiyecek adı girin')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      int kalori = int.tryParse(_kaloriController.text) ?? 0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('yemekKayitlari')
          .add({
        'yemekAdi': _yemekAdiController.text,
        'kalori': kalori,
        'ogun': _seciliOgun,
        'tarih': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_yemekAdiController.text} ($kalori kcal) eklendi!'),
          backgroundColor: Colors.green,
        ),
      );

      // Başarılı olunca alanları temizle
      setState(() {
        _selectedImage = null;
        _yemekAdiController.clear();
        _kaloriController.clear();
        _isLoading = false;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Basit yiyecek veritabanı (Liste için)
  final Map<String, int> _yiyecekListesi = {
    'Elma (1 adet)': 95,
    'Muz (1 adet)': 105,
    'Yumurta (1 adet)': 78,
    'Beyaz Peynir': 90,
    'Simit': 275,
    'Poğaça': 350,
    'Izgara Tavuk': 200,
    'Pilav': 250,
    'Lahmacun': 280,
    'İskender': 450,
    'Döner': 320,
    'Pizza Dilimi': 285,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yiyecek Tanıma'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // GÖRSEL ALANI
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _selectedImage == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 60, color: Colors.grey),
                          Text('Fotoğraf yok', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
            ),
            
            const SizedBox(height: 20),
            
            // BUTONLAR
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resimSec(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resimSec(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // YÜKLENİYOR İKONU
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 5),
                    Text("Yapay zeka yemeği inceliyor..."),
                  ],
                ),
              ),

            // DÜZENLEME FORMU
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Yiyecek Bilgileri", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 15),
                    
                    // Yemek Adı Girişi
                    TextField(
                      controller: _yemekAdiController,
                      decoration: const InputDecoration(
                        labelText: 'Yiyecek Adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fastfood),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Kalori Girişi
                    TextField(
                      controller: _kaloriController,
                      decoration: const InputDecoration(
                        labelText: 'Kalori (kcal)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_fire_department),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),
                    
                    // Öğün Seçimi
                    DropdownButtonFormField<String>(
                      value: _seciliOgun,
                      items: _ogunler.map((ogun) {
                        return DropdownMenuItem(value: ogun, child: Text(ogun));
                      }).toList(),
                      onChanged: (val) => setState(() => _seciliOgun = val),
                      decoration: const InputDecoration(
                        labelText: 'Öğün',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // MANUEL SEÇİM BUTONU
            TextButton.icon(
              onPressed: _manuelSecimListesiniAc,
              icon: const Icon(Icons.list),
              label: const Text('Listeden Seç veya Elle Gir'),
            ),

            const SizedBox(height: 10),
            
            // KAYDET BUTONU
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _yiyecekKaydet,
                icon: const Icon(Icons.save),
                label: const Text('Öğünü Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}