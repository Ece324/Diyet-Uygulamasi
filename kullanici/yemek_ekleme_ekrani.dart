import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class YemekEklemeEkrani extends StatefulWidget {
  const YemekEklemeEkrani({super.key});

  @override
  State<YemekEklemeEkrani> createState() => _YemekEklemeEkraniState();
}

class _YemekEklemeEkraniState extends State<YemekEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _yemekAdiController = TextEditingController();
  final _kaloriController = TextEditingController();
  String? _seciliOgun = 'Kahvaltı';
  bool _isLoading = false;

  final List<String> _ogunler = [
    'Kahvaltı',
    'Öğle Yemeği',
    'Akşam Yemeği',
    'Ara Öğün'
  ];
  final Map<String, int> _yemekVeriSeti = {
    'Haşlanmış Yumurta (1 adet)': 78,
    'Beyaz Peynir (1 dilim)': 90,
    'Domates (1 adet)': 22,
    'Salatalık (1 adet)': 15,
    'Zeytin (5 adet)': 25,
    'Izgara Tavuk Göğsü (100g)': 165,
    'Bulgur Pilavı (1 porsiyon)': 150,
    'Yeşil Salata (1 porsiyon)': 50,
    'Mercimek Çorbası (1 kase)': 120,
    'Izgara Somon (100g)': 208,
    'Elma (1 adet)': 95,
    'Muz (1 adet)': 105,
    'Yoğurt (1 kase)': 150,
    'Ceviz (3 adet)': 100,
  };

  Future<void> _yemekKaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      //... Hata yönetimi ...
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('yemekKayitlari')
          .add({
        'yemekAdi': _yemekAdiController.text,
        'kalori': int.tryParse(_kaloriController.text) ?? 0,
        'ogun': _seciliOgun,
        'tarih': Timestamp.now(),
      });

      _yemekAdiController.clear();
      _kaloriController.clear();
      FocusScope.of(context).unfocus(); // Klavyeyi kapatma
    } catch (e) {
      //Hata yönetimi 
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yemek Ekle"),
      ),
      body: Column(
        children: [
          _buildYemekEklemeFormu(),
          const Divider(height: 1),
          _buildGununYemekleriListesi(),
        ],
      ),
    );
  }

  Widget _buildYemekEklemeFormu() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Otomatik tamamlama özellikli yemek adı girişi
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') return const Iterable.empty();
                return _yemekVeriSeti.keys.where((item) => item
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (selection) {
                setState(() {
                  _yemekAdiController.text = selection;
                  _kaloriController.text = _yemekVeriSeti[selection].toString();
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Yemek Adı (Yazmaya başlayın)',
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Lütfen bir yemek adı girin.' : null,
                  onChanged: (_) => setState(() => _yemekAdiController.text = controller.text),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _seciliOgun,
                    items: _ogunler.map((ogun) =>
                        DropdownMenuItem(value: ogun, child: Text(ogun))).toList(),
                    onChanged: (value) => setState(() => _seciliOgun = value),
                    decoration: const InputDecoration(labelText: 'Öğün'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _kaloriController,
                    decoration: const InputDecoration(labelText: 'Kalori'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Gerekli' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _yemekKaydet,
                    icon: const Icon(Icons.add),
                    label: const Text('Ekle'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildGununYemekleriListesi() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Center(child: Text("Giriş yapın."));

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('yemekKayitlari')
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('tarih', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('tarih', descending: true)
        .snapshots();

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Bugün henüz yemek eklenmedi."));
          }

          int toplamKalori = snapshot.data!.docs.fold(0, (sum, doc) => sum + (doc['kalori'] as int));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Bugün Eklenenler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("$toplamKalori kcal", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final time = (data['tarih'] as Timestamp).toDate();

                    return Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                         FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('yemekKayitlari')
                          .doc(doc.id).delete();
                      },
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      child: ListTile(
                        title: Text(data['yemekAdi']),
                        subtitle: Text(data['ogun']),
                        leading: Text(DateFormat.Hm('tr_TR').format(time), style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Text('${data['kalori']} kcal'),
                      ),
                      
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

