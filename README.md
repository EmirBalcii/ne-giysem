# Ne Giysem?

Anlık hava durumu verilerini ve kullanıcının fiziksel özelliklerini (BMI) kullanarak kişiselleştirilmiş kıyafet önerileri sunan Flutter tabanlı mobil uygulama.

Uygulamanın temel amacı, standart hava durumu verilerini doğrudan kullanıcıya sunmak yerine, kullanıcının fiziksel özelliklerine göre hissedilen sıcaklığı algoritmik olarak yeniden hesaplayarak daha tutarlı bir giyim önerisi oluşturmaktır.

## Temel Özellikler

* Konum ve Hava Durumu Entegrasyonu: `geolocator` kullanılarak alınan koordinat bilgileri ile Open-Meteo API üzerinden anlık sıcaklık, hissedilen sıcaklık ve yağış durumu çekilir.
* Kişiselleştirilmiş Sıcaklık Modeli: Kullanıcının boy ve kilo verilerinden Vücut Kitle İndeksi (BMI) hesaplanır. Bu veriye göre API'den gelen hissedilen sıcaklık değeri yeniden kalibre edilir.
* Yerel Profil Yönetimi: Uygulama içerisinde çoklu kullanıcı profili (boy, kilo, yaş verileriyle) oluşturulabilir ve yönetilebilir. Veriler cihaz üzerinde `shared_preferences` ile saklanır.
* Dinamik Öneri Motoru: Gelen sıcaklık verisi ve seçilen giyim tarzına (Örn. Günlük, Spor, Klasik) uygun öneriler yerel bir JSON dosyasından asenkron olarak okunur.
* Reaktif Arayüz: Mevcut hava koşullarına (yağışlı, sıcak, soğuk vb.) göre uygulamanın renk paleti ve arka plan görselleri dinamik olarak güncellenir.

## Teknolojiler ve Bağımlılıklar

* Çatı: Flutter / Dart
* Ağ İstekleri: `http` (Open-Meteo API)
* Konum Servisleri: `geolocator`
* Veri Saklama: `shared_preferences`

## Kurulum ve Çalıştırma

Projeyi yerel ortamınızda derlemek için aşağıdaki adımları takip edebilirsiniz.

1. Repoyu bilgisayarınıza klonlayın:
   ```bash
   git clone [https://github.com/KULLANICI_ADINIZ/ne-giysem.git](https://github.com/KULLANICI_ADINIZ/ne-giysem.git)
