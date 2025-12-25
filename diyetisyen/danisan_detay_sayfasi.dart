import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../kullanici/mesajlasma_ekrani.dart';

class DanisanDetaySayfasi extends StatefulWidget {
  final String danisanId;
  final String danisanAdi;
  final String? sohbetOdasiId;

  const DanisanDetaySayfasi({
    super.key,
    required this.danisanId,
    required this.danisanAdi,
    this.sohbetOdasiId,
  });

  @override
  State<DanisanDetaySayfasi> createState() => _DanisanDetaySayfasiState();
}

class _DanisanDetaySayfasiState extends State<DanisanDetaySayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // TARİH PARSER
  // String formatındaki (GG/AA/YYYY) tarihi düzgünce DateTime'a çevirir
  DateTime? _parseTarih(dynamic tarih) {
    if (tarih == null) return null;

    if (tarih is Timestamp) {
      return tarih.toDate();
    } else if (tarih is String) {
      try {
        // Önce "GG/AA/YYYY" formatı (Türk formatı)
        if (tarih.contains('/')) {
          return DateFormat('dd/MM/yyyy').parse(tarih);
        }
        // Standart ISO formatı
        return DateTime.parse(tarih);
      } catch (e) {
        debugPrint('Tarih parse hatası: $e');
        return null; // Hata varsa null dön, bugünü dönme
      }
    }
    return null;
  }

  //YAŞ HESAPLAMA
  String _yasHesapla(dynamic dogumTarihiData) {
    final dogumTarihi = _parseTarih(dogumTarihiData);
    if (dogumTarihi == null) return 'Belirtilmemiş';

    final bugun = DateTime.now();
    int yas = bugun.year - dogumTarihi.year;
    
    // Henüz doğum günü gelmediyse yaşı 1 düşür
    if (bugun.month < dogumTarihi.month ||
        (bugun.month == dogumTarihi.month && bugun.day < dogumTarihi.day)) {
      yas--;
    }
    return yas.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.danisanAdi),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.green),
          actions: [
            if (widget.sohbetOdasiId != null)
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MesajlasmaEkrani(
                        sohbetOdasiId: widget.sohbetOdasiId,
                        hedefKullaniciAdi: widget.danisanAdi,
                      ),
                    ),
                  );
                },
                tooltip: 'Mesaj Gönder',
              ),
          ],
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Bilgiler'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Yemek Kayıtları'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGenelBilgiler(context),
            _buildYemekKayitlari(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGenelBilgiler(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(widget.danisanId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profil Özeti
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.person, size: 30, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.danisanAdi,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(userData['email'] ?? '', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Kişisel Bilgiler
            const Text("Kişisel Bilgiler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            _buildInfoRow('Yaş', _yasHesapla(userData['dogumTarihi'])), 
            _buildInfoRow('Cinsiyet', userData['cinsiyet'] ?? 'Belirtilmemiş'),
            _buildInfoRow('Boy', userData['boy'] != null ? '${userData['boy']} cm' : '-'),
            _buildInfoRow('Mevcut Kilo', userData['kilo'] != null ? '${userData['kilo']} kg' : '-'),
            _buildInfoRow('Hedef Kilo', userData['hedefKilo'] != null ? '${userData['hedefKilo']} kg' : '-'),
            
            const SizedBox(height: 24),

            // Diğer Bilgiler
            const Text("Diğer Detaylar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            _buildInfoRow('Aktivite', userData['aktiviteSeviyesi'] ?? '-'),
            _buildInfoRow('Özel Durumlar', userData['ozelDurumlar'] ?? '-'),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildYemekKayitlari(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(widget.danisanId)
          .collection('yemekKayitlari')
          .orderBy('tarih', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz yemek kaydı yok.', style: TextStyle(color: Colors.grey)));
        }

        var kayitlar = snapshot.data!.docs;

        // BUGÜN HESAPLAMASI
        DateTime simdi = DateTime.now();
        String bugunString = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(simdi);
        
        double bugunkuToplam = 0;
        int bugunkuOgunSayisi = 0;

        for (var kayit in kayitlar) {
          var data = kayit.data() as Map<String, dynamic>;
          // Tarih parse ederken hata olursa bugünü bozmaması için güvenli kontrol
          DateTime? kayitTarihi = _parseTarih(data['tarih']);
          if (kayitTarihi != null) {
            String kayitTarihString = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(kayitTarihi);
            if (kayitTarihString == bugunString) {
              bugunkuToplam += (data['kalori'] ?? 0).toDouble();
              bugunkuOgunSayisi++;
            }
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                color: Colors.green[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.today, color: Colors.green, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bugünkü Tüketim', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                          Text('${bugunkuToplam.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('$bugunkuOgunSayisi öğün', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kayitlar.length,
                itemBuilder: (context, index) {
                   var data = kayitlar[index].data() as Map<String, dynamic>;
                   var tarih = _parseTarih(data['tarih']) ?? DateTime.now();
                   
                   return Card(
                     margin: const EdgeInsets.only(bottom: 8),
                     child: ListTile(
                       leading: const Icon(Icons.fastfood, color: Colors.orange),
                       title: Text(data['yemekAdi'] ?? 'İsimsiz'),
                       subtitle: Text('${data['ogun'] ?? '-'} • ${DateFormat('d MMM HH:mm', 'tr_TR').format(tarih)}'),
                       trailing: Text('${data['kalori'] ?? 0} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}