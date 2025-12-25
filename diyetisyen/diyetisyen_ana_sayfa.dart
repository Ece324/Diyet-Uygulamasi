import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../giris/login_screen.dart';
import '../kullanici/mesajlasma_ekrani.dart';
import 'danisan_detay_sayfasi.dart';

class DiyetisyenAnaSayfa extends StatefulWidget {
  final String diyetisyenId;
  final String diyetisyenAdi;

  const DiyetisyenAnaSayfa({
    super.key,
    required this.diyetisyenId,
    required this.diyetisyenAdi,
  });

  @override
  State<DiyetisyenAnaSayfa> createState() => _DiyetisyenAnaSayfaState();
}

class _DiyetisyenAnaSayfaState extends State<DiyetisyenAnaSayfa> {
  late final Stream<QuerySnapshot> _sohbetlerStream;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _sohbetlerStream = FirebaseFirestore.instance
          .collection('sohbetler')
          .where('katilimcilar', arrayContains: _currentUser!.uid)
          .orderBy('sonMesajTarihi', descending: true)
          .snapshots();
    } else {
      _sohbetlerStream = Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Diyetisyen Paneli",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.green),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Çıkış Yap",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hoşgeldin Bölümü
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green[100],
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hoş geldin, ${widget.diyetisyenAdi}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Danışanlarını yönet ve takip et",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.green),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // İstatistikler
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sohbetler')
                  .where('katilimcilar', arrayContains: _currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                int danisanSayisi = snapshot.hasData ? snapshot.data!.docs.length : 0;
                
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.group, color: Colors.blue, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Danışan',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$danisanSayisi',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu, color: Colors.orange, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Aktif Takip',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$danisanSayisi',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Başlık
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Danışanlarım",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Danışan Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _sohbetlerStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Danışanlar yüklenirken hata oluştu",
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
                        Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz danışanınız yok",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Danışanlarınız burada görünecek",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final sohbetler = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sohbetler.length,
                  itemBuilder: (context, index) {
                    final sohbet = sohbetler[index];
                    final data = sohbet.data() as Map<String, dynamic>;
                    final katilimcilar = List<String>.from(data['katilimcilar'] ?? []);
                    final katilimciAdlari = Map<String, String>.from(data['katilimciAdlari'] ?? {});

                    final danisanId = katilimcilar.firstWhere(
                      (id) => id != _currentUser!.uid,
                      orElse: () => '',
                    );
                    
                    final danisanAdi = katilimciAdlari[danisanId] ?? "Danışan";
                    final sonMesaj = data['sonMesaj'] as String? ?? 'Henüz mesaj yok';
                    final sonMesajTarihi = data['sonMesajTarihi'] as Timestamp?;
                    final sonMesajGonderen = data['sonMesajGonderen'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.green[100],
                          child: Text(
                            danisanAdi.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          danisanAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              sonMesaj,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (sonMesajTarihi != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatTime(sonMesajTarihi),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'mesaj',
                              child: Row(
                                children: [
                                  Icon(Icons.message, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  const Text("Mesajlaş"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'detay',
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  const Text("Danışan Detayı"),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                               if (value == 'mesaj') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MesajlasmaEkrani(
                                      sohbetOdasiId: sohbet.id, // SOCHET ID'SİNİ GEÇ
                                      hedefKullaniciAdi: danisanAdi,
                                  ),
                                ),
                              );
                            } else if (value == 'detay') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DanisanDetaySayfasi(
                                    danisanId: danisanId,
                                    danisanAdi: danisanAdi,
                                    sohbetOdasiId: sohbet.id, // SOCHET ID'SİNİ GEÇ
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MesajlasmaEkrani(
                                sohbetOdasiId: sohbet.id, // SOCHET ID'SİNİ GEÇ
                                hedefKullaniciAdi: danisanAdi,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return 'Bugün ${DateFormat('HH:mm').format(messageTime)}';
    } else if (difference.inDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(messageTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'tr_TR').format(messageTime);
    } else {
      return DateFormat('dd MMM HH:mm', 'tr_TR').format(messageTime);
    }
  }
}