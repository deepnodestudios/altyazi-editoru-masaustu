# AGENTS.md - Altyazı Çeviri Editörü (Masaüstü)

Bu dosya, AI asistanların (opencode ve diğerleri) bu repo içinde çalışırken uyması gereken kritik kuralları özetler.

## Önemli Yollar
- Mobil (master repo): `E:\Projeler\Altyazi_Editoru\altyazi_editoru`
- Masaüstü (bu repo): `E:\Projeler\Altyazi_Editoru\altyazi_editoru_Masaustu`
- Web kopya: `E:\Projeler\Altyazi_Editoru\deepnodestudios`

## KRİTİK KURAL: Firebase Fonksiyon Senkronizasyonu
- Bu repo, mobilin **birebir kopyasıdır.** `functions/src/` altındaki backend kodu, mobil (`altyazi_editoru\functions\src`) ve web (`deepnodestudios\functions\index.js`) ile **birebir eşit** tutulmalıdır.
- `functions/src/` altında bir değişiklik yaptığında, değişikliği **aynı anda** mobil ve web sürümlerine de yansıt. Bu üç sürüm tek ortak bir backend olarak çalışır ve eksik set ile deploy yapılırsa canlıdaki fonksiyonlar silinir.
- Tek Firebase projesi: `altyazi-ceviri-editor`, tüm fonksiyonlar `us-central1`. Mobil+masaüstü codebase `default`, web codebase `deepnodestudios`.
- `global_translations` koleksiyonuna yazarken `costUsd` alanı da eklenmelidir.

## Not
- Frontend değişiklikleri yalnızca masaüstüne özgü olabilir; backend (functions) değişiklikleri ise her zaman üç kopyaya da yapılmalıdır.
- Detayları `docs/PROJECT_CONTEXT.md` içinde oku.