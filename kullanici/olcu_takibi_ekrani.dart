import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class OlcuTakibiEkrani extends StatefulWidget {
  const OlcuTakibiEkrani({super.key});

  @override
  State<OlcuTakibiEkrani> createState() => _OlcuTakibiEkraniState();
}

class _OlcuTakibiEkraniState extends State<OlcuTakibiEkrani> {
  late final Stream<QuerySnapshot> _measurementsStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _measurementsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('olcuKayitlari')
          .orderBy('tarih', descending: false) // Grafiğin doğru çizilmesi için tarihi artan yapıldı
          .snapshots();
    } else {
      _measurementsStream = const Stream.empty();
    }
  }

  Future<void> _deleteMeasurement(String docId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('olcuKayitlari')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Ölçüm başarıyla silindi."),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ölçü Takibi"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _measurementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Henüz ölçüm kaydınız bulunmuyor.\nEklemek için '+' butonuna basın.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final measurements = snapshot.data!.docs;
          
          // Grafik verisi hesaplaması burada, build içinde sadece bir kez yapılır
          final spots = <FlSpot>[];
          for (int i = 0; i < measurements.length; i++) {
            final data = measurements[i].data() as Map<String, dynamic>;
            // Kilo null değilse ve double'a çevrilebiliyorsa ekle
            if(data['kilo'] != null) {
               spots.add(FlSpot(i.toDouble(), (data['kilo'] as num).toDouble()));
            }
          }

          // Listeyi ekranda ters sırada (yeniden eskiye) göstermek için
          final reversedMeasurements = measurements.reversed.toList();

          return Column(
            children: [
              _buildChart(spots), // Grafiğe doğrudan hesaplanmış veriyi gönderme
              Expanded(
                child: ListView.builder(
                  itemCount: reversedMeasurements.length,
                  itemBuilder: (context, index) {
                    final measurement = reversedMeasurements[index];
                    final data = measurement.data() as Map<String, dynamic>;
                    final kilo = (data['kilo'] as num?)?.toDouble() ?? 0.0;
                    final belCevresi = (data['belCevresi'] as num?)?.toDouble() ?? 0.0;
                    final tarih = (data['tarih'] as Timestamp).toDate();

                    return Dismissible(
                      key: Key(measurement.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _deleteMeasurement(measurement.id);
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading:
                              CircleAvatar(child: Text(kilo.toStringAsFixed(1))),
                          title: Text(
                              "${DateFormat.yMMMMd('tr').format(tarih)}"),
                          subtitle: Text(
                              "Bel Çevresi: ${belCevresi.toStringAsFixed(1)} cm"),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMeasurementDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // Metod artık doğrudan List<FlSpot> alıyor, hesaplama yapmıyor.
  Widget _buildChart(List<FlSpot> spots) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isNotEmpty ? spots : [const FlSpot(0, 0)],
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context) {
    final kiloController = TextEditingController();
    final belController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Yeni Ölçüm Ekle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kiloController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Kilo (örn: 65.5)"),
              ),
              TextField(
                controller: belController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Bel Çevresi (cm)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) return;

                final kilo = double.tryParse(kiloController.text.replaceAll(',', '.'));
                final belCevresi = double.tryParse(belController.text.replaceAll(',', '.'));

                if (kilo != null && belCevresi != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('olcuKayitlari')
                      .add({
                    'kilo': kilo,
                    'belCevresi': belCevresi,
                    'tarih': Timestamp.now(),
                  });
                  Navigator.pop(context);
                } else {
                   if(mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Lütfen geçerli sayılar girin."), backgroundColor: Colors.red),
                     );
                   }
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }
}

