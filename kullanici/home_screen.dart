import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../giris/login_screen.dart';
import '../yapay_zeka/ai_sohbet_ekrani.dart';
import 'yemek_ekleme_ekrani.dart';
import 'diyetisyen_listesi_ekrani.dart';
import 'profil_ekrani.dart';
import 'olcu_takibi_ekrani.dart';
import 'su_takibi_ekrani.dart';
import 'yemek_gunlugu_ekrani.dart'; 
import '../yapay_zeka/kamera_yiyecek_tanima_basit.dart';

class HomeScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String role;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Diyet Takip Ana Sayfa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Çıkış Yap",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            _WelcomeCard(userName: userName),
            const SizedBox(height: 24),
            const Text(
              "İşlemler",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _RoleBasedMenu(
              role: role,
              userId: userId,
              userName: userName,
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String userName;
  const _WelcomeCard({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoş geldin, $userName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryInfo(title: "Bugünkü Kalori", value: "1500 kcal"),
                _SummaryInfo(title: "Son Kilo Kaydı", value: "72 kg"),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _SummaryInfo extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryInfo({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}

class _RoleBasedMenu extends StatelessWidget {
  final String role;
  final String userId;
  final String userName;

  const _RoleBasedMenu(
      {required this.role, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> danisanMenu = [
      {
        'label': 'Yemek Ekle',
        'icon': Icons.restaurant_menu,
        'page': const YemekEklemeEkrani()
      },
      // Besin Günlüğü butonu ve yeni ekrana yönlendirme
      {
        'label': 'Besin Günlüğü',
        'icon': Icons.menu_book,
        'page': const YemekGunluguEkrani()
      },
      {
        'label': 'Ölçü Takibi',
        'icon': Icons.monitor_weight_outlined,
        'page': const OlcuTakibiEkrani()
      },
      {
        'label': 'Diyetisyen Seç',
        'icon': Icons.people_alt_outlined,
        'page': const DiyetisyenListesiEkrani()
      },
      {
        'label': 'Su Takibi',
        'icon': Icons.water_drop_outlined,
        'page': const SuTakibiEkrani()
      },
      {
        'label': 'Sanal Asistan',
        'icon': Icons.smart_toy,
        'page': const AiSohbetEkrani()
      },
      {
        'label': 'Profil',
        'icon': Icons.person_outline,
        'page': ProfilEkrani(userId: userId)
      },
      {
        'label': 'Yiyecek Tanıma',
        'icon': Icons.camera_alt,
        'page': const KameraYiyecekTanima() 
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: danisanMenu.length,
      itemBuilder: (context, index) {
        final item = danisanMenu[index];
        return _MenuGridItem(
          label: item['label'],
          icon: item['icon'],
          onTap: () {
            if (item['page'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => item['page']),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${item['label']} sayfası yakında eklenecek!')),
              );
            }
          },
        );
      },
    );
  }
}

class _MenuGridItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuGridItem(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: Colors.green),
              const Spacer(),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

