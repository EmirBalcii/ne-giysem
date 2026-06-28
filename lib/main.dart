import 'package:flutter/services.dart' show rootBundle; // Hata düzeldi: .show yerine .dart oldu
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

// Profil verilerini JSON formatına uygun hale getiren Model Sınıfımız
class UserProfile {
  final String name;
  final double height;
  final double weight;
  final int age;
  final String gender;

  UserProfile({
    required this.name,
    required this.height,
    required this.weight,
    required this.age,
    this.gender = 'Erkek',
  });

  // Nesneyi JSON'a (Map yapısına) dönüştüren fonksiyon (Yazarken kullanılır)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'height': height,
      'weight': weight,
      'age': age,
      'gender': gender,
    };
  }

  // JSON'dan (Map yapısından) geri nesne üreten fonksiyon (Okurken kullanılır)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      height: (map['height'] as num).toDouble(),
      weight: (map['weight'] as num).toDouble(),
      age: map['age'],
      gender: map['gender'] ?? 'Erkek',
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
  String selectedGender = 'Erkek';

  @override
  void initState() {
    super.initState();
    loadClothingData().then((_) {
      fetchWeatherAndRecommend();
    });
    loadSavedProfiles(); // Uygulama açıldığında diskteki JSON verilerini oku
  }

  @override
  void dispose() {
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  // DİSKE KAYDETME: Profilleri JSON metnine çevirip kalıcı olarak kaydeder
  Future<void> saveProfilesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    // Tüm listeyi map'leyip JSON String formatına sokuyoruz
    final String encodedData = json.encode(savedProfiles.map((p) => p.toMap()).toList());
    await prefs.setString('user_profiles', encodedData);
  }

  // DİSKTEN OKUMA: Uygulama açıldığında sıfırlanmayı önleyen fonksiyon
  Future<void> loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profilesJson = prefs.getString('user_profiles');

    if (profilesJson != null) {
      // Diskte veri varsa, JSON metnini çözüp listemize dolduruyoruz
      final List<dynamic> decodedList = json.decode(profilesJson);
      setState(() {
        savedProfiles = decodedList.map((item) => UserProfile.fromMap(item)).toList();
        if (savedProfiles.isNotEmpty) {
          selectedProfile = savedProfiles.first;
          heightController.text = selectedProfile!.height.toStringAsFixed(0);
          weightController.text = selectedProfile!.weight.toStringAsFixed(0);
          selectedGender = selectedProfile!.gender;
        }
      });
    }
  }

  void _showAddProfileDialog() {
    final nameInput = TextEditingController();
    final heightInput = TextEditingController();
    final weightInput = TextEditingController();
    final ageInput = TextEditingController();
    String dialogGender = 'Erkek';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yeni Profil Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameInput, decoration: const InputDecoration(labelText: 'İsim')),
                  TextField(controller: heightInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Boy (cm)')),
                  TextField(controller: weightInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilo (kg)')),
                  TextField(controller: ageInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yaş')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cinsiyet', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Erkek', label: Text('Erkek'), icon: Icon(Icons.male)),
                      ButtonSegment(value: 'Kadın', label: Text('Kadın'), icon: Icon(Icons.female)),
                    ],
                    selected: {dialogGender},
                    onSelectionChanged: (Set<String> newSelection) {
                      setDialogState(() {
                        dialogGender = newSelection.first;
                      });
                    },
                  ),
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
                      gender: dialogGender,
                    );
                    setState(() {
                      savedProfiles.add(newProfile);
                      selectedProfile = newProfile;
                      heightController.text = newProfile.height.toStringAsFixed(0);
                      weightController.text = newProfile.weight.toStringAsFixed(0);
                      selectedGender = newProfile.gender;
                    });
                    saveProfilesToStorage(); // JSON olarak diske yaz
                    Navigator.pop(context);
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
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
        selectedGender = selectedProfile!.gender;
      } else {
        selectedProfile = null;
        heightController.clear();
        weightController.clear();
        selectedGender = 'Erkek';
      }
    });
    saveProfilesToStorage(); // Güncel listeyi diske tekrar yaz
  }

  Future<void> loadClothingData() async {
    try {
      final String response = await rootBundle.loadString('assets/clothing_data.json');
      final data = json.decode(response);
      setState(() {
        clothingData = data['tarzlar'];
      });
    } catch (e) {
      setState(() {
        errorMessage = "Kıyafet veri dosyası yüklenemedi: $e";
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Konum servisleri kapalı. Lütfen ayarlardan açın.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Konum izinleri reddedildi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Konum izinleri kalıcı olarak reddedildi.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> fetchWeatherAndRecommend() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      Position position = await _determinePosition();

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,apparent_temperature,rain&timezone=auto');

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
      } else {
        setState(() {
          errorMessage = 'Hava durumu verisi sunucudan alınamadı.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
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

      if (bmi < 18.5) {
        temp -= 3.0;
      } else if (bmi > 25.0) {
        temp += 3.0;
      }
    }
    return temp;
  }

  String getRecommendation() {
    if (apparentTemperature == null || rain == null) {
      return "Kombin önerisi için konum ve hava durumu verisi bekleniyor...";
    }

    if (clothingData == null) {
      return "Kıyafet verileri yükleniyor...";
    }

    double finalTempForLogic = getPersonalizedTemperature();
    String rec = "Bu sıcaklık aralığı için kombin bulunamadı.";

    // Önce cinsiyete göre tarz listesine iniyoruz, sonra seçili tarzı (Günlük/Klasik/Spor) alıyoruz
    Map<String, dynamic> genderData = clothingData![selectedGender] ?? clothingData!['Erkek'] ?? {};
    List<dynamic> styleList = genderData[selectedStyle] ?? [];

    for (var item in styleList) {
      double min = (item['min_temp'] as num).toDouble();
      double max = (item['max_temp'] as num).toDouble();

      if (finalTempForLogic >= min && finalTempForLogic < max) {
        rec = item['recommendation'];
        break;
      }
    }

    if (rain! > 0) {
      rec += "\n\n☔ Uyarı: Dışarıda yağış var veya bekleniyor! Yanına kesinlikle bir şemsiye veya yağmurluk al.";
    }

    return rec;
  }

  String _getBackgroundImage() {
    if (apparentTemperature == null) return 'assets/warm.jpg';
    if (rain! > 0) return 'assets/rainy.avif';

    double personalizedTemp = getPersonalizedTemperature();
    if (personalizedTemp >= 25) {
      return 'assets/hot.jpg';
    } else if (personalizedTemp >= 15) {
      return 'assets/warm.jpg';
    } else {
      return 'assets/cold.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundImage = _getBackgroundImage();

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Text(
            'Bugün Ne Giysem?',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(backgroundImage),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.35),
                BlendMode.darken,
              ),
              onError: (exception, stackTrace) {
                debugPrint("Resim bulunamadı: $backgroundImage");
              },
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profil Seçim ve Yönetim Alanı Kartı
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Aktif Profil",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.white),
                              onPressed: _showAddProfileDialog,
                              tooltip: "Yeni Profil Ekle",
                            )
                          ],
                        ),
                        if (savedProfiles.isEmpty)
                          const Text(
                            "Henüz kayıtlı profil yok. Sağ üstteki butondan ekle.",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<UserProfile>(
                                      value: selectedProfile,
                                      dropdownColor: Colors.blueGrey.shade900,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                      items: savedProfiles.map((UserProfile profile) {
                                        return DropdownMenuItem<UserProfile>(
                                          value: profile,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                profile.gender == 'Kadın' ? Icons.female : Icons.male,
                                                size: 16,
                                                color: Colors.white70,
                                              ),
                                              const SizedBox(width: 6),
                                              Text("${profile.name} (${profile.age} Yaş)"),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (UserProfile? newProfile) {
                                        if (newProfile != null) {
                                          setState(() {
                                            selectedProfile = newProfile;
                                            heightController.text = newProfile.height.toStringAsFixed(0);
                                            weightController.text = newProfile.weight.toStringAsFixed(0);
                                            selectedGender = newProfile.gender;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () {
                                  if (selectedProfile != null) {
                                    _deleteProfile(selectedProfile!);
                                  }
                                },
                              )
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Fiziksel Özellikler Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Fiziksel Özelliklerin (Manuel Değiştirebilirsin)",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 15),
                        SegmentedButton<String>(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                              if (states.contains(WidgetState.selected)) return Colors.white;
                              return Colors.black.withOpacity(0.1);
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                              if (states.contains(WidgetState.selected)) return Colors.black87;
                              return Colors.white;
                            }),
                            side: WidgetStateProperty.all(BorderSide.none),
                          ),
                          segments: const [
                            ButtonSegment(value: 'Erkek', label: Text('Erkek'), icon: Icon(Icons.male)),
                            ButtonSegment(value: 'Kadın', label: Text('Kadın'), icon: Icon(Icons.female)),
                          ],
                          selected: {selectedGender},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              selectedGender = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: heightController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: "Boy (cm)",
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(Icons.height, color: Colors.white70),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextField(
                                controller: weightController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: "Kilo (kg)",
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(Icons.monitor_weight_outlined, color: Colors.white70),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 10),
                    child: Text(
                      "Giyim Tarzını Seç:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: SegmentedButton<String>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) return Colors.white;
                          return Colors.transparent;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) return Colors.black87;
                          return Colors.white;
                        }),
                        side: WidgetStateProperty.all(BorderSide.none),
                      ),
                      segments: styles.map((style) {
                        return ButtonSegment<String>(
                          value: style,
                          label: Text(style, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      selected: {selectedStyle},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          selectedStyle = newSelection.first;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: (rain ?? 0) > 0
                            ? [Colors.blue.shade400, Colors.indigo.shade700]
                            : [Colors.orange.shade300, Colors.deepPurple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: ((rain ?? 0) > 0 ? Colors.indigo : Colors.deepPurple).withOpacity(0.35),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Dekoratif arka plan halkaları
                        Positioned(
                          right: -25,
                          top: -35,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -15,
                          bottom: -30,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(25),
                          child: isLoading
                              ? const Center(child: Padding(
                            padding: EdgeInsets.all(10.0),
                            child: CircularProgressIndicator(color: Colors.white),
                          ))
                              : errorMessage != null
                              ? Text(errorMessage!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.18),
                                ),
                                child: Icon(
                                  (rain ?? 0) > 0 ? Icons.water_drop : Icons.wb_sunny,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 25),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    temperature != null ? "${temperature!.toStringAsFixed(1)}°C" : "--°C",
                                    style: const TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                                    ),
                                  ),
                                  if (apparentTemperature != null)
                                    Text(
                                      "Hissedilen: ${apparentTemperature!.toStringAsFixed(1)}°C",
                                      style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.deepPurple.shade50],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.15),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Dekoratif köşe motifi
                        Positioned(
                          right: -30,
                          bottom: -30,
                          child: Icon(
                            Icons.checkroom,
                            size: 140,
                            color: Colors.deepPurple.withOpacity(0.06),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade500],
                                      ),
                                    ),
                                    child: const Icon(Icons.checkroom, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                      "Senin İçin Önerimiz",
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.deepPurple.withOpacity(0.3), Colors.deepPurple.withOpacity(0.0)],
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                getRecommendation(),
                                style: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
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
        elevation: 6,
        icon: const Icon(Icons.refresh, fontWeight: FontWeight.bold),
        label: const Text("Yenile", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      ),
    );
  }
}