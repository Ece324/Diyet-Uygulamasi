import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class YemekGunluguEkrani extends StatefulWidget {
  const YemekGunluguEkrani({super.key});

  @override
  State<YemekGunluguEkrani> createState() => _YemekGunluguEkraniState();
}

class _YemekGunluguEkraniState extends State<YemekGunluguEkrani> {
  late final Stream<QuerySnapshot> _yemekStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _yemekStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('yemekKayitlari')
          .orderBy('tarih', descending: true) // En yeni kayıtlar üstte
          .snapshots();
    } else {
      _yemekStream = const Stream.empty();
    }
  }

  Future<void> _yemekKaydiniSil(String docId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('yemekKayitlari')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Yemek kaydı başarıyla silindi.'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Kayıt silinemedi. $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Besin Günlüğüm'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _yemekStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Henüz hiç yemek kaydı eklemediniz.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Verileri tarihe göre gruplama
          final groupedByDate = groupBy<QueryDocumentSnapshot, String>(
            docs,
            (doc) => DateFormat('d MMMM yyyy, EEEE', 'tr_TR')
                .format((doc['tarih'] as Timestamp).toDate()),
          );

          return ListView.builder(
            itemCount: groupedByDate.keys.length,
            itemBuilder: (context, index) {
              final date = groupedByDate.keys.elementAt(index);
              final itemsForDate = groupedByDate[date]!;
              int toplamKalori = itemsForDate.fold(
                  0, (sum, item) => sum + ((item['kalori'] ?? 0) as int));

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '$toplamKalori kcal',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      ...itemsForDate.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _yemekKaydiniSil(doc.id),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: ListTile(
                            title: Text(data['yemekAdi'] ?? 'İsimsiz Yemek'),
                            subtitle: Text(data['ogun'] ?? 'Belirtilmemiş'),
                            trailing: Text('${data['kalori'] ?? 0} kcal',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
