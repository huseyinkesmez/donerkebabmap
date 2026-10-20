---
name: release
description: Doner Kebab Map'in yeni sürümünü App Store / TestFlight'a hazırlar — sürüm ve build numarasını artırır, çeviri / "doner" yazımı / Review Notes / Release derlemesi kontrollerini yapar, sonunda Türkçe yükleme ve App Review kontrol listesi verir. Kullanıcı "/release", "yeni sürüm", "TestFlight'a atalım", "markete gönderelim" dediğinde kullan.
argument-hint: "[patch|minor|major|X.Y.Z]"
---

# /release — yeni sürüm hazırlığı

Kullanıcıyla **Türkçe**, basit ve adım adım konuş. Bu skill yükleme yapmaz:
arşivleme ve App Store Connect işlemleri kullanıcının Apple hesabıyla, Xcode'da
yapılır. Kimlik bilgisi isteme, sözleşme kabul etme.

Yardımcı script: `.claude/skills/release/scripts/release.py` (repo kökünden çalıştır).

## 1. Sürüm türünü belirle
Argüman verildiyse onu kullan. Verilmediyse kullanıcıya sor:
- **patch** (1.0 → 1.0.1): sadece hata düzeltmesi
- **minor** (1.0 → 1.1): yeni özellik
- **major** (1.x → 2.0): büyük değişiklik

## 2. Ön kontrol (değişiklik yapmadan önce)
```bash
python3 .claude/skills/release/scripts/release.py check --skip-build
```
Kontrol ettikleri: Debug/Release sürümleri aynı mı, uygulama metinlerinde ö'lü
"döner" var mı, DE/FR çevirisi eksik metin var mı, Review Notes 4000 karakteri
aşıyor mu, commit edilmemiş değişiklik var mı.

**SORUN** çıkarsa önce onları düzelt:
- Ö'lü "döner" → "doner" yap, katalog anahtarını da aynı şekilde güncelle.
- Eksik çeviri → `Localizable.xcstrings`'e ekle. Almanca samimi "du",
  Fransızca nazik "vous". Özel adlar (Apple Maps, Doner Kebab Map) aynı kalır.
- Notes 4000'i aşıyorsa → `docs/app-review-notes.txt`'yi kısalt, ama
  "sonuçlar konuma bağlı, büyük bir şehirde test edin" paragrafını **silme**.

## 3. Sürümü artır
```bash
python3 .claude/skills/release/scripts/release.py bump <patch|minor|major|X.Y.Z>
```
Build numarasını her zaman +1 yapar. Kullanıcıya şunu sor: "App Store
Connect'e en son yüklediğin build numarası kaçtı?" Yeni build ondan büyük
değilse `CURRENT_PROJECT_VERSION`'ı elle yükselt (yükleme reddedilir).

## 4. Tam kontrol (Release derlemesi dahil)
```bash
python3 .claude/skills/release/scripts/release.py check
```
**SONUÇ: HAZIR** görmeden 5. adıma geçme.

## 5. Değişiklik özeti
Son etiketten bu yana neler değişti, kullanıcıya kısaca özetle:
```bash
git describe --tags --abbrev=0
git log <son-etiket>..HEAD --oneline
```
Bu özeti App Store "What's New" metni için İngilizce 2-4 madde olarak da öner.

## 6. Kullanıcıya kontrol listesini ver
Aşağıdakini sürüm/build numaralarını doldurarak ver:

**Arşivle ve yükle (Xcode)**
1. Cihaz seçici: **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App → TestFlight & App Store Connect → Upload**
4. Hata çıkarsa: "PLA Update" → developer.apple.com'da sözleşmeyi kabul et;
   "No iOS Distribution certificate" → Xcode Settings → Accounts →
   Manage Certificates → + Apple Distribution.

**App Store Connect**
- Yeni sürümü oluştur, yeni build'i seç
- "What's New" metnini yapıştır
- Review Notes: `docs/app-review-notes.txt` (düz metin, panoya kopyala:
  `pbcopy < docs/app-review-notes.txt`)
- Ekran görüntülerinde **harita görseli ilk sırada**
- Submit for Review

**Yapma**
- Aynı build numarasını tekrar yükleme
- İnceleme sürerken yeni özellik ekleme, bundle ID / uygulama adı değiştirme
- Review Notes'taki konum uyarısı paragrafını silme
- Apple ekran kaydı isterse simülatörde çekme; fiziksel cihazda, uygulama
  kapalıyken başlat ve konum izni pop-up'ı görünsün

## 7. Commit ve etiket (kullanıcı onaylarsa)
Kullanıcıya sor. Onaylarsa:
```bash
git add -A
git commit -m "Release <sürüm> (build <n>)"
git tag -a v<sürüm> -m "App Store release <sürüm> (build <n>)"
git push origin main && git push origin v<sürüm>
```
Commit mesajının sonuna geçerli Co-Authored-By satırını ekle.
