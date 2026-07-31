# DönerKebabMap — Proje Context

## Ne yapıyoruz
iOS uygulaması (Swift + SwiftUI). Amaç: kullanıcının konumuna göre yakındaki
döner/kebab/gyro satan yerleri Google Maps benzeri bir haritada göstermek.
Geliştirici (ben) QA engineer, yazılım/backend bilgisi sınırlı — adım adım,
basit ve net açıklamalarla ilerlenmesi gerekiyor. Konuşma dili Türkçe.

## Ürün gereksinimleri
- Uygulama açılışta doğrudan harita ekranı gösterir (TabView'in ilk sekmesi).
- Kullanıcı konumu etrafında ~20km yarıçapında döner/kebab/gyro yerleri
  harita üzerinde pin olarak gösterilir. Pin'in altında/yanında yerin ismi yazar.
- Pin'e tıklayınca alttan bir card (sheet) açılır: isim, kullanıcıya mesafe,
  adres, ve "Tarif Al" butonu.
- "Tarif Al" butonuna basınca Apple Haritalar / Google Haritalar seçenekleri
  çıkar (confirmationDialog), seçilen uygulama açılıp yol tarifi başlar.
- Alt sekmeler: **Harita**, **Liste** (aynı veri, mesafeye göre sıralı liste
  halinde, her satırda isim + mesafe), **Profil** (MVP'de basit: favoriler
  placeholder + hakkında).

## Mimari kararlar
- **Backend YOK** (MVP için gerek yok). Veri doğrudan cihazdan haritacılık
  servisine sorularak alınıyor.
- **Veri kaynağı: Apple MapKit (`MKLocalSearch`)** — ücretsiz, sınırsız,
  API key gerektirmiyor, Swift'e gömülü. "döner", "kebab", "kebap", "gyro",
  "dönerci" anahtar kelimeleriyle ayrı ayrı arama yapıp sonuçları birleştirip
  dedupe ediyoruz.
- **Google Places API'ye MVP'de geçilmedi** çünkü: ücretsiz kota ayda ~5.000
  arama ile sınırlı (Pro SKU), üstelik ücretsiz kotayı kullanmak için bile
  Google Cloud'da faturalandırma (kredi kartı) açman gerekiyor. İleride
  (V2) veri kalitesi yetersiz kalırsa değerlendirilecek.
- **OpenStreetMap / Overpass API** V1.1'de veri zenginleştirme için
  eklenmesi planlanan ikinci kaynak (özellikle Avrupa'da OSM'de dönerciler
  `cuisine=kebab` diye özel etiketli, isme bağımlı kalmıyoruz).
- Mimari pattern: **MVVM** (Models, ViewModels, Views, Services, Utilities
  klasörleri).

## Yol haritası
1. **MVP** (şu an bu aşamadayız): Harita + pin'ler + detay card + yol tarifi
   + liste ekranı + basit profil.
2. **V1.1:** Overpass API ile veri zenginleştirme, favoriler (SwiftData ile
   kalıcı hale getirme).
3. **V2:** Google Places API entegrasyonu (opsiyonel), kullanıcı hesabı /
   senkron için basit backend (muhtemelen Firebase).

## Şu ana kadar verilen promptlar (sırayla uygulandı)
1. Proje iskeleti: MVVM klasör yapısı, `DonerPlace` model, TabView (Harita/
   Liste/Profil) + boş placeholder view'lar.
2. `LocationManager`: CoreLocation, konum izni, `@Published userLocation`.
3. `PlacesSearchService`: MKLocalSearch ile 20km yarıçapta arama, anahtar
   kelime bazlı filtreleme, dedupe, mesafeye göre sıralama.
4. `MapTabView`: harita, custom pin (fork.knife ikonu + isim etiketi),
   pin tıklayınca sheet açma, kullanıcı konumu (mavi nokta).
5. `PlaceDetailCard`: alttan açılan sheet, isim/mesafe/adres/"Tarif Al" butonu.
6. `DirectionsHelper`: Apple Maps (`openInMaps`) ve Google Maps
   (`comgooglemaps://` scheme, yoksa web fallback) açma fonksiyonları,
   confirmationDialog entegrasyonu.
7. `ListTabView` + paylaşılan `PlacesViewModel` (arama tek seferde yapılıp
   hem Map hem List sekmesi aynı veriyi kullanıyor).
8. `ProfileTabView`: basit placeholder (favoriler boş state + hakkında).
9. Kod incelemesi + hata düzeltmeleri: `LocationManager` hata yönetimi ve
   init temizliği; `MapTabView`'de her konum güncellemesinde tekrar arama
   yapan hata giderildi (artık ilk konumda tek sefer).
10. Refactor: paylaşılan `PlacesViewModel` `ContentView`'de `@StateObject`
    olarak oluşturulup her iki sekmeye `.environmentObject` ile enjekte edildi;
    arama merkezi olarak (sekmeden bağımsız) tek sefer tetikleniyor.
    `ListTabView` tamamlandı (mesafeye göre sıralı liste, satıra tıklayınca
    `PlaceDetailCard` sheet). `DonerPlace`'e `formattedDistance` eklendi.
11. Harita temizliği: `.mapStyle(.standard(pointsOfInterest: .excludingAll))`
    ile Apple Maps'in kendi POI etiketleri gizlendi, sadece kendi pinlerimiz
    görünüyor.
12. Tasarım/kişiselleştirme (PM/UX zenginleştirme):
    - Ortak marka teması `AppTheme` (kırmızı/turuncu degrade); uygulama geneli
      `.tint` marka rengine bağlandı.
    - Açılış zoom'u ~2 km'ye çekildi (arama yine 20 km).
    - Özel `DonerGlyph`: SwiftUI ile sıfırdan çizilmiş döner logosu (şiş + et
      kütlesi). Pin, splash, liste kartı, detay kartı ve profilde kullanılıyor.
    - Pin gerçek harita işaretçisine dönüştürüldü (marka daire + beyaz halka +
      aşağı sivri uç).
    - `ListTabView` kart tabanlı canlı tasarıma geçirildi (döner rozeti,
      mesafe pill'i, chevron, "X yer" sayacı).
    - `SplashView` + `RootView`: açılışta animasyonlu marka splash ekranı,
      ~1.8 sn sonra ana içeriğe geçiş. Uygulama girişi `RootView`.

**Not:** Info.plist anahtarları eklendi ve doğrulandı:
- `NSLocationWhenInUseUsageDescription` (konum izni açıklaması) — build
  ayarlarında `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` olarak
  tanımlı (project.pbxproj).
- `LSApplicationQueriesSchemes` içinde `comgooglemaps` (Google Maps'in yüklü
  olup olmadığını kontrol edebilmek için) — `DonerKebabMap-Info.plist`
  dosyasında tanımlı.

## Araç geçmişi (önemli değil ama bilgi için)
Önce Cursor + ücretsiz plan denendi, Composer/Agent modu "cannot be billed
to an API key" hatası verdi (ücretsiz plan Composer'ın özel modellerini
kişisel API key ile çalıştırmıyor). Bunun üzerine Cursor'dan vazgeçilip
**Claude Code Pro** aboneliğine geçildi — agent kısıtlaması olmadan çalışıyor.

## Şu an nerede kaldık
MVP fonksiyonel olarak tamam + tasarım zenginleştirmesi yapıldı (özel döner
logosu, splash screen, kartlı liste, marka teması). Uygulama simülatörde
çalışıyor ve build başarılı.

Sıradaki olası adımlar (henüz seçilmedi):
- QA edge case kontrolleri: konum izni reddedilirse, internet yoksa, ~2 km
  açılış zoom'unda yakında hiç yer yoksa davranış.
- Pin seçili durumu (tıklanınca büyüme/renk), yoğun bölgede pin kümeleme
  (clustering), listede arama/filtre çubuğu.
- V1.1: favoriler (SwiftData ile kalıcı), Overpass API ile veri zenginleştirme.

## Proje dosya yapısı (güncel)
- `Models/DonerPlace.swift` — yer modeli + `formattedDistance`.
- `ViewModels/PlacesViewModel.swift` — paylaşılan arama state'i (tek sefer).
- `Services/LocationManager.swift`, `Services/PlacesSearchService.swift`.
- `Utilities/AppTheme.swift` (marka renkleri), `Utilities/DonerGlyph.swift`
  (özel döner logosu), `Utilities/DirectionsHelper.swift`.
- `Views/RootView.swift` (splash + geçiş), `ContentView.swift` (TabView),
  `MapTabView.swift`, `ListTabView.swift`, `PlaceDetailCard.swift`,
  `ProfileTabView.swift`.
