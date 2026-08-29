# Altyazı Çeviri Editörü - Proje Bağlamı (Project Context)

Bu doküman, AI asistanların projeyi hızlıca anlayabilmesi, token israfının önlenmesi ve bağlamdan kopmadan ("vibe coding") geliştirmeye devam edebilmesi için oluşturulmuştur. Her yeni önemli mimari değişiklikte güncellenmelidir.

## 1. Mimari Genel Bakış ve Çoklu Repo Yapısı (Multi-Repo)
Proje üç farklı ana klasör/repo üzerinden yürütülmektedir. Geliştirme yaparken sistemin bütünsel olarak etkileneceğini unutmayın.
1. **Mobil (Ana) Sürüm:** `E:\Projeler\Altyazi_Editoru\altyazi_editoru`
2. **Masaüstü Sürüm:** `E:\Projeler\Altyazi_Editoru\altyazi_editoru_Masaustu`
3. **Web Sürüm:** `E:\Projeler\Altyazi_Editoru\deepnodestudios`

> **Kritik Kural 1 (Etki Analizi):** Backend (Firebase Functions) veya çekirdek iş kurallarında (örn. kredi tüketimi, giriş mekanizmaları) yapılan değişiklikler, bu üç sürümün de aynı mantıkla çalışmasını gerektirebilir. Ortak fonksiyonlarda (shared functions) değişiklik yaparken diğer sürümlerin etkilenip etkilenmeyeceği her zaman hesaba katılmalıdır.

> **Kritik Kural 2 (Değişiklik Kısıtı):** Yönetici (kullanıcı) açıkça talep etmedikçe Masaüstü (`E:\Projeler\Altyazi_Editoru\altyazi_editoru_Masaustu`) ve Web (`E:\Projeler\Altyazi_Editoru\deepnodestudios`) sürümlerindeki dosyalar **kesinlikle değiştirilmeyecektir.** Tüm geliştirmeler varsayılan olarak Mobil (Ana) Sürüm üzerinden yürütülmelidir.

- **Frontend:** Flutter (Mobil, Desktop, Web uyumlu hibrit yapı). Mimari, `lib/` altında modüler olarak (controllers, managers, services vb.) kurgulanmıştır.
- **Backend:** Firebase (Cloud Functions, Firestore, Storage, Authentication). Backend kodları `functions/src/` altındadır (ai, billing, bonus, vb.).
- **Dil:** Frontend tarafı Dart, Backend tarafı TypeScript.

## 2. Temel Firestore Koleksiyonları
- `users/{uid}`: Kullanıcı profilleri, satın alınan krediler (`purchasedCredits`), google login bonusları ve **eski sürüm** (v1.6.8 ve öncesi) cihazlar için reklam ödülü/cihaz kredisi takibi.
- `device_bonuses/{deviceId}`: **Yeni sürüm** (v1.6.9 ve sonrası) cihazlar için kredi ve reklam ödülü takibi. UID sıfırlama açıklarını (abuse) önlemek adına cihaz bazlı takip için kullanılır. 
- `claimed_login_bonuses/{email}`: Kullanıcıların Google oturum açma bonuslarının cross-platform takibi.
- `referral_codes/{code}` ve `referral_claims/{claimId}`: Referans sistemi verileri.

## 3. Kredi ve Ödül Sistemi İş Kuralları (Billing & Rewards)
- **Başlangıç Kredisi (Starter Bonus):** Cihaz başı 5 (veya belirli platform/versiyonlara göre 2) kredi verilir.
- **Kısıtlı bölgeler (düşük eCPM):** Yalnızca **coğrafya** ile tespit edilir (IP kullanılmaz; **dil tek başına kısıtlamaz**).
  - **Tüm sürümler:** `IR`, `IN` (+ timezone yedekleri UTC+3:30 / UTC+5:30).
  - **>= 1.7.6:** `PK`, `BD`, `NP`, `LK`, `AF`, `MM`, `KH`, `LA`, `NG`, `ET`, `KE`, `GH`, `TZ`, `UG`, `CD`, `SD`, `IQ`, `YE`, `SY`.
  - **>= 1.7.7:** ek Afrika `CM`, `CI`, `SN`, `ML`, `BF`, `NE`, `TD`, `MG`, `MZ`, `ZM`, `ZW`, `AO`, `RW`, `BI`, `SO`, `LR`, `SL`, `GN`, `TG`, `BJ`, `MW`, `SS`. Ortak UTC dilimleri eklenmez. Diaspora (ör. ABD/Avrupa’da Hint/Farsça) kısıtlanmaz. Doğrulama: `users.freeRewardsGeoLocked` + `freeRewardsRestrictedReason` (ülke kodu); dil değil cihaz locale ülke kodu.
  - Starter kredi: **1**
  - Google giriş bonusu ve aylık Google bonusu: **yok** (aylık bonus ayrıca herkes için tamamen kapatıldı)
  - `users.freeRewardsGeoLocked`: coğrafi kısıt bir kez tetiklenince kalıcı (VPN ile kaçışı zorlaştırır)
  - Eski dil-tabanlı yanlış pozitifler: `giveStarterCredits` çağrısında coğrafi sinyal yoksa `freeRewardsRestricted` bayrağı temizlenir
  - Backend: `claimReferral`, `getAdRewardStatus`, `recordAdRewardWatch` → `FREE_REWARDS_RESTRICTED`
  - UI: referans ve reklam-izle-kazan gizlenir; “önce bonus kredileri kullan” toggle’ı açık kalır (satın alma bonusu için); sticky geo-lock istemcide cache’lenir
  - Çeviri öncesi ad gate (bedava kredi için) ve “bedava reklamlı / ücretli reklamsız” mesajı **kalır**
  - Mevcut bedava bakiyeler sıfırlanmaz; tüketilebilir
- **Google Giriş Bonusu:** İlk Google ile girişte 2 kredi verilir (kısıtlı bölgeler hariç).
- **Aylık Google Bonusu (`monthlyGoogleBonus`):** **Devre dışı** — artık kimseye kredi vermez (scheduler export’u deploy silmesin diye no-op olarak durur).
- **In-app review (ödülsüz):** Mağaza puanı için kredi yok. ≥2 tamamlanan çeviri → `pending` → sonraki **Start Translate**. Ücretli satın alma → yalnız `paid_eligible` (anında sorulmaz); **app açılışında** aralıklarla sorulabilir. En fazla **3** prompt, aralarında **≥45 gün**. Tur/bakım varken ertelenir.
- **Reklam Ödül Sistemi (`adRewardCredits`):** Kullanıcılar reklam izleyerek kredi/token kazanır (kısıtlı bölgelerde UI kapalı).
  - Eski sürümler (<= 1.6.8) reklam ödüllerini `users/{uid}` altında tutar.
  - Yeni sürümler (>= 1.6.9) reklam ödüllerini `device_bonuses/{deviceId}` altında tutar.
  - Kredi modu (canlı 1.7.x): 5 izleme = 1 kredi, günlük 5 izleme, haftalık 2 kredi.
  - Token cüzdanı (mobil 1.8.0+): her izleme = **5.000** grant token, günlük **10**, haftalık **40**. Haftalık tavan yalnız kazanma hızıdır; grant bakiye hafta sonunda sıfırlanmaz, **1 ay** sonra yanar.
  - Mobil 1.8.0+: bonus token süresini kredi kartı info ekranı anlatır; her kullanıcıya bir kez zorunlu diyalog çıkar (`hide_info_buttons` açık olsa bile). Prefs: `bonus_token_expiry_notice_seen_{uid}`.
  - `recordAdRewardWatch` fonksiyonu yeni bir cihaz için doküman oluşturduğunda, `deviceCredits: 0`, `totalBonusConsumed: 0` ve `adRewardOnlyInit: true` flag'i ile bilinçli olarak yazar. Böylece `giveStarterCredits` fonksiyonu bunun eski tip (legacy) bir doküman olduğunu sanıp yanlışlıkla başlangıç kredisi tanımlamaz; bunun yerine `adRewardOnlyInit` bayrağını okuyarak hakkı olan başlangıç kredisini temiz bir şekilde verir.

## 4. Geliştirme ve Planlama Yönergeleri
- Her büyük/kapsamlı iş (feature) planlanırken, alt görevlere (aşamalar/fazlar) bölünmelidir.
- Mevcut iş akışları (legacy) korunmalıdır; her güncelleme geriye dönük uyumlu olmalı ve eski sürümlerde çalışan kod kırılmamalıdır (`shouldUseV169DeviceAdRewardRules` gibi versiyon flag'leri ile korunmalıdır).
- Değişiklik sonrası `npm run build` ile TypeScript tarafı derlenmeli ve fonksiyonların çalıştığından emin olunmalıdır.
- Kodlar üzerinde çalışırken bu dosya referans alınmalı, geliştirme tamamlanınca yeni kurallar buraya eklenmelidir.

## 5. Devre Dışı Bırakılan Özellikler (Deprecated / Inactive Features)
- **Batch Translate (Toplu Çeviri):** Kod tabanında (Frontend/Backend) batch translate ile ilgili eski fonksiyonlar veya kod kalıntıları bulunabilir. Ancak bu özellik arayüzde (UI) kesinlikle **bulunmamaktadır** ve aktif olarak **kullanılmamaktadır**. Beta aşamasında bir süre kullanıldıktan sonra arayüzden tamamen kaldırılmıştır. Geliştirme süreçlerinde bu kodların pasif olduğu ve kullanılmadığı göz önünde bulundurulmalıdır. AI Asistanları bu özelliği canlandırmaya veya kodlarda bu fonksiyonları aramaya/kullanmaya çalışmamalıdır.

## 6. Firebase Fonksiyon Senkronizasyonu (KRİTİK KURAL)
Bu repo **master (ana) kaynaktır.** `functions/src/` altındaki tüm backend kodları, Masaüstü (`altyazi_editoru_Masaustu`) ve Web (`deepnodestudios`) sürümleriyle **birebir aynı** tutulur. Yönetici bu üç sürümü "tek ortak backend" olarak kurgulamıştır.

> **Kritik Kural 3 (Fonksiyon Eşitliği):** Mobil, Masaüstü ve Web sürümlerinin Firebase fonksiyon kaynak kodları **birebir eşit olmalıdır.** Herhangi birinde `functions/` altında yapılan bir değişiklik, diğer iki sürüme de **aynı anda ve aynen** kopyalanmalıdır. Aksi takdirde bir sürümden yapılan deploy, diğer sürümün fonksiyonlarını silebilir (aynı codebase paylaşıldığı için deploy sırasında eksik olan fonksiyonlar canlıdan kaldırılır).

- **Tek Firebase projesi:** `altyazi-ceviri-editor` — tüm fonksiyonlar `us-central1` bölgesindedir.
- **Codebase dağılımı:** Mobil ve Masaüstü `functions` → codebase `default`; Web `functions` → codebase `deepnodestudios`. Fonksiyon isimleri proje genelinde benzersiz olduğu için deploy'lar birbirini ezmez — yeter ki üç kaynak da birebir aynı seti içersin.
- **Fonksiyon seti (24 fonksiyon):** `addCredits`, `consumeCredit`, `giveStarterCredits`, `transferDeviceCreditsToGoogleAccount`, `checkTranslationAccess`, `translateText`, `startBatchTranslation`, `checkBatchTranslation`, `pollBatchJobs`, `getAdRewardStatus`, `recordAdRewardWatch`, `checkDailyAdLimit`, `recordAdUsage`, `generateReferralCode`, `claimReferral`, `handleSubscription`, `handleVoidedPurchase`, `monthlyGoogleBonus`, `notifyExpiringCredits` (mobil seti) + `lemonWebhook`, `claimLoginBonus`, `startServerTranslation`, `stopServerTranslation`, `processQueuedServerTranslation` (web seti). Web'in ekstra fonksiyonları da mobil kaynağa dahil edilmeli; masaüstü dahil üç sürüm de bu ortak seti içermelidir.
- **Deploy uyarısı:** Sadece mobil kaynağından veya sadece web kaynağından eksik setle deploy yapmak, canlıdaki diğer fonksiyonların silinmesine yol açar. Üç sürüm eşit tutulmadığı sürece deploy yapılmamalıdır.
- **`global_translations` koleksiyonuna cost yazımı:** Çeviri sonucu global önbelleğe yazılırken hem iç içe `cost` hem üst düzey `costUsd` yazılır. **1 Eylül 2026’dan itibaren** `costUsd` P&L defteri için Gemini **3.1 Flash-Lite liste** fiyatıdır ($0.25 giriş / $1.50 çıkış / 1M). Gerçek Google faturası `costUsdProvider` alanındadır (2.5 Flash-Lite: $0.10 / $0.40). Model string canlıda **gemini-2.5-flash-lite** kalır. Önbellek isabetinde her iki maliyet **0** yazılır; kredi/token yine tam iş gibi düşülür.
- **Bakım modu (Remote Config):** Firebase Remote Config üzerinden uygulama kullanımı geçici olarak kapatılabilir. Anahtarlar: `maintenance_mode_enabled` (tüm platformlar), `maintenance_mode_mobile`, `maintenance_mode_desktop`, `maintenance_mode_web` (platform bazlı). Varsayılan: `false`. Etkin olduğunda kullanıcıya yerelleştirilmiş bakım ekranı gösterilir; "Tekrar Dene" ile RC yeniden çekilir.
- **1 Eylül 2026 duyuru ekranı:** Yalnız **1.7.x** (token cüzdanından önceki sürüm). Her soğuk açılışta (tur ve bakım bittikten sonra) 1 Eylül değişikliklerini anlatır. **1.8.0+ bu ekranı göstermez.** Dil: uygulama UI dili (34 locale). `Tamam` yalnız o oturumu kapatır. 1 Eylül 00:00 Europe/Istanbul’dan sonra otomatik durur. Remote Config: `policy_change_notice_enabled` (varsayılan `true`).
- **1 Eylül sonrası “sistem değişti” ekranı (1.8.0+):** Token cüzdanı açıldıktan sonra ~30 gün (varsayılan bitiş: 1 Ekim 2026 00:00 Istanbul = `2026-09-30T21:00:00Z`). Remote Config: `credit_policy_notice_until` (ISO UTC). `Tamam` yalnız oturumu kapatır. 1.7.x bu ekranı görmez.
- **Çeviri öncesi token tahmini:** Token cüzdanındayken ve iş dosya kredisi harcamayacaksa, yerel `ceil(karakter * 1.30)` onay dialogu gösterilir. Mağaza paket kapsamı da aynı çarpanla hesaplanır (ortalama film ~50k / bölüm ~30k karakter; ör. 1M ≈ 15 film veya 25 bölüm; +%10 bonus kapsam dışı). “Önce bonus kullan” açık ve bonus yetmiyorsa kalan ücretli tokenden tamamlanır; kullanıcıya uyarı çıkar, bonus kullanıldığı için reklam da gösterilir. Yetersiz bakiyede mağaza açılır. Sunucuya yüklemeden önce iptal edilebilir. Tek iş ya 1 dosya kredisi ya da bu tahmini token tutarıdır; iş ortasında ek kesinti/iade yok. Tahmin, çeviri motoruyla aynı encoding’i kullanır; SDH açıksa yalnız kaynakta gerçekten SDH (`(...)` / `[...]` / konuşmacı etiketi) varsa temizlenmiş metinden hesaplanır. `translateText` ilk chunk’ta `charCount`/`estimatedTokens` gönderir. Token bakiyesi varken tahmin gelmezse 1 dosya kredisi kesilmez (`CHAR_COUNT_REQUIRED`). Token harcaması `credit_transactions` kaydında `unit=token` ve token tutarı ile yazılır; geçmişte “Token harcandı” görünür.
- **1 Eylül duyuru maili (Ağu 2026):** Google hesaplı kullanıcılara gönderildi (`deepnodestudios@gmail.com`). Dil: en sık çevirilen hedef dil (yoksa EN). Tekil: `users/{uid}.policyChangeEmailSentAt`. Şablonlar: `docs/emails/policy_change_2026/`. FCM henüz yok.
- **Token cüzdanı:** Canlı mobil 1.7.9 her zaman 1 kredi = 1 dosya kalır. **Mobil** token cüzdanı `1.8.0+` (tarih beklemez; mağaza ve kart 1.8.0’da tokena geçer). **Masaüstü** token cüzdanı `1.7.6+` ve 1 Eylül 2026 00:00 Istanbul. Token kartında ana bakiye **token**; ücretli kalan dosya kredisi varsa ayrıca Kredi chip’i. Eski `addCredits` token paketini krediye yazdıysa hydrate `83+1_000_000` kredi / `13+100_000` satın alma bonusunu ayırır (100k’yı 110.000 ile çarpmaz). Snapshot: `creditPolicy=token_v1`, `legacyFlatRateRemaining=purchasedCredits` (yalnız ücretli, 1 dosya = 1 kredi). Eskiden kalan bonus krediler (reklam/starter/login/satın alma bonusu) **1 kredi = 110.000 grant token** olarak çevrilir ve bonus kova sıfırlanır; yeni reklam/referans/starter doğrudan token basar. Tek işte kredi ile token karışmaz. Harcama: ücretli yolda ücretli dosya kredisi → ücretli token → bonus token. “Önce bonus kullan” açıksa bonus token (yetmezse kalan ücretli token) → ücretli kredi. Bonus+ücretli karışık işte reklam yine gösterilir. Masaüstü yalnız ücretli kova. Yeni satın alma `tokenBalance` artırır, legacy kova artmaz. Web aynı gün (`platform=web`) tarih kapısıyla açılır; Lemon eski variant 1 Eylül sonrası kredi×110.000 token (yeni 1/5/10M variant ID’leri eklenince onlar kullanılır). Masaüstü/web mağaza UI fiyatları token döneminde **$2.49 / $11.99 / $21.99** (1.1M / 5.5M / 11M); Play **$2.99 / $13.99 / $25.99**. Lemon checkout URL’leri yeni variant ID’leri girilene kadar eskisi kalır. **Aylık abonelik tokenleri devretmez:** yenilemede `subscriptionTokenPaidRemaining` + `subscriptionTokenGrantRemaining` sıfırlanır, yeni dönem (Hobby 2M+%10 / Cinema 3M+%10) yazılır; tek seferlik 1/5/10M paketler dokunulmaz. Geçmişte sıfırlama `subscription_renewal_forfeit` (token harcandı) + taban ekleme + **Satın Alma Bonusu** satırı görünür. İade hem ücretli hem bonus kovadan düşer; geçmiş `spend`/`voided_purchase`. Pack bonus rebalance yalnız tam eşleşen paket toplamında (greedy `>=` yok).
- **Play Console (token SKU, 1 Eylül öncesi oluşturulmalı):** Eski `credits_*` ürünleri 1.7.9 için durur; 1 Eylül’de kapatılmaz. Yeni tek seferlik ürünler (managed product / consumable): `tokens_1m` ($2.99 → 1.000.000+10%=1.100.000), `tokens_5m` ($13.99 → 5.500.000), `tokens_10m` ($25.99 → 11.000.000). Abonelik ID’leri aynı kalır: `sub_20_credits_monthly` (Hobby 2.0M+%10=2.2M), `sub_30_credits_monthly` (Cinema 3.0M+%10=3.3M). Abonelik Play fiyatı kredi dönemi tarifesinde kalsa da token miktarı Starter 1M paketinin üstündedir (yenileme + reklamsız). **1.8.0 mağazası token paketlerini gösterir**; 1.7.9 kredi paketlerinde kalır.
