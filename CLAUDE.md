# Doner Kebab Map — Proje Context

## Bu proje
Yakındaki doner/kebab/gyro yerlerini haritada gösteren iOS uygulaması
(Swift + SwiftUI, MVVM). **v1.0 App Store'da yayında** (build 5, git tag `v1.0`).

Geliştirici QA engineer, yazılım bilgisi sınırlı: adım adım, basit ve net
açıkla. **Konuşma dili Türkçe.**

## Kurallar
- Uygulama içi metinlerde "döner" değil **"doner"** (Türkçe karakter yok).
  Sadece `PlacesSearchService` arama anahtar kelimeleri ö'lü kalabilir.
- Varsayılan dil İngilizce; Almanca (samimi "du") ve Fransızca ("vous") çevirileri
  `Localizable.xcstrings`'te. Yeni metin eklerken DE/FR çevirisini de ekle.
- Renkler `AppTheme`'de: dolgu/buton için `primary`, tonlu zemin üstündeki
  metin/ikon için `primaryAccent` (light/dark'ta okunaklı). Logo amber.
- Segmented `Picker` içine `ViewThatFits` vb. sarmalayıcı koyma — bozuluyor.
- Uygulama içi logo: büyük yerlerde (splash, profil) `DonerConeLogo`,
  küçük işaretlerde (pin, liste, kart) `DonerGlyph`.
- Commit/push sadece istenince.

## Mimari
- **Backend yok.** Veri: Apple MapKit `MKLocalSearch` (ücretsiz, key yok),
  20 km yarıçap, çoklu anahtar kelime + dedupe (aynı isim ancak <250 m ise aynı yer).
- Konum tek seferlik alınır; 15 sn'de gelmezse "Location Unavailable" ekranı.
- Favoriler `FavoriteStore` ile UserDefaults'ta (isim + <30 m koordinat eşleşmesi).
- Ana arayüz (`ContentView`) onboarding bitmeden mount edilmez — aksi halde
  cihazda dokunuşlar düşüyordu.
- MapKit **vermiyor**: puan, yorum, çalışma saati, fotoğraf. (`rating` şimdilik nil.)

## Dosya yapısı
- `Models/` — `DonerPlace`, `FavoritePlace`
- `ViewModels/PlacesViewModel` — paylaşılan arama state'i
- `Services/` — `LocationManager`, `PlacesSearchService`, `FavoriteStore`
- `Utilities/` — `AppTheme`, `DonerConeLogo`, `DonerGlyph`, `DistanceFormatter`,
  `DirectionsHelper`, `TransportMode`, `AppearanceMode`, `AdaptiveText`, `MailView`
- `Views/` — `RootView` (splash + onboarding), `MapTabView`, `ListTabView`,
  `PlaceDetailCard`, `ProfileTabView` ("More"), `OnboardingView`, `LoadingView`,
  hata/izin ekranları
- `docs/` — `privacy-policy.html`, `support.html`, `app-review-notes.txt`

## Yayın
- Sonraki yüklemede build numarası **6+**, sürüm 1.0.1 (düzeltme) / 1.1 (özellik).
- App Review Notes: `docs/app-review-notes.txt` (<4000 karakter). İçindeki
  "sonuçlar konuma bağlı, büyük bir şehirde test edin" paragrafı kalmalı.
- Çalıştırma: iOS simülatöründe önce sanal konum ayarla (ör. Berlin 52.52,13.405).

## Olası sonraki adımlar
Pin kümeleme, listede arama/filtre, rota çizgisi, Overpass / Google Places ile
puan ve çalışma saatleri.
