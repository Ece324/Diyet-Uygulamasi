import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SuTakibiEkrani extends StatefulWidget {
  const SuTakibiEkrani({super.key});

  @override
  State<SuTakibiEkrani> createState() => _SuTakibiEkraniState();
}

class _SuTakibiEkraniState extends State<SuTakibiEkrani> {
  late final Stream<DocumentSnapshot> _waterStream;
  final int _hedef = 2500; // 2.5 Litre

  @override
  void initState() {
    super.initState();
    // Bu kod, ekran ilk açıldığında SADECE BİR KERE çalışır.
    // Bu sayede sonsuz döngüye girme sorununu çözülür.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _waterStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('suTakibi')
          .doc(todayDocId)
          .snapshots();
    } else {
      // Kullanıcı bulunamadı durumu için boş bir stream oluşturulur
      _waterStream = const Stream.empty();
    }
  }

  Future<void> _suEkle(int miktar) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('suTakibi')
        .doc(todayDocId);

    await docRef.set({
      'miktar': FieldValue.increment(miktar),
      'tarih': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Su Takibi"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _waterStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildContent(0);
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final anlikMiktar = data['miktar'] ?? 0;
          return _buildContent(anlikMiktar);
        },
      ),
    );
  }

  Widget _buildContent(int anlikMiktar) {
    double yuzde = (anlikMiktar / _hedef).clamp(0, 1);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                "Bugünkü Hedef: $_hedef ml",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: yuzde,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(
                            "$anlikMiktar ml",
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "%${(yuzde * 100).toInt()}",
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSuEkleButton(150, "Küçük Bardak"),
                  _buildSuEkleButton(250, "Normal Bardak"),
                  _buildSuEkleButton(500, "Şişe"),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuEkleButton(int miktar, String label) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _suEkle(miktar),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.lightBlue.shade100,
            foregroundColor: Colors.blue.shade800,
          ),
          child: const Icon(Icons.add, size: 30),
        ),
        const SizedBox(height: 8),
        Text("$miktar ml\n($label)", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }
}

