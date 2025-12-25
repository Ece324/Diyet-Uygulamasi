import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HedefDuzenleEkrani extends StatefulWidget {
  final Map<String, dynamic> mevcutHedefler;

  const HedefDuzenleEkrani({super.key, required this.mevcutHedefler});

  @override
  State<HedefDuzenleEkrani> createState() => _HedefDuzenleEkraniState();
}

class _HedefDuzenleEkraniState extends State<HedefDuzenleEkrani> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _kaloriController;
  late TextEditingController _suController;
  late TextEditingController _kiloController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kaloriController = TextEditingController(
        text: (widget.mevcutHedefler['kalori'] ?? 2000).toString());
    _suController = TextEditingController(
        text: (widget.mevcutHedefler['su'] ?? 2.5).toString());
    _kiloController = TextEditingController(
        text: (widget.mevcutHedefler['kilo'] ?? 60).toString());
  }

  @override
  void dispose() {
    _kaloriController.dispose();
    _suController.dispose();
    _kiloController.dispose();
    super.dispose();
  }

  Future<void> _hedefleriKaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final hedefler = {
        'kalori': int.tryParse(_kaloriController.text) ?? 2000,
        'su': double.tryParse(_suController.text) ?? 2.5,
        'kilo': double.tryParse(_kiloController.text) ?? 60.0,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'hedefler': hedefler});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hedefler başarıyla güncellendi!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hedefleri Düzenle"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _kaloriController,
                decoration: const InputDecoration(
                  labelText: 'Günlük Kalori Hedefi (kcal)',
                  prefixIcon: Icon(Icons.local_fire_department),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Lütfen bir değer girin' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _suController,
                decoration: const InputDecoration(
                  labelText: 'Günlük Su Hedefi (Litre)',
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    value!.isEmpty ? 'Lütfen bir değer girin' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _kiloController,
                decoration: const InputDecoration(
                  labelText: 'Hedef Kilo (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    value!.isEmpty ? 'Lütfen bir değer girin' : null,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _hedefleriKaydet,
                      child: const Text('Kaydet'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
