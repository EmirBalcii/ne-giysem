import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const DressWeatherApp());
}

class DressWeatherApp extends StatelessWidget {
  const DressWeatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ne Giysem?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class UserProfile {
  final String name;
  final double height;
  final double weight;
  final int age;

  UserProfile({
    required this.name,
    required this.height,
    required this.weight,
    required this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'height': height,
      'weight': weight,
      'age': age,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      height: (map['height'] as num).toDouble(),
      weight: (map['weight'] as num).toDouble(),
      age: map['age'],
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double? temperature;
  double? apparentTemperature;
  double? rain;
  String selectedStyle = 'Günlük';
  bool isLoading = false;
  String? errorMessage;

  Map<String, dynamic>? clothingData;

  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final List<String> styles = ['Günlük', 'Klasik', 'Spor'];

  List<UserProfile> savedProfiles = [];
  UserProfile? selectedProfile;

  @override
  void initState() {
    super.initState();
    loadClothingData().then((_) {
      fetchWeatherAndRecommend();
    });
    loadSavedProfiles();
  }

  @override
  void dispose() {
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> saveProfilesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(savedProfiles.map((p) => p.toMap()).toList());
    await prefs.setString('user_profiles', encodedData);
  }

  Future<void> loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profilesJson = prefs.getString('user_profiles');

    if (profilesJson != null) {
      final List<dynamic> decodedList = json.decode(profilesJson);
      setState(() {
        savedProfiles = decodedList.map((item) => UserProfile.fromMap(item)).toList();
        if (savedProfiles.isNotEmpty) {
          selectedProfile = savedProfiles.first;
          heightController.text = selectedProfile!.height.toStringAsFixed(0);
          weightController.text = selectedProfile!.weight.toStringAsFixed(0);
        }
      });
    }
  }

  void _showAddProfileDialog() {
    final nameInput = TextEditingController();
    final heightInput = TextEditingController();
    final weightInput = TextEditingController();
    final ageInput = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Profil Ekle', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameInput, decoration: const InputDecoration(labelText: 'İsim')),
              TextField(controller: heightInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Boy (cm)')),
              TextField(controller: weightInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilo (kg)')),
              TextField(controller: ageInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yaş')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (nameInput.text.isNotEmpty && heightInput.text.isNotEmpty && weightInput.text.isNotEmpty) {
                final newProfile = UserProfile(
                  name: nameInput.text,
                  height: double.tryParse(heightInput.text) ?? 175,
                  weight: double.tryParse(weightInput.text) ?? 70,
                  age: int.tryParse(ageInput.text) ?? 22,
                );
                setState(() {
                  savedProfiles.add(newProfile);
                  selectedProfile = newProfile;
                  heightController.text = newProfile.height.toStringAsFixed(0);
                  weightController.text = newProfile.weight.toStringAsFixed(0);
                });
                saveProfilesToStorage();
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteProfile(UserProfile profile) {
    setState(() {
      savedProfiles.remove(profile);
      if (savedProfiles.isNotEmpty) {
        selectedProfile = savedProfiles.first;
        heightController.text = selectedProfile!.height.toStringAsFixed(0);
        weightController.text = selectedProfile!.weight.toStringAsFixed(0);
      } else {
        selectedProfile = null;
        heightController.clear();
        weightController.clear();
      }
    });
    saveProfilesToStorage();
  }

Future<void> loadClothingData() async {
  try {
    final String response = await rootBundle.loadString('assets/clothing_data.json');
    setState(() {
      clothingData = json.decode(response)['tarzlar'];
      errorMessage = null; // Hata yoksa temizle
    });
  } catch (e) {
    setState(() {
      errorMessage = "HATA: JSON dosyası bulunamadı!"; // Eğer dosya yoksa ekrana bunu yazdır
    });
  }
}
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Konum servisleri kapalı.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Konum reddedildi.');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> fetchWeatherAndRecommend() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      Position position = await _determinePosition();
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,apparent_temperature,rain&timezone=auto');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        setState(() {
          temperature = current['temperature_2m'];
          apparentTemperature = current['apparent_temperature'];
          rain = current['rain'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { errorMessage = e.toString(); isLoading = false; });
    }
  }

  double getPersonalizedTemperature() {
    if (apparentTemperature == null) return 0.0;
    double temp = apparentTemperature!;
    double weight = double.tryParse(weightController.text) ?? 0;
    double heightCm = double.tryParse(heightController.text) ?? 0;
    if (weight > 0 && heightCm > 0) {
      double heightM = heightCm / 100;
      double bmi = weight / (heightM * heightM);
      if (bmi < 18.5) temp -= 3.0; else if (bmi > 25.0) temp += 3.0;
    }
    return temp;
  }

String getRecommendation() {
    if (apparentTemperature == null || clothingData == null) return "Veriler yükleniyor...";
    
    double temp = getPersonalizedTemperature(); // Senin BMI düzeltilmiş sıcaklığın
    
    // Default değer atadık ki hata vermesin
    String rec = "Hava biraz garip, ne giysen yakışır! 😎";
    
    List<dynamic> styleList = clothingData![selectedStyle] ?? [];
    
    for (var item in styleList) {
      double min = (item['min_temp'] as num).toDouble();
      double max = (item['max_temp'] as num).toDouble();
      
      // Sınırları "küçük eşittir" (<=) yaparak aralığı garantiledik
      if (temp >= min && temp <= max) {
        rec = item['recommendation'];
        break;
      }
    }
    
    if ((rain ?? 0) > 0) rec += "\n\n☔ Uyarı: Dışarıda yağış var, şemsiye almayı unutma!";
    return rec;
  }

  String _getBackgroundImage() {
    if (apparentTemperature == null) return 'assets/warm.jpg';
    if (rain! > 0) return 'assets/rainy.avif';
    double pTemp = getPersonalizedTemperature();
    if (pTemp >= 25) return 'assets/hot.jpg';
    else if (pTemp >= 15) return 'assets/warm.jpg';
    else return 'assets/cold.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundImage = _getBackgroundImage();
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Text('Bugün Ne Giysem?', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(image: DecorationImage(image: AssetImage(backgroundImage), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken))),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("Aktif Profil", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          IconButton(icon: const Icon(Icons.person_add, color: Colors.white), onPressed: _showAddProfileDialog)
                        ]),
                        if (savedProfiles.isEmpty) const Text("Henüz profil yok.", style: TextStyle(color: Colors.white70))
                        else Row(children: [
                          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<UserProfile>(value: selectedProfile, dropdownColor: Colors.blueGrey.shade900, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900), items: savedProfiles.map((p) => DropdownMenuItem(value: p, child: Text("${p.name} (${p.age})"))).toList(), onChanged: (p) => setState(() => selectedProfile = p!))))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteProfile(selectedProfile!))
                        ])
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Fiziksel Özellikler", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900), decoration: const InputDecoration(labelText: "Boy (cm)", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.height, color: Colors.white70)))),
                        const SizedBox(width: 15),
                        Expanded(child: TextField(controller: weightController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900), decoration: const InputDecoration(labelText: "Kilo (kg)", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.monitor_weight_outlined, color: Colors.white70))))
                      ])
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Builder(builder: (context) {
                    final isRainy = (rain ?? 0) > 0;
                    final pTemp = getPersonalizedTemperature();
                    final List<Color> weatherColors = isRainy
                        ? [const Color(0xFF4A90D9), const Color(0xFF2E5C8A)]
                        : pTemp >= 25
                        ? [const Color(0xFFFFB347), const Color(0xFFFF7E5F)]
                        : pTemp >= 15
                        ? [const Color(0xFFFFD56B), const Color(0xFFFF9966)]
                        : [const Color(0xFF6DD5FA), const Color(0xFF2980B9)];
                    final accentColor = isRainy ? Colors.blue : (pTemp >= 15 ? Colors.orange : Colors.lightBlue);
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 14)),
                          BoxShadow(color: accentColor.withOpacity(0.35), blurRadius: 40, spreadRadius: -6, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: weatherColors,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.25),
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                ),
                                child: Icon(isRainy ? Icons.water_drop : Icons.wb_sunny, size: 36, color: Colors.white),
                              ),
                              const SizedBox(width: 22),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(temperature != null ? "${temperature!.toStringAsFixed(1)}°C" : "--°C", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                                Text(isRainy ? "Yağışlı" : "Açık Hava", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85), letterSpacing: 0.3)),
                              ])
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 14)),
                        BoxShadow(color: Colors.deepPurple.withOpacity(0.35), blurRadius: 40, spreadRadius: -6, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8E6FE0), Color(0xFF5B3FA8)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.checkroom, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text("Senin İçin Önerimiz", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                            ]),
                            Container(height: 1, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(vertical: 14)),
                            Text(getRecommendation(), style: TextStyle(fontSize: 16, height: 1.7, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w500))
                          ]),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: fetchWeatherAndRecommend,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple.shade700,
        label: const Text("Yenile", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

