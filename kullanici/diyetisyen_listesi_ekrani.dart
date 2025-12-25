import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mesajlasma_ekrani.dart';

class DiyetisyenListesiEkrani extends StatelessWidget {
  const DiyetisyenListesiEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Giriş yapmalısınız.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diyetisyen Seç'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('rol', isEqualTo: 'diyetisyen')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Firestore Hatası: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      "Veriler yüklenirken hata oluştu",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("Veri yok"));
          }

          final diyetisyenler = snapshot.data!.docs;
          debugPrint('${diyetisyenler.length} adet diyetisyen bulundu');

          // Debug: Tüm diyetisyenleri konsola yazdır
          for (var diyetisyen in diyetisyenler) {
            final data = diyetisyen.data() as Map<String, dynamic>;
            debugPrint('Diyetisyen: ${data['adSoyad']} - ID: ${diyetisyen.id} - Rol: ${data['rol']}');
          }

          if (diyetisyenler.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "Sistemde kayıtlı diyetisyen bulunamadı.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: diyetisyenler.length,
            itemBuilder: (context, index) {
              final diyetisyen = diyetisyenler[index];
              final data = diyetisyen.data() as Map<String, dynamic>;

              // Kendi kullanıcınızı listeden çıkarın
              if (diyetisyen.id == currentUser.uid) {
                return const SizedBox.shrink(); // Gizle
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(data['adSoyad'] ?? 'İsimsiz Diyetisyen',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['uzmanlikAlani'] ?? 'Genel Beslenme'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MesajlasmaEkrani(
                          diyetisyenId: diyetisyen.id,
                          diyetisyenAdi: data['adSoyad'] ?? 'İsimsiz Diyetisyen',
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
    );
  }
}