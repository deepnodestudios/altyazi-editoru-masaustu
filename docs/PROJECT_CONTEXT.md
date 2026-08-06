# Altyazı Çeviri Editörü - Masaüstü Sürüm Proje Bağlamı (Project Context)

Bu doküman, AI asistanların projeyi hızlıca anlayabilmesi, token israfının önlenmesi ve bağlamdan kopmadan geliştirmeye devam edebilmesi için oluşturulmuştur. Her yeni önemli mimari değişiklikte güncellenmelidir.

## 1. Mimari Genel Bakış ve Çoklu Repo Yapısı (Multi-Repo)
Proje üç farklı ana klasör/repo üzerinden yürütülmektedir. Geliştirme yaparken sistemin bütünsel olarak etkileneceğini unutmayın. Bu doküman **Masaüstü Sürümü** (`altyazi_editoru_Masaustu`) repo'sunu açıklamaktadır.
1. **Mobil (Ana) Master Sürüm:** `E:\Projeler\Altyazi_Editoru\altyazi_editoru` (Android/iOS)
2. **Masaüstü Sürüm (Bu Repo):** `E:\Projeler\Altyazi_Editoru\altyazi_editoru_Masaustu` (Windows/macOS/Linux)
3. **Web Sürüm:** `E:\Projeler\Altyazi_Editoru\deepnodestudios` (Web Frontend/Landing)

> **Kritik Kural 1 (Değişiklik Kısıtı):** Masaüstü (`E:\Projeler\Altyazi_Editoru\altyazi_editoru_Masaustu`) uygulaması üzerinde çalışırken, yönetici (kullanıcı) açıkça onaylamadıkça/istemedikçe **Mobil** (`E:\Projeler\Altyazi_Editoru\altyazi_editoru`) ve **Web** (`E:\Projeler\Altyazi_Editoru\deepnodestudios`) dosyaları **KESİNLİKLE DEĞİŞTİRİLMEYECEKTİR.** Odak noktası sadece masaüstü sürümüdür.

> **Kritik Kural 2 (Fonksiyon Senkronizasyonu):** Bu projenin `functions/src/` kaynak kodu, Mobil sürümün (`altyazi_editoru\functions\src`) kodunun **birebir kopyası olmalıdır.** Yönetici üç sürümü (mobil + masaüstü + web) **tek ortak backend** olarak kurgulamıştır; fonksiyonlar birebir eşit tutulmalıdır. Masaüstündeki `functions/` kodunda değişiklik yapıyorsan, değişikliği mobil ve web sürümlerine de **aynı anda ve aynen** yansıt. Aynı `default` codebase paylaşıldığı için eksik setle deploy edersen mobil fonksiyonları (örn. `handleSubscription`, `monthlyGoogleBonus`, reklam ödülleri) canlıdan silinir.

## 2. Masaüstü Sürümüne Özel İşlevler ve Mobilden Farkları
Masaüstü versiyonu, mobil uygulamanın masaüstüne uyarlanmış halidir ancak mobilden bazı belirgin farkları vardır:
- **OAuth Yoktur:** Mobil sürümde bulunan Cloud (Dropbox, Yandex Disk vb.) OAuth entegrasyonları masaüstü sürümünde **bulunmaz**. Dosya işlemleri yerel dosya sistemi (local file system) üzerinden yürütülür.
- **Masaüstü Seçim Davranışı (Desktop Selection):** Çoklu dosya seçimi, shift+click, ctrl+click, marquee (sürükle bırak kare içine alma) gibi gelişmiş masaüstü seçim mantığı içerir.
- **Windows Optimizasyonu:** `windows/runner/CMakeLists.txt` ile C++ derleme optimizasyonu yapılmıştır ve boyutları küçültmek için `flutter build windows` komutu özel Powershell script'leriyle (`build_windows_release.ps1`, `build_windows_installer.ps1`) desteklenmektedir.

## 3. Temel Firestore Koleksiyonları ve İş Kuralları
Masaüstü sürümü, Mobil uygulama ile aynı Firestore yapısına bağlanır.
- `users/{uid}`, `device_bonuses/{deviceId}`, `claimed_login_bonuses/{email}` gibi koleksiyonlar ortaktır.
- Başlangıç kredisi, giriş bonusu ve ödül mekanizmaları aynı Firebase backend'i üzerinden işlenir. 

## 4. Geliştirme ve Planlama Yönergeleri
- Geliştirmeler ve hata ayıklamalar masaüstü hedefinde (`windows` veya `macos`) test edilmelidir. 
- Kodlar üzerinde çalışırken bu dosya referans alınmalı, masaüstüne özgü yeni kurallar/davranışlar buraya eklenmelidir.

## 5. Devre Dışı Bırakılan Özellikler
- **Batch Translate (Toplu Çeviri):** Ana mobilde de olduğu gibi, eğer kod tabanında (Frontend/Backend) batch translate ile ilgili eski fonksiyonlar veya kod kalıntıları bulunuyorsa bu özellik arayüzde (UI) kesinlikle **bulunmamaktadır** ve aktif olarak **kullanılmamaktadır**.
