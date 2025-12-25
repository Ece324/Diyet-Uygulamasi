import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../giris/login_screen.dart'; 
import 'hedef_duzenle_ekrani.dart'; 

class ProfilEkrani extends StatefulWidget {
  final String userId;

  const ProfilEkrani({
    super.key,
    required this.userId,
  });

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Veritabanından kullanıcı bilgilerini ve hedeflerini tek seferde çek
  Stream<DocumentSnapshot> _getUserDataStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();
  }

  // O günkü verileri çekmek için (Kalori, Su)
  Stream<QuerySnapshot> _getTodayDataStream(String collectionName) {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection(collectionName)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('tarih', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();
  }
  
  // Son kilo verisini çekmek için
  Stream<QuerySnapshot> _getLatestWeightStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('olcuKayitlari')
        .orderBy('tarih', descending: true)
        .limit(1)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // hamburger menü butonu tasarımı
      appBar: AppBar(
        title: const Text("Kontrol Paneli"),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      // Hamburger menüye basınca açılacak yan menü
      drawer: _buildAppDrawer(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getUserDataStream(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.data!.exists) {
            return const Center(child: Text("Kullanıcı bulunamadı."));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final userName = userData['adSoyad'] ?? 'Kullanıcı Adı';
          final userAge = _calculateAge(userData['dogumTarihi']);
          final userGender = userData['cinsiyet'] ?? 'Belirtilmemiş';
          final hedefler =
              Map<String, dynamic>.from(userData['hedefler'] ?? {});

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildProfileHeader(userName, userAge, userGender),
              const SizedBox(height: 24),
              _buildTodaySummary(), // "Bugün" kısmı
              const SizedBox(height: 24),
              _buildGoalsSection(hedefler), // "Hedefler" kısmı
            ],
          );
        },
      ),
    );
  }

  // Yan menü widget'ı
  Drawer _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.green),
            child: Text(
              _currentUser?.email ?? 'Diyet Takip',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Ayarlar'),
            onTap: () {
              // Ayarlar sayfasına yönlendirme (ileride yapılabilir)
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış Yap'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Profil (Kullanıcı Adı, Yaş, Cinsiyet) başlığı
  Widget _buildProfileHeader(String name, int age, String gender) {
    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.green,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'E',
            style: const TextStyle(fontSize: 30, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(
              "$age, $gender",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  // "Bugün" özet kartları (Kalori, Su, Ağırlık)
  Widget _buildTodaySummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Bugün",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bugünkü Kalori Kartı
            StreamBuilder<QuerySnapshot>(
              stream: _getTodayDataStream('yemekKayitlari'),
              builder: (context, snapshot) {
                int bugunkuKalori = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    bugunkuKalori += (doc['kalori'] as int);
                  }
                }
                return _SummaryCard(
                    title: "Kalori",
                    value: bugunkuKalori.toString(),
                    unit: "kcal");
              }
            ),
            // Bugünkü Su Kartı
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('suTakibi')
                  .doc(DateFormat('yyyy-MM-dd').format(DateTime.now()))
                  .snapshots(),
              builder: (context, snapshot) {
                 double bugunkuSu = 0;
                 if (snapshot.hasData && snapshot.data!.exists) {
                   bugunkuSu = ((snapshot.data!.data() as Map<String, dynamic>)['miktar'] ?? 0).toDouble() / 1000;
                 }
                return _SummaryCard(title: "Su", value: bugunkuSu.toStringAsFixed(1), unit: "L");
              }
            ),
            // Son Ağırlık Kartı
            StreamBuilder<QuerySnapshot>(
               stream: _getLatestWeightStream(),
               builder: (context, snapshot) {
                 double sonKilo = 0;
                 if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    sonKilo = (snapshot.data!.docs.first['kilo'] ?? 0).toDouble();
                 }
                return _SummaryCard(title: "Ağırlık", value: sonKilo.toStringAsFixed(1), unit: "kg");
               }
            ),
          ],
        ),
      ],
    );
  }

  // "Hedefler" ilerleme çubukları
  Widget _buildGoalsSection(Map<String, dynamic> hedefler) {
    // Hedefleri al, yoksa varsayılan ata
    final hedefKalori = (hedefler['kalori'] ?? 2000).toDouble();
    final hedefSu = (hedefler['su'] ?? 2.5).toDouble();
    final hedefKilo = (hedefler['kilo'] ?? 60.0).toDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Hedefler",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            // Hedefleri düzenleme butonu
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.green),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HedefDuzenleEkrani(
                      mevcutHedefler: hedefler,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Kalori Hedef Çubuğu
        StreamBuilder<QuerySnapshot>(
          stream: _getTodayDataStream('yemekKayitlari'),
          builder: (context, snapshot) {
            int bugunkuKalori = 0;
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                bugunkuKalori += (doc['kalori'] as int);
              }
            }
            return _HedefProgressCard(
              title: "Kalori",
              mevcut: bugunkuKalori.toDouble(),
              hedef: hedefKalori,
              unit: "kcal",
            );
          }
        ),
        const SizedBox(height: 16),
        
        // Su Hedef Çubuğu
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('suTakibi')
              .doc(DateFormat('yyyy-MM-dd').format(DateTime.now()))
              .snapshots(),
          builder: (context, snapshot) {
            double bugunkuSu = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              bugunkuSu = ((snapshot.data!.data() as Map<String, dynamic>)['miktar'] ?? 0).toDouble() / 1000;
            }
            return _HedefProgressCard(
              title: "Su",
              mevcut: bugunkuSu,
              hedef: hedefSu,
              unit: "L",
            );
          }
        ),
        const SizedBox(height: 16),

        // Kilo Hedef Çubuğu
        StreamBuilder<QuerySnapshot>(
           stream: _getLatestWeightStream(),
           builder: (context, snapshot) {
             double sonKilo = 0;
             if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                sonKilo = (snapshot.data!.docs.first['kilo'] ?? 0).toDouble();
             }
             // Kilo için ilerleme mantığı farklıdır (hedefe ne kadar yaklaşıldı)
             // Bu basit bir implementasyondur, daha da geliştirilebilir.
             double baslangicKilo = 70; // Bu da veritabanından gelmeli
             double ilerleme = (baslangicKilo - sonKilo) / (baslangicKilo - hedefKilo);
             
            return _HedefProgressCard(
              title: "Ağırlık",
              mevcut: sonKilo,
              hedef: hedefKilo,
              unit: "kg",
              progressOverride: (sonKilo / hedefKilo).clamp(0,1), 
            );
           }
        ),
      ],
    );
  }

  // Yaşı hesapla (Doğum tarihi String "GG/AA/YYYY" formatında)
  int _calculateAge(String? birthDateString) {
    if (birthDateString == null) return 0;
    try {
      final parts = birthDateString.split('/');
      if (parts.length != 3) return 0;
      final birthDate =
          DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }
}

// "Bugün" kısmındaki küçük özet kartları için
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const _SummaryCard(
      {required this.title, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text("$value $unit",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// "Hedefler" kısmındaki ilerleme çubuğu kartları için
class _HedefProgressCard extends StatelessWidget {
  final String title;
  final double mevcut;
  final double hedef;
  final String unit;
  final double? progressOverride;

  const _HedefProgressCard({
    required this.title,
    required this.mevcut,
    required this.hedef,
    required this.unit,
    this.progressOverride,
  });

  @override
  Widget build(BuildContext context) {
    final double ilerleme = progressOverride ?? (mevcut / hedef).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text("${mevcut.toStringAsFixed(1)} / ${hedef.toStringAsFixed(1)} $unit",
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: ilerleme,
          backgroundColor: Colors.grey[300],
          color: Colors.green,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
