import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profil_ekrani.dart';
import 'yemek_gunlugu_ekrani.dart'; // Besin Günlüğü ekranı
import 'su_takibi_ekrani.dart';
import 'diyetisyen_listesi_ekrani.dart';
import '../yapay_zeka/ai_sohbet_ekrani.dart'; // Yapay zeka sohbet ekranını import

class NavigationController extends StatefulWidget {
  const NavigationController({super.key});

  @override
  State<NavigationController> createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  int _seciliIndex = 0;
  final _currentUser = FirebaseAuth.instance.currentUser;

  late final List<Widget> _ekranlar;

  @override
  void initState() {
    super.initState();
    
    _ekranlar = [
      // 0: Profil
      ProfilEkrani(
        userId: _currentUser!.uid,
      ),
      // 1: Besin Günlüğü
      const YemekGunluguEkrani(),
      // 2: Su Takibi
      const SuTakibiEkrani(),
      // 3: Diyetisyen
      const DiyetisyenListesiEkrani(),
      // 4: YENİ: Sanal Asistan
      const AiSohbetEkrani(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _seciliIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text("Lütfen tekrar giriş yapın.")));
    }
    
    return Scaffold(
      body: IndexedStack(
        index: _seciliIndex,
        children: _ekranlar,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), 
            label: 'Ana Sayfa', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Besin Günlüğü',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop_outlined),
            activeIcon: Icon(Icons.water_drop),
            label: 'Su Takibi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search_outlined), 
            activeIcon: Icon(Icons.person_search),
            label: 'Diyetisyen',
          ),
          // YENİ: 5. Sekme
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined), // Yapay zeka ikonu
            activeIcon: Icon(Icons.smart_toy),
            label: 'Sanal Asistan',
          ),
        ],
        currentIndex: _seciliIndex,
        selectedItemColor: Colors.green, 
        unselectedItemColor: Colors.grey[600], 
        onTap: _onItemTapped, 
        type: BottomNavigationBarType.fixed, // 4+ item için sabit mod
        showUnselectedLabels: true, 
        backgroundColor: Theme.of(context).cardColor,
        elevation: 5, 
      ),
    );
  }
}