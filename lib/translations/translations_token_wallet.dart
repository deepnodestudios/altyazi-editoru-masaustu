// Token-wallet UI strings (estimate dialog, live notice, credit card).
const Map<String, Map<String, String>> translationsTokenWallet = {
  'EN': {
    'wallet_token_label': 'Tokens',
    'wallet_bonus_token_label': 'Bonus tokens',
    'credit_explanation_tokens_paid': 'Leftover paid credits still cover one full file each. Leftover bonus credits become tokens.',
    'credit_explanation_tokens_expiry': 'Bonus tokens are valid for 1 month. You can save them up and use them over that period; after 1 month, any remaining bonus tokens are removed from your account.',
    'bonus_token_expiry_title': 'Bonus tokens expire',
    'ad_reward_tile_title_tokens': 'Watch ads, earn tokens',
    'ad_reward_tile_desc_tokens': 'Each ad gives 5,000 tokens.',
    'ad_reward_limit_desc_tokens': 'You can watch up to 10 ads a day and 40 a week. Bonus tokens are valid for 1 month. You can save them up and use them over that period; after 1 month, any remaining bonus tokens are removed from your account.',
    'ad_reward_each_ad_hint': 'Each ad adds {tokens} tokens.',
    'token_mix_paid_title': 'Bonus tokens won\'t cover it all',
    'token_mix_paid_body': 'This file needs about {needed} tokens: {bonus} from bonus tokens, {paid} from paid tokens.',
    'token_mix_paid_confirm': 'Continue',
    'referral_cta_tokens': 'Refer and Earn Tokens',
    'referral_dialog_desc_tokens':
        'Share your code with a friend. When they join and redeem it, both of you receive 150,000 tokens.',
    'referral_claim_success_tokens':
        'Referral bonus added. 150,000 tokens were granted.',
    'referral_share_message_tokens':
        'Join AI SRT Subtitle Translator & Editor with my referral code: {code}. When you redeem it, both of us receive 150,000 tokens.',
    'tutorial_referral_desc_tokens':
        'This button opens the referral center. Invite friends, and both of you can earn 150,000 tokens. Google sign-in is required.',
    'credit_source_referral': 'Referral reward',
    'ad_reward_token_cta': 'Watch Ad\nEarn Tokens',
    'prefer_free_tokens_first': 'Use bonus tokens first',
    'subscription_monthly_note_tokens': 'Renews monthly. Unused tokens do not carry over.',
    'ad_gate_desc_tokens': 'Bonus tokens show a rewarded ad before processing. If bonus tokens are not enough, the rest comes from paid tokens and the ad still plays. Paid file credits, paid-only token jobs, and active subscriptions start immediately without ads.',
    'file_rights_unit': 'FILE',
    'start_cost_one_file_right': 'file',
    'same_language_desc_tokens': 'The language of the selected files appears to match the target translation language. Do you still want to proceed and use your balance?',
    'feature_credit_title_tokens': 'Token System & History',
    'feature_credit_desc_tokens': 'Track token and leftover file-credit usage in detail. See when tokens were added or spent, and for which file.',
    'credit_history_error_tokens': 'Could not load token history.',
    'billing_no_token': 'Not enough tokens',
    'billing_no_token_desc': 'You do not have enough balance to start this translation.',
    'batch_no_token_log': 'Not enough tokens. You have no balance to start.',
    'wallet_paid_token_label': 'Paid tokens',
    'history_menu_tokens': 'Translation/Token History',
    'credit_history_title_tokens': 'Token History',
    'credit_history_add_tokens': 'Token added',
    'credit_history_spend_tokens': 'Token spent',
    'credit_history_subscription_forfeit_tokens': 'Unused subscription tokens reset',
    'add_tokens': 'Add Tokens',
    'credit_explanation_tokens':
        'Tokens scale with file length. Leftover paid credits still cover one full file each.',
    'token_estimate_title': 'Estimated token use',
    'token_estimate_body':
        'This file will use about {tokens} tokens. Remaining after: {remaining}.',
    'token_estimate_cancel': 'Cancel',
    'token_estimate_confirm': 'Start',
    'token_insufficient_title': 'Not enough tokens',
    'token_insufficient_body':
        'This file needs {needed} tokens. You have {balance}.',
    'token_insufficient_shop': 'Add tokens',
    'credit_policy_live_title': 'Billing now uses tokens',
    'credit_policy_live_intro':
        'From 1 September 2026, new translations are charged in tokens. Longer files cost more; shorter files cost less. You see an estimate before each translation starts.',
    'credit_policy_live_rule_1':
        'Paid file credits you already have still work as 1 file = 1 credit until they run out.',
    'credit_policy_live_rule_2':
        'New top-ups are 1 / 5 / 10 million token packs. Remaining paid credits and your token balance are shown together.',
    'credit_policy_live_rule_3':
        'One job uses either leftover file credits or tokens — never both mixed.',
    'credit_policy_live_ads':
        'Rewarded ads continue: 5 ads = 75,000 tokens. Daily and weekly limits stay the same.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'About {movies} movies or {episodes} episodes',

  },
  'TR': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Bonus Token',
    'credit_explanation_tokens_paid': 'Kalan ücretli krediler bitene kadar 1 dosya = 1 kredi olarak durur. Eski bonus krediler tokene çevrilir.',
    'credit_explanation_tokens_expiry': 'Kazanılan bonus tokenler 1 ay geçerlidir, biriktirilerek kullanılabilir; 1 ay sonunda hesabınızdan silinir.',
    'bonus_token_expiry_title': 'Bonus tokenların süresi dolar',
    'ad_reward_tile_title_tokens': 'Reklam izle, token kazan',
    'ad_reward_tile_desc_tokens': 'Her reklam 5.000 token kazandırır.',
    'ad_reward_limit_desc_tokens': 'Günde en fazla 10, haftada en fazla 40 reklam izleyebilirsiniz. Kazanılan bonus tokenler 1 ay geçerlidir, biriktirilerek kullanılabilir; 1 ay sonunda hesabınızdan silinir.',
    'ad_reward_each_ad_hint': 'Her reklam {tokens} token ekler.',
    'token_mix_paid_title': 'Bonus token yetmiyor',
    'token_mix_paid_body': 'Bu dosya yaklaşık {needed} token gerektirir. {bonus} bonus tokenden, {paid} ücretli tokenden düşülecek.',
    'token_mix_paid_confirm': 'Devam et',
    'referral_cta_tokens': 'Referans Ol\nToken Kazan',
    'referral_dialog_desc_tokens':
        'Kodunu bir arkadaşınla paylaş. Uygulamaya katılıp kodu kullandığında ikinize de 150.000 token verilir.',
    'referral_claim_success_tokens':
        'Referans bonusu eklendi. 150.000 token tanımlandı.',
    'referral_share_message_tokens':
        'AI SRT Altyazı Çeviri & Editör uygulamasına benim referans kodumla katıl: {code}. Kodu kullandığında ikimize de 150.000 token verilir.',
    'tutorial_referral_desc_tokens':
        'Bu buton referans merkezini açar. Arkadaşlarını davet ederek ikinize de 150.000 token kazandırabilirsin. Google girişi zorunludur.',
    'credit_source_referral': 'Referans ödülü',
    'ad_reward_token_cta': 'Reklam İzle\nToken Kazan',
    'prefer_free_tokens_first': 'Önce bonus tokenları kullan',
    'subscription_monthly_note_tokens': 'Aylık yenilenir. Kullanılmayan tokenlar devretmez.',
    'ad_gate_desc_tokens': 'Bonus tokenlar işlenmeden önce ödüllü reklam gösterilir. Bonus yetmezse kalan ücretli tokenden tamamlanır; reklam yine gösterilir. Ücretli krediler, yalnız ücretli token ve aktif abonelikler reklamsız hemen başlar.',
    'file_rights_unit': 'HAK',
    'start_cost_one_file_right': 'hak',
    'same_language_desc_tokens': 'Seçtiğiniz dosyaların dili, çevirmek istediğiniz hedef dil ile aynı gibi görünüyor. Yine de çeviri işlemine başlayıp bakiyenizi kullanmak istiyor musunuz?',
    'feature_credit_title_tokens': 'Token Sistemi ve Geçmişi',
    'feature_credit_desc_tokens': 'Token ve kalan dosya kredisi kullanımını ayrıntılı izleyin. Tokenların ne zaman eklendiğini veya harcandığını ve hangi dosya için olduğunu görün.',
    'credit_history_error_tokens': 'Token geçmişi yüklenemedi.',
    'billing_no_token': 'Yetersiz token',
    'billing_no_token_desc': 'Bu işlemi başlatmak için bakiyeniz bulunmuyor.',
    'batch_no_token_log': 'Yetersiz token. İşlemi başlatabilmek için bakiyeniz bulunmuyor.',
    'wallet_paid_token_label': 'Ücretli Token',
    'history_menu_tokens': 'Çeviri/Token Geçmişi',
    'credit_history_title_tokens': 'Token Geçmişi',
    'credit_history_add_tokens': 'Token eklendi',
    'credit_history_spend_tokens': 'Token harcandı',
    'credit_history_subscription_forfeit_tokens': 'Kullanılmayan abonelik tokenları sıfırlandı',
    'add_tokens': 'Token Ekle',
    'credit_explanation_tokens':
        'Token kullanımı dosya uzunluğuna göre değişir. Kalan ücretli krediler bitene kadar 1 dosya = 1 kredi olarak durur.',
    'token_estimate_title': 'Tahmini token kullanımı',
    'token_estimate_body':
        'Bu dosya yaklaşık {tokens} token harcar. Sonra kalan: {remaining}.',
    'token_estimate_cancel': 'İptal',
    'token_estimate_confirm': 'Başlat',
    'token_insufficient_title': 'Yetersiz token',
    'token_insufficient_body':
        'Bu dosya {needed} token ister. Elinizde {balance} var.',
    'token_insufficient_shop': 'Token ekle',
    'credit_policy_live_title': 'Ücretlendirme artık token ile',
    'credit_policy_live_intro':
        '1 Eylül 2026 itibarıyla yeni çeviriler token ile ücretlendirilir. Uzun dosya daha fazla, kısa dosya daha az harcar. Çeviri başlamadan tahmini görürsünüz.',
    'credit_policy_live_rule_1':
        'Hesabınızdaki ücretli dosya kredileri bitene kadar 1 dosya = 1 kredi olarak çalışmaya devam eder.',
    'credit_policy_live_rule_2':
        'Yeni yüklemeler 1 / 5 / 10 milyon token paketleridir. Kalan ücretli hak ve token bakiyesi birlikte görünür.',
    'credit_policy_live_rule_3':
        'Bir iş ya kalan dosya kredisi ya da token harcar; ikisi karışmaz.',
    'credit_policy_live_ads':
        'Reklam izleme duruyor: 5 reklam = 75.000 token. Günlük ve haftalık limitler aynı.',
    'credit_policy_live_ok': 'Tamam',
    'token_pack_coverage':
        'Yaklaşık {movies} film veya {episodes} dizi bölümü',

  },
  'FR': {
    'wallet_token_label': 'Jetons',
    'wallet_bonus_token_label': 'Jetons bonus',
    'credit_explanation_tokens_paid': 'Les crédits payés restants couvrent encore un fichier entier chacun. Les crédits bonus restants deviennent des jetons.',
    'credit_explanation_tokens_expiry': 'Les jetons bonus sont valables un mois. Vous pouvez les cumuler et les utiliser pendant cette période ; passé un mois, ceux qui restent sont retirés de votre compte.',
    'bonus_token_expiry_title': 'Les jetons bonus expirent',
    'ad_reward_tile_title_tokens': 'Regarder une pub, gagner des jetons',
    'ad_reward_tile_desc_tokens': 'Chaque publicité rapporte 5 000 jetons.',
    'ad_reward_limit_desc_tokens': 'Jusqu’à 10 pubs par jour et 40 par semaine. Les jetons bonus sont valables un mois. Vous pouvez les cumuler et les utiliser pendant cette période ; passé un mois, ceux qui restent sont retirés de votre compte.',
    'ad_reward_each_ad_hint': 'Chaque pub ajoute {tokens} jetons.',
    'token_mix_paid_title': 'Jetons bonus insuffisants',
    'token_mix_paid_body': 'Ce fichier nécessite environ {needed} jetons : {bonus} sur vos jetons bonus, {paid} sur vos jetons payés.',
    'token_mix_paid_confirm': 'Continuer',
    'referral_cta_tokens': 'Parrainer et\nGagner des jetons',
    'referral_dialog_desc_tokens':
        'Partagez votre code avec un ami. Quand il rejoint l\'application et saisit le code, vous recevez tous les deux 150 000 jetons.',
    'referral_claim_success_tokens': 'Bonus de parrainage ajouté. 150 000 jetons ont été crédités.',
    'referral_share_message_tokens':
        'Rejoignez AI SRT Subtitle Translator & Editor avec mon code de parrainage : {code}. Quand vous le saisissez, nous recevons tous les deux 150 000 jetons.',
    'tutorial_referral_desc_tokens':
        'Ce bouton ouvre le centre de parrainage. Invitez des amis : chacun gagne 150 000 jetons. Une connexion Google est nécessaire.',
    'credit_source_referral': 'Récompense de parrainage',
    'ad_reward_token_cta': 'Regarder une pub\nGagner des jetons',
    'prefer_free_tokens_first': 'Utiliser d\'abord les jetons bonus',
    'subscription_monthly_note_tokens': 'Renouvellement mensuel. Les jetons non utilisés ne sont pas reportés.',
    'ad_gate_desc_tokens': 'Les jetons bonus affichent une publicité récompensée avant le traitement. Si les jetons bonus ne suffisent pas, le reste est prélevé sur vos jetons payés et la publicité s\'affiche quand même. Les crédits fichier payants, les travaux en jetons payants uniquement et les abonnements actifs démarrent immédiatement sans publicité.',
    'file_rights_unit': 'FICHIER',
    'start_cost_one_file_right': 'fichier',
    'wallet_paid_token_label': 'Jetons payés',
    'history_menu_tokens': 'Historique traduction/jetons',
    'credit_history_title_tokens': 'Historique des jetons',
    'credit_history_add_tokens': 'Jetons ajoutés',
    'credit_history_spend_tokens': 'Jetons dépensés',
    'credit_history_subscription_forfeit_tokens': 'Jetons d\'abonnement non utilisés réinitialisés',
    'add_tokens': 'Ajouter des jetons',
    'credit_explanation_tokens':
        'Les jetons dépendent de la longueur du fichier. Les crédits payés restants couvrent encore un fichier entier chacun.',
    'token_estimate_title': 'Estimation des jetons',
    'token_estimate_body':
        'Ce fichier utilisera environ {tokens} jetons. Il restera : {remaining}.',
    'token_estimate_cancel': 'Annuler',
    'token_estimate_confirm': 'Démarrer',
    'token_insufficient_title': 'Pas assez de jetons',
    'token_insufficient_body':
        'Ce fichier nécessite {needed} jetons. Vous en avez {balance}.',
    'token_insufficient_shop': 'Ajouter des jetons',
    'credit_policy_live_title': 'La facturation utilise désormais des jetons',
    'credit_policy_live_intro':
        'Depuis le 1er septembre 2026, les nouvelles traductions sont facturées en jetons. Un fichier long coûte plus, un court coûte moins. Une estimation s’affiche avant le départ.',
    'credit_policy_live_rule_1':
        'Les crédits de fichier déjà achetés restent valables : 1 fichier = 1 crédit jusqu’à épuisement.',
    'credit_policy_live_rule_2':
        'Les nouveaux packs sont de 1 / 5 / 10 millions de jetons. Crédits restants et solde de jetons s’affichent ensemble.',
    'credit_policy_live_rule_3':
        'Un travail utilise soit des crédits fichier restants, soit des jetons — jamais les deux mélangés.',
    'credit_policy_live_ads':
        'Les pubs récompensées continuent : 5 pubs = 75 000 jetons. Les plafonds quotidien et hebdomadaire restent identiques.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Environ {movies} films ou {episodes} épisodes',

  },
  'DE': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Bonus-Token',
    'credit_explanation_tokens_paid': 'Übrige bezahlte Credits gelten weiter als 1 Datei = 1 Credit. Übrige Bonus-Credits werden zu Token.',
    'credit_explanation_tokens_expiry': 'Bonus-Token sind einen Monat gültig. Sie können sie sammeln und in diesem Zeitraum nutzen; nach einem Monat werden ungenutzte Bonus-Token von Ihrem Konto entfernt.',
    'bonus_token_expiry_title': 'Bonus-Token verfallen',
    'ad_reward_tile_title_tokens': 'Werbung ansehen, Token verdienen',
    'ad_reward_tile_desc_tokens': 'Jede Anzeige bringt 5.000 Token.',
    'ad_reward_limit_desc_tokens': 'Höchstens 10 Anzeigen am Tag und 40 in der Woche. Bonus-Token sind einen Monat gültig. Sie können sie sammeln und in diesem Zeitraum nutzen; nach einem Monat werden ungenutzte Bonus-Token von Ihrem Konto entfernt.',
    'ad_reward_each_ad_hint': 'Jede Anzeige fügt {tokens} Token hinzu.',
    'token_mix_paid_title': 'Bonus-Token reichen nicht aus',
    'token_mix_paid_body': 'Diese Datei benötigt etwa {needed} Token: {bonus} aus Bonus-Token, {paid} aus bezahlten Token.',
    'token_mix_paid_confirm': 'Weiter',
    'referral_cta_tokens': 'Empfehlen und\nToken verdienen',
    'referral_dialog_desc_tokens':
        'Teilen Sie Ihren Code mit einem Freund. Wenn er die App nutzt und den Code einlöst, erhalten Sie beide 150.000 Token.',
    'referral_claim_success_tokens': 'Empfehlungsbonus gutgeschrieben. 150.000 Token wurden Ihrem Konto hinzugefügt.',
    'referral_share_message_tokens':
        'Komm zu AI SRT Subtitle Translator & Editor mit meinem Empfehlungscode: {code}. Wenn du ihn einlöst, erhalten wir beide 150.000 Token.',
    'tutorial_referral_desc_tokens':
        'Diese Schaltfläche öffnet das Empfehlungszentrum. Laden Sie Freunde ein — Sie beide erhalten 150.000 Token. Google-Anmeldung ist erforderlich.',
    'credit_source_referral': 'Empfehlungsprämie',
    'ad_reward_token_cta': 'Werbung ansehen\nToken verdienen',
    'prefer_free_tokens_first': 'Bonus-Token zuerst nutzen',
    'subscription_monthly_note_tokens': 'Monatliche Verlängerung. Ungenutzte Token werden nicht übertragen.',
    'ad_gate_desc_tokens': 'Bonus-Token zeigen vor der Verarbeitung eine Belohnungsanzeige. Reichen Bonus-Token nicht aus, wird der Rest aus bezahlten Token genommen; die Anzeige wird trotzdem gezeigt. Bezahlte Datei-Credits, rein bezahlte Token-Jobs und aktive Abos starten sofort ohne Werbung.',
    'file_rights_unit': 'DATEI',
    'start_cost_one_file_right': 'Datei',
    'wallet_paid_token_label': 'Bezahlte Token',
    'history_menu_tokens': 'Übersetzungs-/Token-Verlauf',
    'credit_history_title_tokens': 'Token-Verlauf',
    'credit_history_add_tokens': 'Token hinzugefügt',
    'credit_history_spend_tokens': 'Token ausgegeben',
    'credit_history_subscription_forfeit_tokens': 'Ungenutzte Abo-Token zurückgesetzt',
    'add_tokens': 'Token hinzufügen',
    'credit_explanation_tokens':
        'Token richten sich nach der Dateilänge. Übrige bezahlte Credits gelten weiter als 1 Datei = 1 Credit.',
    'token_estimate_title': 'Geschätzter Tokenverbrauch',
    'token_estimate_body':
        'Diese Datei verbraucht etwa {tokens} Token. Danach bleiben: {remaining}.',
    'token_estimate_cancel': 'Abbrechen',
    'token_estimate_confirm': 'Starten',
    'token_insufficient_title': 'Nicht genug Token',
    'token_insufficient_body':
        'Diese Datei braucht {needed} Token. Sie haben {balance}.',
    'token_insufficient_shop': 'Token hinzufügen',
    'credit_policy_live_title': 'Abrechnung erfolgt jetzt in Token',
    'credit_policy_live_intro':
        'Seit dem 1. September 2026 werden neue Übersetzungen in Token berechnet. Längere Dateien kosten mehr, kürzere weniger. Vor dem Start sehen Sie eine Schätzung.',
    'credit_policy_live_rule_1':
        'Bereits gekaufte Datei-Credits gelten weiter: 1 Datei = 1 Credit, bis sie aufgebraucht sind.',
    'credit_policy_live_rule_2':
        'Neue Aufladungen sind 1- / 5- / 10-Millionen-Token-Pakete. Restcredits und Tokenstand erscheinen zusammen.',
    'credit_policy_live_rule_3':
        'Ein Auftrag nutzt entweder Rest-Datei-Credits oder Token — nie beides gemischt.',
    'credit_policy_live_ads':
        'Belohnte Werbung bleibt: 5 Ads = 75.000 Token. Tages- und Wochenlimits bleiben gleich.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Etwa {movies} Filme oder {episodes} Folgen',

  },
  'IT': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Token bonus',
    'credit_explanation_tokens_paid': 'I crediti a pagamento rimasti coprono ancora 1 file = 1 credito. I crediti bonus rimasti diventano token.',
    'credit_explanation_tokens_expiry': 'I token bonus sono validi per 1 mese. Puoi accumularli e usarli in questo periodo; dopo 1 mese, quelli rimasti vengono rimossi dal tuo account.',
    'bonus_token_expiry_title': 'I token bonus scadono',
    'ad_reward_tile_title_tokens': 'Guarda un annuncio, guadagna token',
    'ad_reward_tile_desc_tokens': 'Ogni annuncio dà 5.000 token.',
    'ad_reward_limit_desc_tokens': 'Fino a 10 annunci al giorno e 40 a settimana. I token bonus sono validi per 1 mese. Puoi accumularli e usarli in questo periodo; dopo 1 mese, quelli rimasti vengono rimossi dal tuo account.',
    'ad_reward_each_ad_hint': 'Ogni annuncio aggiunge {tokens} token.',
    'token_mix_paid_title': 'I token bonus non bastano',
    'token_mix_paid_body': 'Questo file richiede circa {needed} token: {bonus} dai token bonus, {paid} dai token a pagamento.',
    'token_mix_paid_confirm': 'Continua',
    'referral_cta_tokens': 'Invita e\nGuadagna token',
    'referral_dialog_desc_tokens':
        'Condividi il tuo codice con un amico. Quando entra nell\'app e lo usa, ricevete entrambi 150.000 token.',
    'referral_claim_success_tokens': 'Bonus invito aggiunto. Sono stati accreditati 150.000 token.',
    'referral_share_message_tokens':
        'Entra in AI SRT Subtitle Translator & Editor con il mio codice invito: {code}. Quando lo usi, riceviamo entrambi 150.000 token.',
    'tutorial_referral_desc_tokens':
        'Questo pulsante apre il centro inviti. Invita gli amici: entrambi ricevete 150.000 token. Serve l\'accesso con Google.',
    'credit_source_referral': 'Premio invito',
    'ad_reward_token_cta': 'Guarda annuncio\nGuadagna token',
    'prefer_free_tokens_first': 'Usa prima i token bonus',
    'subscription_monthly_note_tokens': 'Si rinnova mensilmente. I token non usati non vengono riportati.',
    'ad_gate_desc_tokens': 'I token bonus mostrano un annuncio premio prima dell\'elaborazione. Se non bastano, il resto viene preso dai token a pagamento e l\'annuncio viene comunque mostrato. Crediti file pagati, lavori solo a pagamento e abbonamenti attivi partono subito senza pubblicità.',
    'file_rights_unit': 'FILE',
    'start_cost_one_file_right': 'file',
    'wallet_paid_token_label': 'Token a pagamento',
    'history_menu_tokens': 'Cronologia traduzioni/token',
    'credit_history_title_tokens': 'Cronologia token',
    'credit_history_add_tokens': 'Token aggiunti',
    'credit_history_spend_tokens': 'Token spesi',
    'credit_history_subscription_forfeit_tokens': 'Token dell\'abbonamento non usati azzerati',
    'add_tokens': 'Aggiungi token',
    'credit_explanation_tokens':
        'I token dipendono dalla lunghezza del file. I crediti a pagamento rimasti coprono ancora 1 file = 1 credito.',
    'token_estimate_title': 'Stima dei token',
    'token_estimate_body':
        'Questo file userà circa {tokens} token. Rimanenti dopo: {remaining}.',
    'token_estimate_cancel': 'Annulla',
    'token_estimate_confirm': 'Avvia',
    'token_insufficient_title': 'Token insufficienti',
    'token_insufficient_body':
        'Questo file richiede {needed} token. Ne hai {balance}.',
    'token_insufficient_shop': 'Aggiungi token',
    'credit_policy_live_title': 'La fatturazione ora usa i token',
    'credit_policy_live_intro':
        'Dal 1º settembre 2026 le nuove traduzioni si pagano in token. I file lunghi costano di più, quelli corti di meno. Vedi una stima prima di iniziare.',
    'credit_policy_live_rule_1':
        'I crediti file già acquistati restano validi: 1 file = 1 credito fino a esaurimento.',
    'credit_policy_live_rule_2':
        'I nuovi pacchetti sono da 1 / 5 / 10 milioni di token. Crediti rimasti e saldo token si vedono insieme.',
    'credit_policy_live_rule_3':
        'Un lavoro usa crediti file residui oppure token — mai entrambi insieme.',
    'credit_policy_live_ads':
        'Le ads premiate continuano: 5 ads = 75.000 token. I limiti giornalieri e settimanali restano uguali.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Circa {movies} film o {episodes} episodi',

  },
  'ES': {
    'wallet_token_label': 'Tokens',
    'wallet_bonus_token_label': 'Tokens bonus',
    'credit_explanation_tokens_paid': 'Los créditos de pago restantes siguen cubriendo 1 archivo = 1 crédito. Los créditos bonus restantes se convierten en tokens.',
    'credit_explanation_tokens_expiry': 'Los tokens bonus son válidos durante 1 mes. Puedes acumularlos y usarlos en ese plazo; al cumplirse el mes, los que queden se eliminan de tu cuenta.',
    'bonus_token_expiry_title': 'Los tokens bonus caducan',
    'ad_reward_tile_title_tokens': 'Ver anuncio, ganar tokens',
    'ad_reward_tile_desc_tokens': 'Cada anuncio da 5.000 tokens.',
    'ad_reward_limit_desc_tokens': 'Hasta 10 anuncios al día y 40 a la semana. Los tokens bonus son válidos durante 1 mes. Puedes acumularlos y usarlos en ese plazo; al cumplirse el mes, los que queden se eliminan de tu cuenta.',
    'ad_reward_each_ad_hint': 'Cada anuncio suma {tokens} tokens.',
    'token_mix_paid_title': 'Los tokens bonus no alcanzan',
    'token_mix_paid_body': 'Este archivo necesita unos {needed} tokens: {bonus} de tokens bonus y {paid} de tokens de pago.',
    'token_mix_paid_confirm': 'Continuar',
    'referral_cta_tokens': 'Referir y\nGanar tokens',
    'referral_dialog_desc_tokens':
        'Comparte tu código con un amigo. Cuando entre en la app y lo canjee, ambos recibiréis 150.000 tokens.',
    'referral_claim_success_tokens': 'Bonus de invitación añadido. Se han abonado 150.000 tokens.',
    'referral_share_message_tokens':
        'Únete a AI SRT Subtitle Translator & Editor con mi código de invitación: {code}. Al canjearlo, ambos recibimos 150.000 tokens.',
    'tutorial_referral_desc_tokens':
        'Este botón abre el centro de invitaciones. Invita a amigos y ambos recibís 150.000 tokens. Hace falta iniciar sesión con Google.',
    'credit_source_referral': 'Recompensa por invitación',
    'ad_reward_token_cta': 'Ver anuncio\nGanar tokens',
    'prefer_free_tokens_first': 'Usar primero tokens bonus',
    'subscription_monthly_note_tokens': 'Se renueva mensualmente. Los tokens no usados no se acumulan.',
    'ad_gate_desc_tokens': 'Los tokens bonus muestran un anuncio recompensado antes del procesamiento. Si no alcanzan, el resto sale de tokens de pago y el anuncio se muestra igual. Créditos de archivo pagados, trabajos solo con tokens de pago y suscripciones activas empiezan al instante sin anuncios.',
    'file_rights_unit': 'ARCHIVO',
    'start_cost_one_file_right': 'archivo',
    'wallet_paid_token_label': 'Tokens de pago',
    'history_menu_tokens': 'Historial traducción/token',
    'credit_history_title_tokens': 'Historial de tokens',
    'credit_history_add_tokens': 'Tokens añadidos',
    'credit_history_spend_tokens': 'Tokens gastados',
    'credit_history_subscription_forfeit_tokens': 'Tokens de suscripción no usados reiniciados',
    'add_tokens': 'Añadir tokens',
    'credit_explanation_tokens':
        'Los tokens dependen de la longitud del archivo. Los créditos de pago restantes siguen cubriendo 1 archivo = 1 crédito.',
    'token_estimate_title': 'Uso estimado de tokens',
    'token_estimate_body':
        'Este archivo usará unos {tokens} tokens. Quedarán: {remaining}.',
    'token_estimate_cancel': 'Cancelar',
    'token_estimate_confirm': 'Iniciar',
    'token_insufficient_title': 'No hay tokens suficientes',
    'token_insufficient_body':
        'Este archivo necesita {needed} tokens. Tienes {balance}.',
    'token_insufficient_shop': 'Añadir tokens',
    'credit_policy_live_title': 'La facturación ahora usa tokens',
    'credit_policy_live_intro':
        'Desde el 1 de septiembre de 2026 las traducciones nuevas se cobran en tokens. Los archivos largos cuestan más; los cortos, menos. Verás una estimación antes de empezar.',
    'credit_policy_live_rule_1':
        'Los créditos de archivo ya comprados siguen valiendo: 1 archivo = 1 crédito hasta agotarse.',
    'credit_policy_live_rule_2':
        'Las recargas nuevas son paquetes de 1 / 5 / 10 millones de tokens. Créditos restantes y saldo de tokens se muestran juntos.',
    'credit_policy_live_rule_3':
        'Un trabajo usa créditos de archivo restantes o tokens, nunca ambos mezclados.',
    'credit_policy_live_ads':
        'Los anuncios recompensados siguen: 5 anuncios = 75.000 tokens. Los límites diarios y semanales no cambian.',
    'credit_policy_live_ok': 'Aceptar',
    'token_pack_coverage':
        'Aprox. {movies} películas o {episodes} episodios',

  },
  'PT': {
    'wallet_token_label': 'Tokens',
    'wallet_bonus_token_label': 'Tokens bónus',
    'credit_explanation_tokens_paid': 'Os créditos pagos restantes ainda cobrem 1 ficheiro = 1 crédito. Os créditos bónus restantes convertem-se em tokens.',
    'credit_explanation_tokens_expiry': 'Os tokens bónus são válidos durante 1 mês. Pode acumulá-los e utilizá-los nesse período; ao fim de 1 mês, os que restarem são removidos da sua conta.',
    'bonus_token_expiry_title': 'Os tokens bónus caducam',
    'ad_reward_tile_title_tokens': 'Ver anúncio, ganhar tokens',
    'ad_reward_tile_desc_tokens': 'Cada anúncio dá 5.000 tokens.',
    'ad_reward_limit_desc_tokens': 'Até 10 anúncios por dia e 40 por semana. Os tokens bónus são válidos durante 1 mês. Pode acumulá-los e utilizá-los nesse período; ao fim de 1 mês, os que restarem são removidos da sua conta.',
    'ad_reward_each_ad_hint': 'Cada anúncio acrescenta {tokens} tokens.',
    'token_mix_paid_title': 'Tokens bónus insuficientes',
    'token_mix_paid_body': 'Este ficheiro precisa de cerca de {needed} tokens: {bonus} dos tokens bónus, {paid} dos tokens pagos.',
    'token_mix_paid_confirm': 'Continuar',
    'referral_cta_tokens': 'Indicar e\nGanhar tokens',
    'referral_dialog_desc_tokens':
        'Partilhe o seu código com um amigo. Quando ele entrar na app e usar o código, os dois recebem 150.000 tokens.',
    'referral_claim_success_tokens': 'Bónus de indicação adicionado. Foram creditados 150.000 tokens.',
    'referral_share_message_tokens':
        'Entre no AI SRT Subtitle Translator & Editor com o meu código de indicação: {code}. Ao usá-lo, os dois recebemos 150.000 tokens.',
    'tutorial_referral_desc_tokens':
        'Este botão abre o centro de indicações. Convide amigos e os dois recebem 150.000 tokens. É preciso entrar com o Google.',
    'credit_source_referral': 'Recompensa de indicação',
    'ad_reward_token_cta': 'Ver anúncio\nGanhar tokens',
    'prefer_free_tokens_first': 'Usar primeiro tokens bónus',
    'subscription_monthly_note_tokens': 'Renova mensalmente. Tokens não usados não acumulam.',
    'ad_gate_desc_tokens': 'Os tokens bónus mostram um anúncio recompensado antes do processamento. Se não chegarem, o restante vem dos tokens pagos e o anúncio continua a ser exibido. Créditos de ficheiro pagos, trabalhos só com tokens pagos e subscrições ativas começam de imediato sem anúncios.',
    'file_rights_unit': 'FICHEIRO',
    'start_cost_one_file_right': 'ficheiro',
    'wallet_paid_token_label': 'Tokens pagos',
    'history_menu_tokens': 'Histórico tradução/token',
    'credit_history_title_tokens': 'Histórico de tokens',
    'credit_history_add_tokens': 'Tokens adicionados',
    'credit_history_spend_tokens': 'Tokens gastos',
    'credit_history_subscription_forfeit_tokens': 'Tokens da assinatura não usados foram reiniciados',
    'add_tokens': 'Adicionar tokens',
    'credit_explanation_tokens':
        'Os tokens variam com o tamanho do ficheiro. Os créditos pagos restantes ainda cobrem 1 ficheiro = 1 crédito.',
    'token_estimate_title': 'Uso estimado de tokens',
    'token_estimate_body':
        'Este ficheiro usará cerca de {tokens} tokens. Restantes depois: {remaining}.',
    'token_estimate_cancel': 'Cancelar',
    'token_estimate_confirm': 'Iniciar',
    'token_insufficient_title': 'Tokens insuficientes',
    'token_insufficient_body':
        'Este ficheiro precisa de {needed} tokens. Tem {balance}.',
    'token_insufficient_shop': 'Adicionar tokens',
    'credit_policy_live_title': 'A faturação agora usa tokens',
    'credit_policy_live_intro':
        'Desde 1 de setembro de 2026 as novas traduções são cobradas em tokens. Ficheiros longos custam mais; curtos, menos. Vê uma estimativa antes de começar.',
    'credit_policy_live_rule_1':
        'Os créditos de ficheiro já pagos continuam a valer: 1 ficheiro = 1 crédito até acabarem.',
    'credit_policy_live_rule_2':
        'As novas recargas são pacotes de 1 / 5 / 10 milhões de tokens. Créditos restantes e saldo de tokens aparecem juntos.',
    'credit_policy_live_rule_3':
        'Um trabalho usa créditos de ficheiro restantes ou tokens — nunca os dois misturados.',
    'credit_policy_live_ads':
        'Os anúncios recompensados continuam: 5 anúncios = 75.000 tokens. Os limites diários e semanais mantêm-se.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Cerca de {movies} filmes ou {episodes} episódios',

  },
  'RU': {
    'wallet_token_label': 'Токены',
    'wallet_bonus_token_label': 'Бонусные токены',
    'credit_explanation_tokens_paid': 'Оставшиеся платные кредиты по-прежнему: 1 файл = 1 кредит. Оставшиеся бонусные кредиты превращаются в токены.',
    'credit_explanation_tokens_expiry': 'Бонусные токены действуют 1 месяц. Их можно копить и тратить в течение этого срока; по истечении месяца неиспользованные бонусные токены удаляются с вашего аккаунта.',
    'bonus_token_expiry_title': 'Бонусные токены сгорают',
    'ad_reward_tile_title_tokens': 'Смотрите рекламу — получайте токены',
    'ad_reward_tile_desc_tokens': 'Каждый ролик даёт 5 000 токенов.',
    'ad_reward_limit_desc_tokens': 'Не больше 10 роликов в день и 40 в неделю. Бонусные токены действуют 1 месяц. Их можно копить и тратить в течение этого срока; по истечении месяца неиспользованные бонусные токены удаляются с вашего аккаунта.',
    'ad_reward_each_ad_hint': 'Каждый ролик добавляет {tokens} токенов.',
    'token_mix_paid_title': 'Бонусных токенов не хватает',
    'token_mix_paid_body': 'Этому файлу нужно около {needed} токенов: {bonus} с бонусных, {paid} с платных.',
    'token_mix_paid_confirm': 'Продолжить',
    'referral_cta_tokens': 'Пригласить и\nзаработать токены',
    'referral_dialog_desc_tokens':
        'Поделитесь кодом с другом. Когда он войдёт в приложение и введёт код, вы оба получите по 150 000 токенов.',
    'referral_claim_success_tokens': 'Реферальный бонус начислен: 150 000 токенов.',
    'referral_share_message_tokens':
        'Присоединяйтесь к AI SRT Subtitle Translator & Editor по моему коду: {code}. Когда вы его введёте, мы оба получим по 150 000 токенов.',
    'tutorial_referral_desc_tokens':
        'Эта кнопка открывает центр приглашений. Пригласите друзей — вы оба получите по 150 000 токенов. Нужен вход через Google.',
    'credit_source_referral': 'Реферальная награда',
    'ad_reward_token_cta': 'Смотреть рекламу\nЗаработать токены',
    'prefer_free_tokens_first': 'Сначала использовать бонусные токены',
    'subscription_monthly_note_tokens': 'Продлевается ежемесячно. Неиспользованные токены не переносятся.',
    'ad_gate_desc_tokens': 'Бонусные токены показывают рекламу с вознаграждением перед обработкой. Если их не хватает, остаток списывается с платных токенов, реклама всё равно показывается. Платные файловые кредиты, задачи только на платных токенах и активные подписки начинаются сразу без рекламы.',
    'file_rights_unit': 'ФАЙЛ',
    'start_cost_one_file_right': 'файл',
    'wallet_paid_token_label': 'Платные токены',
    'history_menu_tokens': 'История переводов/токенов',
    'credit_history_title_tokens': 'История токенов',
    'credit_history_add_tokens': 'Токены добавлены',
    'credit_history_spend_tokens': 'Токены списаны',
    'credit_history_subscription_forfeit_tokens': 'Неиспользованные токены подписки сброшены',
    'add_tokens': 'Добавить токены',
    'credit_explanation_tokens':
        'Расход токенов зависит от длины файла. Оставшиеся платные кредиты по-прежнему: 1 файл = 1 кредит.',
    'token_estimate_title': 'Оценка расхода токенов',
    'token_estimate_body':
        'Этот файл потратит около {tokens} токенов. Останется: {remaining}.',
    'token_estimate_cancel': 'Отмена',
    'token_estimate_confirm': 'Начать',
    'token_insufficient_title': 'Недостаточно токенов',
    'token_insufficient_body':
        'Этому файлу нужно {needed} токенов. У вас {balance}.',
    'token_insufficient_shop': 'Добавить токены',
    'credit_policy_live_title': 'Оплата теперь в токенах',
    'credit_policy_live_intro':
        'С 1 сентября 2026 новые переводы оплачиваются токенами. Длинные файлы стоят больше, короткие — меньше. Перед стартом вы видите оценку.',
    'credit_policy_live_rule_1':
        'Уже купленные файловые кредиты действуют как 1 файл = 1 кредит, пока не закончатся.',
    'credit_policy_live_rule_2':
        'Новые пакеты — 1 / 5 / 10 миллионов токенов. Остаток кредитов и баланс токенов показываются вместе.',
    'credit_policy_live_rule_3':
        'Одна задача тратит либо оставшиеся файловые кредиты, либо токены — не оба сразу.',
    'credit_policy_live_ads':
        'Реклама за награду: 5 роликов = 75 000 токенов. Дневной и недельный лимиты те же.',
    'credit_policy_live_ok': 'ОК',
    'token_pack_coverage':
        'Около {movies} фильмов или {episodes} серий',

  },
  'EL': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Token μπόνους',
    'credit_explanation_tokens_paid': 'Οι υπόλοιπες πληρωμένες πιστώσεις καλύπτουν ακόμα 1 αρχείο = 1 πίστωση. Οι υπόλοιπες πιστώσεις μπόνους μετατρέπονται σε token.',
    'credit_explanation_tokens_expiry': 'Τα token μπόνους ισχύουν για 1 μήνα. Μπορείτε να τα συσσωρεύετε και να τα χρησιμοποιείτε σε αυτό το διάστημα· μετά από 1 μήνα, όσα απομένουν διαγράφονται από τον λογαριασμό σας.',
    'bonus_token_expiry_title': 'Τα token μπόνους λήγουν',
    'ad_reward_tile_title_tokens': 'Δείτε διαφήμιση, κερδίστε token',
    'ad_reward_tile_desc_tokens': 'Κάθε διαφήμιση δίνει 5.000 token.',
    'ad_reward_limit_desc_tokens': 'Έως 10 διαφημίσεις τη μέρα και 40 την εβδομάδα. Τα token μπόνους ισχύουν για 1 μήνα. Μπορείτε να τα συσσωρεύετε και να τα χρησιμοποιείτε σε αυτό το διάστημα· μετά από 1 μήνα, όσα απομένουν διαγράφονται από τον λογαριασμό σας.',
    'ad_reward_each_ad_hint': 'Κάθε διαφήμιση προσθέτει {tokens} token.',
    'token_mix_paid_title': 'Τα token μπόνους δεν επαρκούν',
    'token_mix_paid_body': 'Αυτό το αρχείο χρειάζεται περίπου {needed} token: {bonus} από token μπόνους, {paid} από πληρωμένα token.',
    'token_mix_paid_confirm': 'Συνέχεια',
    'referral_cta_tokens': 'Πρόσκληση και\nκέρδος token',
    'referral_dialog_desc_tokens':
        'Μοιραστείτε τον κωδικό σας με έναν φίλο. Όταν μπει στην εφαρμογή και τον χρησιμοποιήσει, παίρνετε και οι δύο 150.000 token.',
    'referral_claim_success_tokens': 'Προστέθηκε το μπόνους πρόσκλησης. Πιστώθηκαν 150.000 token.',
    'referral_share_message_tokens':
        'Μπείτε στο AI SRT Subtitle Translator & Editor με τον κωδικό μου: {code}. Όταν τον χρησιμοποιήσετε, παίρνουμε και οι δύο 150.000 token.',
    'tutorial_referral_desc_tokens':
        'Αυτό το κουμπί ανοίγει το κέντρο προσκλήσεων. Προσκαλέστε φίλους και κερδίζετε και οι δύο 150.000 token. Απαιτείται είσοδος με Google.',
    'credit_source_referral': 'Αμοιβή πρόσκλησης',
    'ad_reward_token_cta': 'Παρακολούθηση διαφήμισης\nΚέρδος token',
    'prefer_free_tokens_first': 'Χρήση πρώτα των token μπόνους',
    'subscription_monthly_note_tokens': 'Ανανεώνεται μηνιαία. Τα αχρησιμοποίητα token δεν μεταφέρονται.',
    'ad_gate_desc_tokens': 'Τα token μπόνους εμφανίζουν διαφήμιση ανταμοιβής πριν την επεξεργασία. Αν δεν επαρκούν, το υπόλοιπο αφαιρείται από πληρωμένα token και η διαφήμιση εμφανίζεται κανονικά. Πληρωμένες πιστώσεις αρχείου, εργασίες μόνο με πληρωμένα token και ενεργές συνδρομές ξεκινούν αμέσως χωρίς διαφημίσεις.',
    'file_rights_unit': 'ΑΡΧΕΙΟ',
    'start_cost_one_file_right': 'αρχείο',
    'wallet_paid_token_label': 'Πληρωμένα token',
    'history_menu_tokens': 'Ιστορικό μετάφρασης/token',
    'credit_history_title_tokens': 'Ιστορικό token',
    'credit_history_add_tokens': 'Προστέθηκαν token',
    'credit_history_spend_tokens': 'Δαπανήθηκαν token',
    'credit_history_subscription_forfeit_tokens': 'Τα αχρησιμοποίητα token συνδρομής μηδενίστηκαν',
    'add_tokens': 'Προσθήκη token',
    'credit_explanation_tokens':
        'Τα token εξαρτώνται από το μήκος του αρχείου. Τα υπόλοιπα επί πληρωμή credits καλύπτουν ακόμα 1 αρχείο = 1 credit.',
    'token_estimate_title': 'Εκτιμώμενη χρήση token',
    'token_estimate_body':
        'Αυτό το αρχείο θα χρησιμοποιήσει περίπου {tokens} token. Υπόλοιπο μετά: {remaining}.',
    'token_estimate_cancel': 'Ακύρωση',
    'token_estimate_confirm': 'Έναρξη',
    'token_insufficient_title': 'Δεν επαρκούν τα token',
    'token_insufficient_body':
        'Αυτό το αρχείο χρειάζεται {needed} token. Έχετε {balance}.',
    'token_insufficient_shop': 'Προσθήκη token',
    'credit_policy_live_title': 'Η χρέωση γίνεται πλέον με token',
    'credit_policy_live_intro':
        'Από την 1η Σεπτεμβρίου 2026 οι νέες μεταφράσεις χρεώνονται σε token. Τα μεγάλα αρχεία κοστίζουν περισσότερο, τα μικρά λιγότερο. Βλέπετε εκτίμηση πριν την έναρξη.',
    'credit_policy_live_rule_1':
        'Τα επί πληρωμή credits αρχείων που έχετε ισχύουν ως 1 αρχείο = 1 credit μέχρι να τελειώσουν.',
    'credit_policy_live_rule_2':
        'Τα νέα πακέτα είναι 1 / 5 / 10 εκατομμύρια token. Υπόλοιπα credits και υπόλοιπο token εμφανίζονται μαζί.',
    'credit_policy_live_rule_3':
        'Μια εργασία χρησιμοποιεί είτε υπόλοιπα credits αρχείου είτε token — ποτέ και τα δύο μαζί.',
    'credit_policy_live_ads':
        'Οι ανταποδοτικές διαφημίσεις συνεχίζονται: 5 διαφημίσεις = 75.000 token. Τα ημερήσια και εβδομαδιαία όρια μένουν ίδια.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Περίπου {movies} ταινίες ή {episodes} επεισόδια',

  },
  'AR': {
    'wallet_token_label': 'الرموز',
    'wallet_bonus_token_label': 'الرموز المجانية',
    'credit_explanation_tokens_paid': 'الأرصدة المدفوعة المتبقية ما زالت تغطي ملفاً كاملاً لكل رصيد. تتحول أرصدة المكافأة المتبقية إلى رموز.',
    'credit_explanation_tokens_expiry': 'رموز المكافأة صالحة لمدة شهر واحد. يمكنك تجميعها واستخدامها خلال هذه المدة؛ وبعد مرور شهر تُحذف ما تبقى من رصيدك.',
    'bonus_token_expiry_title': 'رموز المكافأة تنتهي',
    'ad_reward_tile_title_tokens': 'شاهد إعلانًا واكسب رموزًا',
    'ad_reward_tile_desc_tokens': 'كل إعلان يمنحك 5,000 رمز.',
    'ad_reward_limit_desc_tokens': 'حتى 10 إعلانات في اليوم و40 في الأسبوع. رموز المكافأة صالحة لمدة شهر واحد. يمكنك تجميعها واستخدامها خلال هذه المدة؛ وبعد مرور شهر تُحذف ما تبقى من رصيدك.',
    'ad_reward_each_ad_hint': 'كل إعلان يضيف {tokens} رمزًا.',
    'token_mix_paid_title': 'رموز المكافأة لا تكفي',
    'token_mix_paid_body': 'يحتاج هذا الملف إلى نحو {needed} رمز: {bonus} من رموز المكافأة و{paid} من الرموز المدفوعة.',
    'token_mix_paid_confirm': 'متابعة',
    'referral_cta_tokens': 'أحِل و\nاكسب رموزاً',
    'referral_dialog_desc_tokens': 'شارك رمزك مع صديق. عندما يدخل التطبيق ويستخدم الرمز، يحصل كل منكما على 150,000 رمز.',
    'referral_claim_success_tokens': 'أُضيفت مكافأة الدعوة. تم منح 150,000 رمز.',
    'referral_share_message_tokens':
        'انضم إلى AI SRT Subtitle Translator & Editor برمز الدعوة الخاص بي: {code}. عند استخدامه نحصل نحن الاثنين على 150,000 رمز.',
    'tutorial_referral_desc_tokens':
        'هذا الزر يفتح مركز الدعوات. ادعُ أصدقاءك ليحصل كل منكما على 150,000 رمز. يلزم تسجيل الدخول عبر Google.',
    'credit_source_referral': 'مكافأة الدعوة',
    'ad_reward_token_cta': 'شاهد إعلاناً\nاكسب رموزاً',
    'prefer_free_tokens_first': 'استخدم رموز المكافأة أولاً',
    'subscription_monthly_note_tokens': 'يتجدد شهرياً. الرموز غير المستخدمة لا تُرحَّل.',
    'ad_gate_desc_tokens': 'تعرض رموز المكافأة إعلاناً بمكافأة قبل المعالجة. إذا لم تكفِ، يُكمل الباقي من الرموز المدفوعة ويُعرض الإعلان أيضاً. أرصدة الملفات المدفوعة والمهام بالرموز المدفوعة فقط والاشتراكات النشطة تبدأ فوراً بدون إعلانات.',
    'file_rights_unit': 'ملف',
    'start_cost_one_file_right': 'ملف',
    'wallet_paid_token_label': 'الرموز المدفوعة',
    'history_menu_tokens': 'سجل الترجمة/الرموز',
    'credit_history_title_tokens': 'سجل الرموز',
    'credit_history_add_tokens': 'تمت إضافة الرموز',
    'credit_history_spend_tokens': 'تم إنفاق الرموز',
    'credit_history_subscription_forfeit_tokens': 'أُعيد ضبط رموز الاشتراك غير المستخدمة',
    'add_tokens': 'إضافة رموز',
    'credit_explanation_tokens':
        'استهلاك الرموز يتناسب مع طول الملف. الأرصدة المدفوعة المتبقية ما زالت تغطي ملفاً كاملاً لكل رصيد.',
    'token_estimate_title': 'تقدير استهلاك الرموز',
    'token_estimate_body':
        'سيستخدم هذا الملف نحو {tokens} رمزاً. المتبقي بعدها: {remaining}.',
    'token_estimate_cancel': 'إلغاء',
    'token_estimate_confirm': 'بدء',
    'token_insufficient_title': 'رموز غير كافية',
    'token_insufficient_body':
        'يحتاج هذا الملف إلى {needed} رمزاً. لديك {balance}.',
    'token_insufficient_shop': 'إضافة رموز',
    'credit_policy_live_title': 'الفوترة أصبحت بالرموز',
    'credit_policy_live_intro':
        'اعتباراً من 1 سبتمبر 2026 تُحسب الترجمات الجديدة بالرموز. الملفات الأطول تكلف أكثر والقصيرة أقل. تظهر تقديراً قبل البدء.',
    'credit_policy_live_rule_1':
        'أرصدة الملفات المدفوعة التي لديك ما زالت تعمل: ملف واحد = رصيد واحد حتى تنفد.',
    'credit_policy_live_rule_2':
        'عمليات الشحن الجديدة حزم 1 / 5 / 10 ملايين رمز. الأرصدة المتبقية ورصيد الرموز يظهران معاً.',
    'credit_policy_live_rule_3':
        'المهمة الواحدة تستخدم إما أرصدة ملفات متبقية أو رموزاً — دون خلطهما.',
    'credit_policy_live_ads':
        'إعلانات المكافأة مستمرة: 5 إعلانات = 75,000 رمزاً. الحدود اليومية والأسبوعية كما هي.',
    'credit_policy_live_ok': 'حسنًا',
    'token_pack_coverage':
        'حوالي {movies} فيلم أو {episodes} حلقة',

  },
  'IN': {
    'wallet_token_label': 'टोकन',
    'wallet_bonus_token_label': 'बोनस टोकन',
    'credit_explanation_tokens_paid': 'बचे भुगतान क्रेडिट अभी भी 1 फ़ाइल = 1 क्रेडिट हैं। बचे बोनस क्रेडिट टोकन में बदल जाते हैं।',
    'credit_explanation_tokens_expiry': 'बोनस टोकन 1 महीने तक मान्य रहते हैं। इस दौरान इन्हें जमा करके इस्तेमाल किया जा सकता है; 1 महीने बाद बचे हुए बोनस टोकन आपके खाते से हटा दिए जाते हैं।',
    'bonus_token_expiry_title': 'बोनस टोकन खत्म हो जाते हैं',
    'ad_reward_tile_title_tokens': 'विज्ञापन देखें, टोकन कमाएँ',
    'ad_reward_tile_desc_tokens': 'हर विज्ञापन 5,000 टोकन देता है।',
    'ad_reward_limit_desc_tokens': 'दिन में अधिकतम 10 और हफ़्ते में 40 विज्ञापन। बोनस टोकन 1 महीने तक मान्य रहते हैं। इस दौरान इन्हें जमा करके इस्तेमाल किया जा सकता है; 1 महीने बाद बचे हुए बोनस टोकन आपके खाते से हटा दिए जाते हैं।',
    'ad_reward_each_ad_hint': 'हर विज्ञापन {tokens} टोकन जोड़ता है।',
    'token_mix_paid_title': 'बोनस टोकन काफ़ी नहीं हैं',
    'token_mix_paid_body': 'इस फ़ाइल को लगभग {needed} टोकन चाहिए: {bonus} बोनस से, {paid} भुगतान से।',
    'token_mix_paid_confirm': 'जारी रखें',
    'referral_cta_tokens': 'रेफर करें और\nटोकन कमाएँ',
    'referral_dialog_desc_tokens':
        'अपना कोड किसी मित्र के साथ साझा करें। जब वे ऐप में जुड़कर कोड इस्तेमाल करेंगे, आप दोनों को 150,000 टोकन मिलेंगे।',
    'referral_claim_success_tokens': 'रेफ़रल बोनस जुड़ गया। 150,000 टोकन खाते में जमा हुए।',
    'referral_share_message_tokens':
        'मेरे रेफ़रल कोड से AI SRT Subtitle Translator & Editor में शामिल हों: {code}। कोड इस्तेमाल करने पर हम दोनों को 150,000 टोकन मिलेंगे।',
    'tutorial_referral_desc_tokens':
        'यह बटन रेफ़रल केंद्र खोलता है। दोस्तों को बुलाएँ, आप दोनों 150,000 टोकन पा सकते हैं। Google से साइन-इन ज़रूरी है।',
    'credit_source_referral': 'रेफ़रल इनाम',
    'ad_reward_token_cta': 'विज्ञापन देखें\nटोकन कमाएँ',
    'prefer_free_tokens_first': 'पहले बोनस टोकन उपयोग करें',
    'subscription_monthly_note_tokens': 'मासिक नवीनीकरण। अप्रयुक्त टोकन आगे नहीं बढ़ते।',
    'ad_gate_desc_tokens': 'बोनस टोकन प्रसंस्करण से पहले इनाम वाला विज्ञापन दिखाते हैं। यदि पर्याप्त न हों, तो शेष भुगतान टोकन से काटा जाता है और विज्ञापन फिर भी चलता है। भुगतान फ़ाइल क्रेडिट, केवल भुगतान टोकन वाले कार्य और सक्रिय सदस्यता तुरंत बिना विज्ञापन शुरू होते हैं।',
    'file_rights_unit': 'फ़ाइल',
    'start_cost_one_file_right': 'फ़ाइल',
    'wallet_paid_token_label': 'भुगतान टोकन',
    'history_menu_tokens': 'अनुवाद/टोकन इतिहास',
    'credit_history_title_tokens': 'टोकन इतिहास',
    'credit_history_add_tokens': 'टोकन जोड़े गए',
    'credit_history_spend_tokens': 'टोकन खर्च किए गए',
    'credit_history_subscription_forfeit_tokens': 'बचे हुए सब्सक्रिप्शन टोकन रीसेट हुए',
    'add_tokens': 'टोकन जोड़ें',
    'credit_explanation_tokens':
        'टोकन फ़ाइल की लंबाई के अनुसार खर्च होते हैं। बचे भुगतान क्रेडिट अभी भी 1 फ़ाइल = 1 क्रेडिट हैं।',
    'token_estimate_title': 'अनुमानित टोकन उपयोग',
    'token_estimate_body':
        'यह फ़ाइल लगभग {tokens} टोकन खर्च करेगी। बाद में शेष: {remaining}.',
    'token_estimate_cancel': 'रद्द करें',
    'token_estimate_confirm': 'शुरू करें',
    'token_insufficient_title': 'पर्याप्त टोकन नहीं',
    'token_insufficient_body':
        'इस फ़ाइल को {needed} टोकन चाहिए। आपके पास {balance} हैं।',
    'token_insufficient_shop': 'टोकन जोड़ें',
    'credit_policy_live_title': 'बिलिंग अब टोकन से है',
    'credit_policy_live_intro':
        '1 सितंबर 2026 से नई अनुवाद टोकन से शुल्क लगते हैं। लंबी फ़ाइल अधिक, छोटी कम खर्च करती है। शुरू करने से पहले अनुमान दिखता है।',
    'credit_policy_live_rule_1':
        'आपके मौजूदा भुगतान फ़ाइल क्रेडिट खत्म होने तक 1 फ़ाइल = 1 क्रेडिट रहते हैं।',
    'credit_policy_live_rule_2':
        'नए पैक 1 / 5 / 10 मिलियन टोकन के हैं। बचे क्रेडिट और टोकन बैलेंस साथ दिखते हैं।',
    'credit_policy_live_rule_3':
        'एक काम या बचे फ़ाइल क्रेडिट या टोकन खर्च करता है — दोनों मिलाकर नहीं।',
    'credit_policy_live_ads':
        'रिवॉर्ड विज्ञापन जारी: 5 विज्ञापन = 75,000 टोकन। दैनिक और साप्ताहिक सीमा वही।',
    'credit_policy_live_ok': 'ठीक है',
    'token_pack_coverage':
        'लगभग {movies} फिल्में या {episodes} एपिसोड',

  },
  'ID': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Token bonus',
    'credit_explanation_tokens_paid': 'Sisa kredit berbayar tetap 1 file = 1 kredit. Sisa kredit bonus diubah menjadi token.',
    'credit_explanation_tokens_expiry': 'Token bonus berlaku selama 1 bulan. Anda bisa mengumpulkannya dan memakainya selama masa itu; setelah 1 bulan, sisa token bonus dihapus dari akun Anda.',
    'bonus_token_expiry_title': 'Token bonus kedaluwarsa',
    'ad_reward_tile_title_tokens': 'Tonton iklan, dapatkan token',
    'ad_reward_tile_desc_tokens': 'Setiap iklan memberi 5.000 token.',
    'ad_reward_limit_desc_tokens': 'Maksimal 10 iklan per hari dan 40 per minggu. Token bonus berlaku selama 1 bulan. Anda bisa mengumpulkannya dan memakainya selama masa itu; setelah 1 bulan, sisa token bonus dihapus dari akun Anda.',
    'ad_reward_each_ad_hint': 'Setiap iklan menambah {tokens} token.',
    'token_mix_paid_title': 'Token bonus tidak cukup',
    'token_mix_paid_body': 'File ini membutuhkan sekitar {needed} token: {bonus} dari token bonus, {paid} dari token berbayar.',
    'token_mix_paid_confirm': 'Lanjutkan',
    'referral_cta_tokens': 'Referensikan dan\nDapatkan token',
    'referral_dialog_desc_tokens':
        'Bagikan kode Anda ke teman. Saat mereka masuk ke aplikasi dan memakai kodenya, kalian berdua mendapat 150.000 token.',
    'referral_claim_success_tokens': 'Bonus undangan ditambahkan. 150.000 token sudah masuk ke akun.',
    'referral_share_message_tokens':
        'Gabung AI SRT Subtitle Translator & Editor dengan kode undangan saya: {code}. Saat dipakai, kita berdua mendapat 150.000 token.',
    'tutorial_referral_desc_tokens':
        'Tombol ini membuka pusat undangan. Undang teman, kalian berdua bisa mendapat 150.000 token. Perlu masuk dengan Google.',
    'credit_source_referral': 'Hadiah undangan',
    'ad_reward_token_cta': 'Tonton iklan\nDapatkan token',
    'prefer_free_tokens_first': 'Gunakan token bonus terlebih dahulu',
    'subscription_monthly_note_tokens': 'Diperpanjang bulanan. Token yang tidak terpakai tidak dibawa.',
    'ad_gate_desc_tokens': 'Token bonus menampilkan iklan berhadiah sebelum diproses. Jika tidak cukup, sisanya diambil dari token berbayar dan iklan tetap ditampilkan. Kredit file berbayar, pekerjaan token berbayar saja, dan langganan aktif langsung dimulai tanpa iklan.',
    'file_rights_unit': 'FILE',
    'start_cost_one_file_right': 'file',
    'wallet_paid_token_label': 'Token berbayar',
    'history_menu_tokens': 'Riwayat terjemahan/token',
    'credit_history_title_tokens': 'Riwayat token',
    'credit_history_add_tokens': 'Token ditambahkan',
    'credit_history_spend_tokens': 'Token digunakan',
    'credit_history_subscription_forfeit_tokens': 'Token langganan yang tidak terpakai direset',
    'add_tokens': 'Tambah token',
    'credit_explanation_tokens':
        'Pemakaian token mengikuti panjang file. Sisa kredit berbayar tetap 1 file = 1 kredit.',
    'token_estimate_title': 'Perkiraan pemakaian token',
    'token_estimate_body':
        'File ini akan memakai sekitar {tokens} token. Sisa setelahnya: {remaining}.',
    'token_estimate_cancel': 'Batal',
    'token_estimate_confirm': 'Mulai',
    'token_insufficient_title': 'Token tidak cukup',
    'token_insufficient_body':
        'File ini membutuhkan {needed} token. Anda punya {balance}.',
    'token_insufficient_shop': 'Tambah token',
    'credit_policy_live_title': 'Penagihan kini memakai token',
    'credit_policy_live_intro':
        'Mulai 1 September 2026 terjemahan baru dikenakan token. File panjang lebih mahal, yang pendek lebih murah. Anda melihat perkiraan sebelum mulai.',
    'credit_policy_live_rule_1':
        'Kredit file berbayar yang sudah ada tetap berlaku: 1 file = 1 kredit sampai habis.',
    'credit_policy_live_rule_2':
        'Isi ulang baru adalah paket 1 / 5 / 10 juta token. Sisa kredit dan saldo token tampil bersama.',
    'credit_policy_live_rule_3':
        'Satu pekerjaan memakai sisa kredit file atau token — tidak dicampur.',
    'credit_policy_live_ads':
        'Iklan berhadiah berlanjut: 5 iklan = 75.000 token. Batas harian dan mingguan tetap.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Sekitar {movies} film atau {episodes} episode',

  },
  'CN': {
    'wallet_token_label': '代币',
    'wallet_bonus_token_label': '奖励代币',
    'credit_explanation_tokens_paid': '剩余付费额度仍按 1 个文件 = 1 额度。剩余奖励积分会转换为代币。',
    'credit_explanation_tokens_expiry': '奖励代币有效期为 1 个月，可累积使用；满 1 个月后，账户中未用完的奖励代币将被清除。',
    'bonus_token_expiry_title': '奖励代币会过期',
    'ad_reward_tile_title_tokens': '看广告，赚代币',
    'ad_reward_tile_desc_tokens': '每看一条广告可得 5,000 代币。',
    'ad_reward_limit_desc_tokens': '每天最多观看 10 条，每周最多 40 条。奖励代币有效期为 1 个月，可累积使用；满 1 个月后，账户中未用完的奖励代币将被清除。',
    'ad_reward_each_ad_hint': '每条广告增加 {tokens} 代币。',
    'token_mix_paid_title': '奖励代币不足',
    'token_mix_paid_body': '此文件约需 {needed} 代币：{bonus} 从奖励代币扣除，{paid} 从付费代币扣除。',
    'token_mix_paid_confirm': '继续',
    'referral_cta_tokens': '推荐并\n赚取代币',
    'referral_dialog_desc_tokens': '把邀请码发给朋友。对方加入并兑换后，你们各得 150,000 代币。',
    'referral_claim_success_tokens': '邀请奖励已到账，已发放 150,000 代币。',
    'referral_share_message_tokens': '用我的邀请码加入 AI SRT Subtitle Translator & Editor：{code}。兑换后我们各得 150,000 代币。',
    'tutorial_referral_desc_tokens': '这个按钮会打开邀请中心。邀请朋友，双方都能拿到 150,000 代币。需要用 Google 登录。',
    'credit_source_referral': '邀请奖励',
    'ad_reward_token_cta': '观看广告\n赚取代币',
    'prefer_free_tokens_first': '优先使用奖励代币',
    'subscription_monthly_note_tokens': '按月续订。未使用的代币不会结转。',
    'ad_gate_desc_tokens': '奖励代币在处理前会显示激励广告。若奖励代币不足，差额从付费代币扣除，广告仍会播放。已购文件额度、纯付费代币任务和有效订阅可立即开始且无广告。',
    'file_rights_unit': '文件',
    'start_cost_one_file_right': '文件',
    'wallet_paid_token_label': '付费代币',
    'history_menu_tokens': '翻译/代币记录',
    'credit_history_title_tokens': '代币记录',
    'credit_history_add_tokens': '已添加代币',
    'credit_history_spend_tokens': '已消耗代币',
    'credit_history_subscription_forfeit_tokens': '未用完的订阅代币已清零',
    'add_tokens': '添加代币',
    'credit_explanation_tokens':
        '代币按文件长度计费。剩余付费额度仍按 1 个文件 = 1 额度。',
    'token_estimate_title': '预计代币用量',
    'token_estimate_body':
        '此文件大约使用 {tokens} 代币。之后剩余：{remaining}。',
    'token_estimate_cancel': '取消',
    'token_estimate_confirm': '开始',
    'token_insufficient_title': '代币不足',
    'token_insufficient_body':
        '此文件需要 {needed} 代币。您有 {balance}。',
    'token_insufficient_shop': '添加代币',
    'credit_policy_live_title': '现已按代币计费',
    'credit_policy_live_intro':
        '自 2026 年 9 月 1 日起，新翻译按代币计费。较长文件费用更高，较短更低。开始前会显示预估。',
    'credit_policy_live_rule_1':
        '已购买的文件额度仍按 1 文件 = 1 额度，直到用完。',
    'credit_policy_live_rule_2':
        '新充值是 100 万 / 500 万 / 1000 万代币包。剩余额度与代币余额一起显示。',
    'credit_policy_live_rule_3':
        '一次任务只使用剩余文件额度或代币，不会混用。',
    'credit_policy_live_ads':
        '激励广告继续：5 次广告 = 75,000 代币。每日和每周上限不变。',
    'credit_policy_live_ok': '确定',
    'token_pack_coverage':
        '约 {movies} 部电影或 {episodes} 集剧集',

  },
  'JA': {
    'wallet_token_label': 'トークン',
    'wallet_bonus_token_label': 'ボーナストークン',
    'credit_explanation_tokens_paid': '残りの有料クレジットは 1 ファイル = 1 クレジットのままです。残りのボーナスクレジットはトークンに変換されます。',
    'credit_explanation_tokens_expiry': 'ボーナストークンの有効期限は1か月です。この期間中は貯めて使えます。1か月経過後、残っているボーナストークンはアカウントから削除されます。',
    'bonus_token_expiry_title': 'ボーナストークンの有効期限',
    'ad_reward_tile_title_tokens': '広告を見てトークンを得る',
    'ad_reward_tile_desc_tokens': '広告1本で5,000トークンです。',
    'ad_reward_limit_desc_tokens': '1日最大10本、週最大40本まで視聴できます。ボーナストークンの有効期限は1か月です。この期間中は貯めて使えます。1か月経過後、残っているボーナストークンはアカウントから削除されます。',
    'ad_reward_each_ad_hint': '広告1本で{tokens}トークンが入ります。',
    'token_mix_paid_title': 'ボーナストークンが足りません',
    'token_mix_paid_body': 'このファイルは約 {needed} トークン必要です。{bonus} はボーナス、{paid} は有料トークンから差し引かれます。',
    'token_mix_paid_confirm': '続行',
    'referral_cta_tokens': '紹介して\nトークンを獲得',
    'referral_dialog_desc_tokens': 'コードを友だちに共有してください。アプリに参加してコードを使うと、お互いに 150,000 トークンが入ります。',
    'referral_claim_success_tokens': '紹介ボーナスを追加しました。150,000 トークンを付与しました。',
    'referral_share_message_tokens':
        '私の紹介コード {code} で AI SRT Subtitle Translator & Editor に参加してください。コードを使うと、二人とも 150,000 トークンを受け取れます。',
    'tutorial_referral_desc_tokens': 'このボタンで紹介センターが開きます。友だちを招待すると、二人とも 150,000 トークンを獲得できます。Google ログインが必要です。',
    'credit_source_referral': '紹介特典',
    'ad_reward_token_cta': '広告を見る\nトークンを獲得',
    'prefer_free_tokens_first': 'ボーナストークンを先に使う',
    'subscription_monthly_note_tokens': '毎月更新。未使用トークンは繰り越されません。',
    'ad_gate_desc_tokens': 'ボーナストークンは処理前にリワード広告が表示されます。足りない場合は有料トークンから補填され、広告は表示されたままです。有料ファイルクレジット、有料トークンのみのジョブ、有効なサブスクリプションは広告なしですぐに開始します。',
    'file_rights_unit': 'ファイル',
    'start_cost_one_file_right': 'ファイル',
    'wallet_paid_token_label': '有料トークン',
    'history_menu_tokens': '翻訳/トークン履歴',
    'credit_history_title_tokens': 'トークン履歴',
    'credit_history_add_tokens': 'トークン追加',
    'credit_history_spend_tokens': 'トークン消費',
    'credit_history_subscription_forfeit_tokens': '使われなかった定期購入トークンをリセットしました',
    'add_tokens': 'トークンを追加',
    'credit_explanation_tokens':
        'トークンはファイルの長さに応じて消費されます。残りの有料クレジットは 1 ファイル = 1 クレジットのままです。',
    'token_estimate_title': 'トークン使用量の見積もり',
    'token_estimate_body':
        'このファイルは約 {tokens} トークンを使います。残り: {remaining}。',
    'token_estimate_cancel': 'キャンセル',
    'token_estimate_confirm': '開始',
    'token_insufficient_title': 'トークンが足りません',
    'token_insufficient_body':
        'このファイルには {needed} トークンが必要です。残高は {balance} です。',
    'token_insufficient_shop': 'トークンを追加',
    'credit_policy_live_title': '課金はトークンになりました',
    'credit_policy_live_intro':
        '2026年9月1日から新しい翻訳はトークンで課金されます。長いファイルほど高く、短いほど安くなります。開始前に見積もりが表示されます。',
    'credit_policy_live_rule_1':
        'すでに購入したファイルクレジットはなくなるまで 1 ファイル = 1 クレジットです。',
    'credit_policy_live_rule_2':
        '新しいチャージは 100万 / 500万 / 1000万トークンパックです。残クレジットとトークン残高は一緒に表示されます。',
    'credit_policy_live_rule_3':
        '1件のジョブは残りのファイルクレジットかトークンのどちらかを使い、混在しません。',
    'credit_policy_live_ads':
        'リワード広告は継続: 広告5回 = 75,000トークン。日次・週次上限は同じです。',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        '約{movies}本の映画、または{episodes}話のドラマ',

  },
  'KO': {
    'wallet_token_label': '토큰',
    'wallet_bonus_token_label': '보너스 토큰',
    'credit_explanation_tokens_paid': '남은 유료 크레딧은 여전히 파일 1개 = 크레딧 1개입니다. 남은 보너스 크레딧은 토큰으로 전환됩니다.',
    'credit_explanation_tokens_expiry': '보너스 토큰은 1개월 동안 유효합니다. 이 기간 동안 모아서 사용할 수 있으며, 1개월이 지나면 남은 보너스 토큰은 계정에서 삭제됩니다.',
    'bonus_token_expiry_title': '보너스 토큰은 만료됩니다',
    'ad_reward_tile_title_tokens': '광고 보고 토큰 받기',
    'ad_reward_tile_desc_tokens': '광고 1회당 5,000토큰입니다.',
    'ad_reward_limit_desc_tokens': '하루 최대 10회, 주 최대 40회 시청할 수 있습니다. 보너스 토큰은 1개월 동안 유효합니다. 이 기간 동안 모아서 사용할 수 있으며, 1개월이 지나면 남은 보너스 토큰은 계정에서 삭제됩니다.',
    'ad_reward_each_ad_hint': '광고 1회마다 {tokens}토큰이 추가됩니다.',
    'token_mix_paid_title': '보너스 토큰이 부족합니다',
    'token_mix_paid_body': '이 파일은 약 {needed} 토큰이 필요합니다. {bonus}는 보너스에서, {paid}는 유료에서 차감됩니다.',
    'token_mix_paid_confirm': '계속',
    'referral_cta_tokens': '추천하고\n토큰 받기',
    'referral_dialog_desc_tokens': '코드를 친구와 공유하세요. 앱에 가입해 코드를 쓰면 두 분 모두 150,000토큰을 받습니다.',
    'referral_claim_success_tokens': '추천 보너스가 추가되어 150,000토큰이 지급되었습니다.',
    'referral_share_message_tokens':
        '내 추천 코드 {code}로 AI SRT Subtitle Translator & Editor에 가입하세요. 코드를 쓰면 우리 둘 다 150,000토큰을 받습니다.',
    'tutorial_referral_desc_tokens': '이 버튼은 추천 센터를 엽니다. 친구를 초대하면 두 분 모두 150,000토큰을 받을 수 있습니다. Google 로그인이 필요합니다.',
    'credit_source_referral': '추천 보상',
    'ad_reward_token_cta': '광고 시청\n토큰 받기',
    'prefer_free_tokens_first': '보너스 토큰 먼저 사용',
    'subscription_monthly_note_tokens': '매월 갱신. 사용하지 않은 토큰은 이월되지 않습니다.',
    'ad_gate_desc_tokens': '보너스 토큰은 처리 전 보상형 광고가 표시됩니다. 부족하면 유료 토큰에서 나머지가 차감되며 광고는 그대로 표시됩니다. 유료 파일 크레딧, 유료 토큰 전용 작업, 활성 구독은 광고 없이 즉시 시작됩니다.',
    'file_rights_unit': '파일',
    'start_cost_one_file_right': '파일',
    'wallet_paid_token_label': '유료 토큰',
    'history_menu_tokens': '번역/토큰 기록',
    'credit_history_title_tokens': '토큰 기록',
    'credit_history_add_tokens': '토큰 추가됨',
    'credit_history_spend_tokens': '토큰 사용됨',
    'credit_history_subscription_forfeit_tokens': '쓰지 않은 구독 토큰이 초기화됨',
    'add_tokens': '토큰 추가',
    'credit_explanation_tokens':
        '토큰은 파일 길이에 따라 사용됩니다. 남은 유료 크레딧은 여전히 파일 1개 = 크레딧 1개입니다.',
    'token_estimate_title': '예상 토큰 사용량',
    'token_estimate_body':
        '이 파일은 약 {tokens} 토큰을 사용합니다. 이후 잔액: {remaining}.',
    'token_estimate_cancel': '취소',
    'token_estimate_confirm': '시작',
    'token_insufficient_title': '토큰이 부족합니다',
    'token_insufficient_body':
        '이 파일에는 {needed} 토큰이 필요합니다. 보유량: {balance}.',
    'token_insufficient_shop': '토큰 추가',
    'credit_policy_live_title': '이제 토큰으로 결제됩니다',
    'credit_policy_live_intro':
        '2026년 9월 1일부터 새 번역은 토큰으로 청구됩니다. 긴 파일은 더 비싸고 짧은 파일은 더 저렴합니다. 시작 전에 예상치가 표시됩니다.',
    'credit_policy_live_rule_1':
        '이미 구매한 파일 크레딧은 소진될 때까지 파일 1개 = 크레딧 1개입니다.',
    'credit_policy_live_rule_2':
        '새 충전은 100만 / 500만 / 1000만 토큰 팩입니다. 남은 크레딧과 토큰 잔액이 함께 표시됩니다.',
    'credit_policy_live_rule_3':
        '한 작업은 남은 파일 크레딧 또는 토큰만 사용하며 섞지 않습니다.',
    'credit_policy_live_ads':
        '리워드 광고 유지: 광고 5회 = 75,000 토큰. 일일·주간 한도는 그대로입니다.',
    'credit_policy_live_ok': '확인',
    'token_pack_coverage':
        '약 {movies}편의 영화 또는 {episodes}편의 에피소드',

  },
  'NL': {
    'wallet_token_label': 'Tokens',
    'wallet_bonus_token_label': 'Bonustokens',
    'credit_explanation_tokens_paid': 'Overgebleven betaalde credits blijven 1 bestand = 1 credit. Overgebleven bonuscredits worden tokens.',
    'credit_explanation_tokens_expiry': 'Bonustokens zijn 1 maand geldig. Je kunt ze sparen en in die periode gebruiken; na 1 maand worden ongebruikte bonustokens van je account verwijderd.',
    'bonus_token_expiry_title': 'Bonustokens vervallen',
    'ad_reward_tile_title_tokens': 'Advertentie kijken, tokens verdienen',
    'ad_reward_tile_desc_tokens': 'Elke advertentie levert 5.000 tokens op.',
    'ad_reward_limit_desc_tokens': 'Maximaal 10 advertenties per dag en 40 per week. Bonustokens zijn 1 maand geldig. Je kunt ze sparen en in die periode gebruiken; na 1 maand worden ongebruikte bonustokens van je account verwijderd.',
    'ad_reward_each_ad_hint': 'Elke advertentie voegt {tokens} tokens toe.',
    'token_mix_paid_title': 'Bonustokens zijn onvoldoende',
    'token_mix_paid_body': 'Dit bestand heeft ongeveer {needed} tokens nodig: {bonus} van bonustokens, {paid} van betaalde tokens.',
    'token_mix_paid_confirm': 'Doorgaan',
    'referral_cta_tokens': 'Verwijs en\nverdien tokens',
    'referral_dialog_desc_tokens':
        'Deel je code met een vriend. Als die de app opent en de code inwisselt, krijgen jullie allebei 150.000 tokens.',
    'referral_claim_success_tokens': 'Verwijzingsbonus toegevoegd. Er zijn 150.000 tokens bijgeschreven.',
    'referral_share_message_tokens':
        'Ga naar AI SRT Subtitle Translator & Editor met mijn verwijzingscode: {code}. Als je die inwisselt, krijgen we allebei 150.000 tokens.',
    'tutorial_referral_desc_tokens':
        'Deze knop opent het verwijzingscentrum. Nodig vrienden uit en jullie krijgen allebei 150.000 tokens. Inloggen met Google is verplicht.',
    'credit_source_referral': 'Verwijzingsbeloning',
    'ad_reward_token_cta': 'Advertentie bekijken\nTokens verdienen',
    'prefer_free_tokens_first': 'Eerst bonustokens gebruiken',
    'subscription_monthly_note_tokens': 'Wordt maandelijks verlengd. Ongebruikte tokens worden niet meegenomen.',
    'ad_gate_desc_tokens': 'Bonustokens tonen vóór verwerking een beloningsadvertentie. Als ze niet genoeg zijn, komt de rest uit betaalde tokens en wordt de advertentie alsnog getoond. Betaalde bestandcredits, alleen-betaalde-token taken en actieve abonnementen starten direct zonder advertenties.',
    'file_rights_unit': 'BESTAND',
    'start_cost_one_file_right': 'bestand',
    'wallet_paid_token_label': 'Betaalde tokens',
    'history_menu_tokens': 'Vertaal-/token-geschiedenis',
    'credit_history_title_tokens': 'Token-geschiedenis',
    'credit_history_add_tokens': 'Tokens toegevoegd',
    'credit_history_spend_tokens': 'Tokens verbruikt',
    'credit_history_subscription_forfeit_tokens': 'Ongebruikte abonnementstokens gereset',
    'add_tokens': 'Tokens toevoegen',
    'credit_explanation_tokens':
        'Tokens hangen af van de bestandslengte. Overgebleven betaalde credits blijven 1 bestand = 1 credit.',
    'token_estimate_title': 'Geschat tokenverbruik',
    'token_estimate_body':
        'Dit bestand gebruikt ongeveer {tokens} tokens. Daarna over: {remaining}.',
    'token_estimate_cancel': 'Annuleren',
    'token_estimate_confirm': 'Starten',
    'token_insufficient_title': 'Niet genoeg tokens',
    'token_insufficient_body':
        'Dit bestand heeft {needed} tokens nodig. U heeft {balance}.',
    'token_insufficient_shop': 'Tokens toevoegen',
    'credit_policy_live_title': 'Facturatie gebruikt nu tokens',
    'credit_policy_live_intro':
        'Vanaf 1 september 2026 worden nieuwe vertalingen in tokens gerekend. Langere bestanden kosten meer, kortere minder. U ziet een schatting vóór de start.',
    'credit_policy_live_rule_1':
        'Betaalde bestandcredits die u al heeft, blijven 1 bestand = 1 credit tot ze op zijn.',
    'credit_policy_live_rule_2':
        'Nieuwe opwaarderingen zijn pakketten van 1 / 5 / 10 miljoen tokens. Restcredits en tokensaldo staan samen.',
    'credit_policy_live_rule_3':
        'Eén opdracht gebruikt óf rest-bestandcredits óf tokens — nooit gemengd.',
    'credit_policy_live_ads':
        'Beloonde ads blijven: 5 ads = 75.000 tokens. Dag- en weeklimieten blijven gelijk.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Ongeveer {movies} films of {episodes} afleveringen',

  },
  'SV': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Bonustoken',
    'credit_explanation_tokens_paid': 'Kvarvarande betalda krediter täcker fortfarande 1 fil = 1 kredit. Kvarvarande bonuskrediter blir token.',
    'credit_explanation_tokens_expiry': 'Bonustoken gäller i 1 månad. Du kan samla dem och använda dem under den tiden; efter 1 månad tas oanvända bonustoken bort från ditt konto.',
    'bonus_token_expiry_title': 'Bonustoken går ut',
    'ad_reward_tile_title_tokens': 'Titta på annons, tjäna token',
    'ad_reward_tile_desc_tokens': 'Varje annons ger 5 000 token.',
    'ad_reward_limit_desc_tokens': 'Högst 10 annonser per dag och 40 per vecka. Bonustoken gäller i 1 månad. Du kan samla dem och använda dem under den tiden; efter 1 månad tas oanvända bonustoken bort från ditt konto.',
    'ad_reward_each_ad_hint': 'Varje annons lägger till {tokens} token.',
    'token_mix_paid_title': 'Bonustoken räcker inte',
    'token_mix_paid_body': 'Den här filen behöver cirka {needed} tokens: {bonus} från bonustokens, {paid} från betalda tokens.',
    'token_mix_paid_confirm': 'Fortsätt',
    'referral_cta_tokens': 'Referera och\nTjäna token',
    'referral_dialog_desc_tokens': 'Dela din kod med en vän. När hen går med och löser in den får ni båda 150 000 token.',
    'referral_claim_success_tokens': 'Värvningsbonus tillagd. 150 000 token har satts in.',
    'referral_share_message_tokens':
        'Gå med i AI SRT Subtitle Translator & Editor med min värvningskod: {code}. När du löser in den får vi båda 150 000 token.',
    'tutorial_referral_desc_tokens':
        'Den här knappen öppnar värvningscentret. Bjud in vänner så kan ni båda få 150 000 token. Google-inloggning krävs.',
    'credit_source_referral': 'Värvningsbelöning',
    'ad_reward_token_cta': 'Titta på annons\nTjäna token',
    'prefer_free_tokens_first': 'Använd bonustoken först',
    'subscription_monthly_note_tokens': 'Förnyas månadsvis. Oanvända token sparas inte.',
    'ad_gate_desc_tokens': 'Bonustokens visar en belöningsannons före bearbetning. Räcker de inte tas resten från betalda tokens och annonsen visas ändå. Betalda filkrediter, enbart betalda tokenjobb och aktiva prenumerationer startar direkt utan annonser.',
    'file_rights_unit': 'FIL',
    'start_cost_one_file_right': 'fil',
    'wallet_paid_token_label': 'Betalda token',
    'history_menu_tokens': 'Översättnings-/tokenhistorik',
    'credit_history_title_tokens': 'Tokenhistorik',
    'credit_history_add_tokens': 'Token tillagda',
    'credit_history_spend_tokens': 'Token förbrukade',
    'credit_history_subscription_forfeit_tokens': 'Oanvända prenumerationstoken nollställdes',
    'add_tokens': 'Lägg till token',
    'credit_explanation_tokens':
        'Token beror på fillängden. Kvarvarande betalda krediter täcker fortfarande 1 fil = 1 kredit.',
    'token_estimate_title': 'Beräknad tokenanvändning',
    'token_estimate_body':
        'Den här filen använder cirka {tokens} token. Kvar efteråt: {remaining}.',
    'token_estimate_cancel': 'Avbryt',
    'token_estimate_confirm': 'Starta',
    'token_insufficient_title': 'Inte tillräckligt med token',
    'token_insufficient_body':
        'Den här filen behöver {needed} token. Du har {balance}.',
    'token_insufficient_shop': 'Lägg till token',
    'credit_policy_live_title': 'Fakturering sker nu med token',
    'credit_policy_live_intro':
        'Från 1 september 2026 debiteras nya översättningar i token. Längre filer kostar mer, kortare mindre. Du ser en uppskattning innan start.',
    'credit_policy_live_rule_1':
        'Betalda filkrediter du redan har gäller som 1 fil = 1 kredit tills de tar slut.',
    'credit_policy_live_rule_2':
        'Nya påfyllningar är paket på 1 / 5 / 10 miljoner token. Kvarvarande krediter och tokensaldo visas tillsammans.',
    'credit_policy_live_rule_3':
        'Ett jobb använder antingen kvarvarande filkrediter eller token — aldrig båda blandade.',
    'credit_policy_live_ads':
        'Belöningsannonser fortsätter: 5 annonser = 75 000 token. Dygns- och veckogränsen är densamma.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Cirka {movies} filmer eller {episodes} avsnitt',

  },
  'PL': {
    'wallet_token_label': 'Tokeny',
    'wallet_bonus_token_label': 'Tokeny bonus',
    'credit_explanation_tokens_paid': 'Pozostałe płatne kredyty nadal: 1 plik = 1 kredyt. Pozostałe bonusowe kredyty zamieniają się w tokeny.',
    'credit_explanation_tokens_expiry': 'Tokeny bonusowe są ważne przez 1 miesiąc. Możesz je zbierać i wykorzystywać w tym czasie; po upływie miesiąca niewykorzystane tokeny bonusowe są usuwane z konta.',
    'bonus_token_expiry_title': 'Tokeny bonusowe wygasają',
    'ad_reward_tile_title_tokens': 'Oglądaj reklamę, zdobywaj tokeny',
    'ad_reward_tile_desc_tokens': 'Każda reklama daje 5 000 tokenów.',
    'ad_reward_limit_desc_tokens': 'Maksymalnie 10 reklam dziennie i 40 tygodniowo. Tokeny bonusowe są ważne przez 1 miesiąc. Możesz je zbierać i wykorzystywać w tym czasie; po upływie miesiąca niewykorzystane tokeny bonusowe są usuwane z konta.',
    'ad_reward_each_ad_hint': 'Każda reklama dodaje {tokens} tokenów.',
    'token_mix_paid_title': 'Bonusowych tokenów brakuje',
    'token_mix_paid_body': 'Ten plik wymaga około {needed} tokenów: {bonus} z bonusowych, {paid} z płatnych.',
    'token_mix_paid_confirm': 'Kontynuuj',
    'referral_cta_tokens': 'Poleć i\nZdobądź tokeny',
    'referral_dialog_desc_tokens':
        'Udostępnij kod znajomemu. Gdy dołączy do aplikacji i go użyje, oboje dostaniecie 150 000 tokenów.',
    'referral_claim_success_tokens': 'Dodano bonus za polecenie. Przyznano 150 000 tokenów.',
    'referral_share_message_tokens':
        'Dołącz do AI SRT Subtitle Translator & Editor z moim kodem polecającym: {code}. Po jego użyciu oboje dostaniemy 150 000 tokenów.',
    'tutorial_referral_desc_tokens':
        'Ten przycisk otwiera centrum poleceń. Zaproś znajomych — oboje możecie dostać 150 000 tokenów. Wymagane logowanie przez Google.',
    'credit_source_referral': 'Nagroda za polecenie',
    'ad_reward_token_cta': 'Obejrzyj reklamę\nZdobądź tokeny',
    'prefer_free_tokens_first': 'Najpierw użyj bonusowych tokenów',
    'subscription_monthly_note_tokens': 'Odnawia się co miesiąc. Niewykorzystane tokeny nie przechodzą dalej.',
    'ad_gate_desc_tokens': 'Bonusowe tokeny pokazują reklamę z nagrodą przed przetwarzaniem. Gdy ich brakuje, reszta jest pobierana z tokenów płatnych, a reklama nadal się wyświetla. Płatne kredyty plików, zadania tylko na tokenach płatnych i aktywne subskrypcje startują natychmiast bez reklam.',
    'file_rights_unit': 'PLIK',
    'start_cost_one_file_right': 'plik',
    'wallet_paid_token_label': 'Tokeny płatne',
    'history_menu_tokens': 'Historia tłumaczeń/tokenów',
    'credit_history_title_tokens': 'Historia tokenów',
    'credit_history_add_tokens': 'Dodano tokeny',
    'credit_history_spend_tokens': 'Wydano tokeny',
    'credit_history_subscription_forfeit_tokens': 'Niewykorzystane tokeny subskrypcji wyzerowane',
    'add_tokens': 'Dodaj tokeny',
    'credit_explanation_tokens':
        'Zużycie tokenów zależy od długości pliku. Pozostałe płatne kredyty nadal: 1 plik = 1 kredyt.',
    'token_estimate_title': 'Szacowane zużycie tokenów',
    'token_estimate_body':
        'Ten plik zużyje około {tokens} tokenów. Zostanie: {remaining}.',
    'token_estimate_cancel': 'Anuluj',
    'token_estimate_confirm': 'Start',
    'token_insufficient_title': 'Za mało tokenów',
    'token_insufficient_body':
        'Ten plik wymaga {needed} tokenów. Masz {balance}.',
    'token_insufficient_shop': 'Dodaj tokeny',
    'credit_policy_live_title': 'Rozliczenie jest teraz w tokenach',
    'credit_policy_live_intro':
        'Od 1 września 2026 nowe tłumaczenia są rozliczane w tokenach. Dłuższe pliki kosztują więcej, krótsze mniej. Przed startem widzisz szacunek.',
    'credit_policy_live_rule_1':
        'Posiadane płatne kredyty plików działają jako 1 plik = 1 kredyt do wyczerpania.',
    'credit_policy_live_rule_2':
        'Nowe doładowania to pakiety 1 / 5 / 10 milionów tokenów. Pozostałe kredyty i saldo tokenów widać razem.',
    'credit_policy_live_rule_3':
        'Jedno zadanie zużywa albo pozostałe kredyty plików, albo tokeny — nigdy obu naraz.',
    'credit_policy_live_ads':
        'Reklamy z nagrodą bez zmian: 5 reklam = 75 000 tokenów. Limity dzienne i tygodniowe te same.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Około {movies} filmów lub {episodes} odcinków',

  },
  'HE': {
    'wallet_token_label': 'טוקנים',
    'wallet_bonus_token_label': 'טוקני בונוס',
    'credit_explanation_tokens_paid': 'קרדיטים בתשלום שנותרו עדיין מכסים קובץ אחד לכל קרדיט. קרדיטי בונוס שנותרו הופכים לטוקנים.',
    'credit_explanation_tokens_expiry': 'טוקני בונוס תקפים לחודש. ניתן לצבור אותם ולהשתמש בהם במהלך תקופה זו; לאחר חודש, טוקני הבונוס שנותרו יימחקו מהחשבון.',
    'bonus_token_expiry_title': 'טוקני הבונוס פגים',
    'ad_reward_tile_title_tokens': 'צפו בפרסומת וצברו טוקנים',
    'ad_reward_tile_desc_tokens': 'כל פרסומת נותנת 5,000 טוקנים.',
    'ad_reward_limit_desc_tokens': 'עד 10 פרסומות ביום ו־40 בשבוע. טוקני בונוס תקפים לחודש. ניתן לצבור אותם ולהשתמש בהם במהלך תקופה זו; לאחר חודש, טוקני הבונוס שנותרו יימחקו מהחשבון.',
    'ad_reward_each_ad_hint': 'כל פרסומת מוסיפה {tokens} טוקנים.',
    'token_mix_paid_title': 'טוקני הבונוס לא מספיקים',
    'token_mix_paid_body': 'קובץ זה דורש כ-{needed} טוקנים: {bonus} מטוקני בונוס, {paid} מטוקנים בתשלום.',
    'token_mix_paid_confirm': 'המשך',
    'referral_cta_tokens': 'הפנה ו\nהרווח טוקנים',
    'referral_dialog_desc_tokens': 'שתפו את הקוד עם חבר. כשהוא מצטרף לאפליקציה ומממש אותו, שניכם מקבלים 150,000 טוקנים.',
    'referral_claim_success_tokens': 'בונוס ההזמנה נוסף. הוענקו 150,000 טוקנים.',
    'referral_share_message_tokens':
        'הצטרפו ל-AI SRT Subtitle Translator & Editor עם קוד ההזמנה שלי: {code}. במימוש הקוד שנינו מקבלים 150,000 טוקנים.',
    'tutorial_referral_desc_tokens':
        'הכפתור הזה פותח את מרכז ההזמנות. הזמינו חברים ושניכם יכולים לקבל 150,000 טוקנים. נדרשת כניסה עם Google.',
    'credit_source_referral': 'פרס הזמנה',
    'ad_reward_token_cta': 'צפה בפרסומת\nהרווח טוקנים',
    'prefer_free_tokens_first': 'השתמש קודם בטוקני בונוס',
    'subscription_monthly_note_tokens': 'מתחדש מדי חודש. טוקנים שלא נוצלו לא מועברים.',
    'ad_gate_desc_tokens': 'טוקני בונוס מציגים מודעת תגמול לפני העיבוד. אם אין מספיק, השאר נגבה מטוקנים בתשלום והמודעה עדיין מוצגת. קרדיטי קבצים בתשלום, עבודות בטוקנים בתשלום בלבד ומנויים פעילים מתחילים מיד ללא פרסומות.',
    'file_rights_unit': 'קובץ',
    'start_cost_one_file_right': 'קובץ',
    'wallet_paid_token_label': 'טוקנים בתשלום',
    'history_menu_tokens': 'היסטוריית תרגום/טוקנים',
    'credit_history_title_tokens': 'היסטוריית טוקנים',
    'credit_history_add_tokens': 'נוספו טוקנים',
    'credit_history_spend_tokens': 'נוצלו טוקנים',
    'credit_history_subscription_forfeit_tokens': 'טוקני המנוי שלא נוצלו אופסו',
    'add_tokens': 'הוסף טוקנים',
    'credit_explanation_tokens':
        'צריכת הטוקנים תלויה באורך הקובץ. קרדיטים בתשלום שנותרו עדיין מכסים קובץ אחד לכל קרדיט.',
    'token_estimate_title': 'הערכת שימוש בטוקנים',
    'token_estimate_body':
        'הקובץ ישתמש בכ־{tokens} טוקנים. יישארו: {remaining}.',
    'token_estimate_cancel': 'ביטול',
    'token_estimate_confirm': 'התחל',
    'token_insufficient_title': 'אין מספיק טוקנים',
    'token_insufficient_body':
        'הקובץ צריך {needed} טוקנים. יש לך {balance}.',
    'token_insufficient_shop': 'הוסף טוקנים',
    'credit_policy_live_title': 'החיוב הוא כעת בטוקנים',
    'credit_policy_live_intro':
        'מ־1 בספטמבר 2026 תרגומים חדשים מחויבים בטוקנים. קבצים ארוכים עולים יותר, קצרים פחות. מוצגת הערכה לפני ההתחלה.',
    'credit_policy_live_rule_1':
        'קרדיטי הקבצים שכבר שולמו נשארים 1 קובץ = 1 קרדיט עד שייגמרו.',
    'credit_policy_live_rule_2':
        'הטענות חדשות הן חבילות של 1 / 5 / 10 מיליון טוקנים. קרדיטים שנותרו ויתרת הטוקנים מוצגים יחד.',
    'credit_policy_live_rule_3':
        'משימה אחת משתמשת בקרדיטי קובץ שנותרו או בטוקנים — לא בערבוב.',
    'credit_policy_live_ads':
        'פרסומות עם תגמול נמשכות: 5 פרסומות = 75,000 טוקנים. המגבלות היומיות והשבועיות זהות.',
    'credit_policy_live_ok': 'אישור',
    'token_pack_coverage':
        'בערך {movies} סרטים או {episodes} פרקים',

  },
  'FA': {
    'wallet_token_label': 'توکن',
    'wallet_bonus_token_label': 'توکن پاداش',
    'credit_explanation_tokens_paid': 'اعتبارهای پرداخت‌شده باقی‌مانده هنوز ۱ فایل = ۱ اعتبار است. اعتبارهای پاداش باقی‌مانده به توکن تبدیل می‌شوند.',
    'credit_explanation_tokens_expiry': 'توکن پاداش یک ماه اعتبار دارد. می‌توانید آن‌ها را جمع کنید و در این مدت استفاده کنید؛ پس از یک ماه، توکن‌های پاداش باقی‌مانده از حساب شما حذف می‌شوند.',
    'bonus_token_expiry_title': 'توکن‌های پاداش منقضی می‌شوند',
    'ad_reward_tile_title_tokens': 'تبلیغ ببین، توکن بگیر',
    'ad_reward_tile_desc_tokens': 'هر تبلیغ ۵٬۰۰۰ توکن می‌دهد.',
    'ad_reward_limit_desc_tokens': 'روزانه تا ۱۰ و هفتگی تا ۴۰ تبلیغ. توکن پاداش یک ماه اعتبار دارد. می‌توانید آن‌ها را جمع کنید و در این مدت استفاده کنید؛ پس از یک ماه، توکن‌های پاداش باقی‌مانده از حساب شما حذف می‌شوند.',
    'ad_reward_each_ad_hint': 'هر تبلیغ {tokens} توکن اضافه می‌کند.',
    'token_mix_paid_title': 'توکن پاداش کافی نیست',
    'token_mix_paid_body': 'این فایل حدود {needed} توکن می‌خواهد: {bonus} از پاداش، {paid} از توکن پولی.',
    'token_mix_paid_confirm': 'ادامه',
    'referral_cta_tokens': 'معرفی کن و\nتوکن بگیر',
    'referral_dialog_desc_tokens':
        'کدتان را با یک دوست به اشتراک بگذارید. وقتی وارد برنامه شود و کد را وارد کند، هر دو ۱۵۰٬۰۰۰ توکن می‌گیرید.',
    'referral_claim_success_tokens': 'پاداش دعوت اضافه شد. ۱۵۰٬۰۰۰ توکن به حساب نشست.',
    'referral_share_message_tokens':
        'با کد دعوت من به AI SRT Subtitle Translator & Editor بپیوندید: {code}. با وارد کردن کد، هر دو ۱۵۰٬۰۰۰ توکن می‌گیریم.',
    'tutorial_referral_desc_tokens':
        'این دکمه مرکز دعوت را باز می‌کند. دوستان را دعوت کنید تا هر دو ۱۵۰٬۰۰۰ توکن بگیرید. ورود با Google لازم است.',
    'credit_source_referral': 'پاداش دعوت',
    'ad_reward_token_cta': 'تبلیغ ببین\nتوکن بگیر',
    'prefer_free_tokens_first': 'ابتدا از توکن‌های پاداش استفاده کن',
    'subscription_monthly_note_tokens': 'ماهانه تمدید می‌شود. توکن‌های استفاده‌نشده منتقل نمی‌شوند.',
    'ad_gate_desc_tokens': 'توکن‌های پاداش قبل از پردازش تبلیغ پاداش‌دار نشان می‌دهند. اگر کافی نباشند، باقی از توکن پولی کسر می‌شود و تبلیغ همچنان نمایش داده می‌شود. اعتبار فایل پولی، کارهای فقط با توکن پولی و اشتراک‌های فعال فوراً و بدون تبلیغ شروع می‌شوند.',
    'file_rights_unit': 'فایل',
    'start_cost_one_file_right': 'فایل',
    'wallet_paid_token_label': 'توکن پولی',
    'history_menu_tokens': 'تاریخچه ترجمه/توکن',
    'credit_history_title_tokens': 'تاریخچه توکن',
    'credit_history_add_tokens': 'توکن اضافه شد',
    'credit_history_spend_tokens': 'توکن مصرف شد',
    'credit_history_subscription_forfeit_tokens': 'توکن‌های استفاده‌نشده اشتراک صفر شد',
    'add_tokens': 'افزودن توکن',
    'credit_explanation_tokens':
        'مصرف توکن به طول فایل بستگی دارد. اعتبارهای پرداخت‌شده باقی‌مانده هنوز ۱ فایل = ۱ اعتبار است.',
    'token_estimate_title': 'برآورد مصرف توکن',
    'token_estimate_body':
        'این فایل حدود {tokens} توکن مصرف می‌کند. باقی‌مانده پس از آن: {remaining}.',
    'token_estimate_cancel': 'لغو',
    'token_estimate_confirm': 'شروع',
    'token_insufficient_title': 'توکن کافی نیست',
    'token_insufficient_body':
        'این فایل به {needed} توکن نیاز دارد. شما {balance} دارید.',
    'token_insufficient_shop': 'افزودن توکن',
    'credit_policy_live_title': 'صورتحساب اکنون با توکن است',
    'credit_policy_live_intro':
        'از ۱ سپتامبر ۲۰۲۶ ترجمه‌های جدید با توکن محاسبه می‌شوند. فایل بلند هزینه بیشتر و کوتاه کمتر دارد. قبل از شروع برآورد می‌بینید.',
    'credit_policy_live_rule_1':
        'اعتبار فایل پرداخت‌شده‌ای که دارید تا تمام شدن ۱ فایل = ۱ اعتبار می‌ماند.',
    'credit_policy_live_rule_2':
        'شارژهای جدید بسته‌های ۱ / ۵ / ۱۰ میلیون توکن هستند. اعتبار باقی‌مانده و موجودی توکن با هم دیده می‌شود.',
    'credit_policy_live_rule_3':
        'هر کار یا اعتبار فایل باقی‌مانده یا توکن مصرف می‌کند — نه هر دو با هم.',
    'credit_policy_live_ads':
        'تبلیغ پاداش‌دار ادامه دارد: ۵ تبلیغ = ۷۵٬۰۰۰ توکن. سقف روزانه و هفتگی همان است.',
    'credit_policy_live_ok': 'باشه',
    'token_pack_coverage':
        'حدود {movies} فیلم یا {episodes} قسمت سریال',

  },
  'TH': {
    'wallet_token_label': 'โทเค็น',
    'wallet_bonus_token_label': 'โทเค็นโบนัส',
    'credit_explanation_tokens_paid': 'เครดิตที่ซื้อไว้แล้วยังใช้แบบ 1 ไฟล์ = 1 เครดิต เครดิตโบนัสที่เหลือจะแปลงเป็นโทเค็น',
    'credit_explanation_tokens_expiry': 'โทเค็นโบนัสใช้ได้ 1 เดือน สะสมและใช้ระหว่างนี้ได้ ครบ 1 เดือนแล้วโทเค็นโบนัสที่เหลือจะถูกลบออกจากบัญชีของคุณ',
    'bonus_token_expiry_title': 'โทเค็นโบนัสหมดอายุ',
    'ad_reward_tile_title_tokens': 'ดูโฆษณา รับโทเค็น',
    'ad_reward_tile_desc_tokens': 'โฆษณาแต่ละครั้งได้ 5,000 โทเค็น',
    'ad_reward_limit_desc_tokens': 'วันละไม่เกิน 10 ครั้ง สัปดาห์ละ 40 ครั้ง โทเค็นโบนัสใช้ได้ 1 เดือน สะสมและใช้ระหว่างนี้ได้ ครบ 1 เดือนแล้วโทเค็นโบนัสที่เหลือจะถูกลบออกจากบัญชีของคุณ',
    'ad_reward_each_ad_hint': 'โฆษณาแต่ละครั้งเพิ่ม {tokens} โทเค็น',
    'token_mix_paid_title': 'โทเค็นโบนัสไม่พอ',
    'token_mix_paid_body': 'ไฟล์นี้ต้องการประมาณ {needed} โทเค็น: {bonus} จากโบนัส {paid} จากที่ซื้อ',
    'token_mix_paid_confirm': 'ดำเนินการต่อ',
    'referral_cta_tokens': 'แนะนำและ\nรับโทเค็น',
    'referral_dialog_desc_tokens': 'แชร์รหัสกับเพื่อน เมื่อเขาเข้าแอปแล้วใช้รหัส ทั้งคู่จะได้ 150,000 โทเค็น',
    'referral_claim_success_tokens': 'เพิ่มโบนัสชวนเพื่อนแล้ว ได้รับ 150,000 โทเค็น',
    'referral_share_message_tokens':
        'สมัคร AI SRT Subtitle Translator & Editor ด้วยรหัสของฉัน: {code} พอใช้รหัส ทั้งคู่ได้ 150,000 โทเค็น',
    'tutorial_referral_desc_tokens':
        'ปุ่มนี้เปิดศูนย์ชวนเพื่อน ชวนเพื่อนแล้วทั้งคู่ได้ 150,000 โทเค็น ต้องเข้าสู่ระบบด้วย Google',
    'credit_source_referral': 'รางวัลชวนเพื่อน',
    'ad_reward_token_cta': 'ดูโฆษณา\nรับโทเค็น',
    'prefer_free_tokens_first': 'ใช้โทเค็นโบนัสก่อน',
    'subscription_monthly_note_tokens': 'ต่ออายุรายเดือน โทเค็นที่ไม่ได้ใช้ไม่ยกยอด',
    'ad_gate_desc_tokens': 'โทเค็นโบนัสจะแสดงโฆษณารางวัลก่อนประมวลผล หากไม่พอ ส่วนที่เหลือจะหักจากโทเค็นที่ซื้อ และโฆษณายังคงแสดง เครดิตไฟล์ที่ชำระแล้ว งานที่ใช้เฉพาะโทเค็นที่ซื้อ และการสมัครที่ใช้งานอยู่เริ่มทันทีโดยไม่มีโฆษณา',
    'file_rights_unit': 'ไฟล์',
    'start_cost_one_file_right': 'ไฟล์',
    'wallet_paid_token_label': 'โทเค็นที่ชำระ',
    'history_menu_tokens': 'ประวัติแปล/โทเค็น',
    'credit_history_title_tokens': 'ประวัติโทเค็น',
    'credit_history_add_tokens': 'เพิ่มโทเค็นแล้ว',
    'credit_history_spend_tokens': 'ใช้โทเค็นแล้ว',
    'credit_history_subscription_forfeit_tokens': 'รีเซ็ตโทเค็นสมาชิกรายเดือนที่ยังไม่ใช้',
    'add_tokens': 'เพิ่มโทเค็น',
    'credit_explanation_tokens':
        'โทเค็นคิดตามความยาวไฟล์ เครดิตที่ซื้อไว้แล้วยังใช้แบบ 1 ไฟล์ = 1 เครดิต',
    'token_estimate_title': 'ประมาณการใช้โทเค็น',
    'token_estimate_body':
        'ไฟล์นี้จะใช้ประมาณ {tokens} โทเค็น เหลือหลังจากนั้น: {remaining}',
    'token_estimate_cancel': 'ยกเลิก',
    'token_estimate_confirm': 'เริ่ม',
    'token_insufficient_title': 'โทเค็นไม่พอ',
    'token_insufficient_body':
        'ไฟล์นี้ต้องการ {needed} โทเค็น คุณมี {balance}',
    'token_insufficient_shop': 'เพิ่มโทเค็น',
    'credit_policy_live_title': 'คิดเงินด้วยโทเค็นแล้ว',
    'credit_policy_live_intro':
        'ตั้งแต่วันที่ 1 กันยายน 2026 การแปลใหม่คิดเป็นโทเค็น ไฟล์ยาวแพงกว่า ไฟล์สั้นถูกกว่า คุณจะเห็นประมาณการก่อนเริ่ม',
    'credit_policy_live_rule_1':
        'เครดิตไฟล์ที่ซื้อไว้แล้วยังใช้ได้แบบ 1 ไฟล์ = 1 เครดิตจนกว่าจะหมด',
    'credit_policy_live_rule_2':
        'การเติมใหม่เป็นแพ็ก 1 / 5 / 10 ล้านโทเค็น เครดิตคงเหลือและยอดโทเค็นแสดงด้วยกัน',
    'credit_policy_live_rule_3':
        'หนึ่งงานใช้เครดิตไฟล์ที่เหลือหรือโทเค็นอย่างใดอย่างหนึ่ง ไม่ผสมกัน',
    'credit_policy_live_ads':
        'โฆษณารางวัลยังมี: 5 โฆษณา = 75,000 โทเค็น เพดานรายวันและรายสัปดาห์เท่าเดิม',
    'credit_policy_live_ok': 'ตกลง',
    'token_pack_coverage':
        'ประมาณ {movies} เรื่องภาพยนตร์ หรือ {episodes} ตอนซีรีส์',

  },
  'VI': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Token thưởng',
    'credit_explanation_tokens_paid': 'Tín dụng trả phí còn lại vẫn là 1 tệp = 1 tín dụng. Tín dụng thưởng còn lại được chuyển thành token.',
    'credit_explanation_tokens_expiry': 'Token thưởng có hiệu lực trong 1 tháng. Bạn có thể tích lũy và dùng trong thời gian đó; sau 1 tháng, token thưởng còn lại sẽ bị xóa khỏi tài khoản.',
    'bonus_token_expiry_title': 'Token thưởng hết hạn',
    'ad_reward_tile_title_tokens': 'Xem quảng cáo, nhận token',
    'ad_reward_tile_desc_tokens': 'Mỗi quảng cáo cho 5.000 token.',
    'ad_reward_limit_desc_tokens': 'Tối đa 10 quảng cáo mỗi ngày và 40 mỗi tuần. Token thưởng có hiệu lực trong 1 tháng. Bạn có thể tích lũy và dùng trong thời gian đó; sau 1 tháng, token thưởng còn lại sẽ bị xóa khỏi tài khoản.',
    'ad_reward_each_ad_hint': 'Mỗi quảng cáo cộng {tokens} token.',
    'token_mix_paid_title': 'Token thưởng không đủ',
    'token_mix_paid_body': 'Tệp này cần khoảng {needed} token: {bonus} từ token thưởng, {paid} từ token trả phí.',
    'token_mix_paid_confirm': 'Tiếp tục',
    'referral_cta_tokens': 'Giới thiệu và\nNhận token',
    'referral_dialog_desc_tokens': 'Chia sẻ mã với bạn. Khi họ vào ứng dụng và dùng mã, cả hai đều nhận 150.000 token.',
    'referral_claim_success_tokens': 'Đã cộng thưởng giới thiệu. 150.000 token đã vào tài khoản.',
    'referral_share_message_tokens':
        'Tham gia AI SRT Subtitle Translator & Editor với mã của tôi: {code}. Khi dùng mã, cả hai nhận 150.000 token.',
    'tutorial_referral_desc_tokens':
        'Nút này mở trung tâm giới thiệu. Mời bạn bè, cả hai có thể nhận 150.000 token. Cần đăng nhập Google.',
    'credit_source_referral': 'Thưởng giới thiệu',
    'ad_reward_token_cta': 'Xem quảng cáo\nNhận token',
    'prefer_free_tokens_first': 'Ưu tiên dùng token thưởng',
    'subscription_monthly_note_tokens': 'Gia hạn hàng tháng. Token không dùng không cộng dồn.',
    'ad_gate_desc_tokens': 'Token thưởng hiển thị quảng cáo có thưởng trước khi xử lý. Nếu không đủ, phần còn lại lấy từ token trả phí và quảng cáo vẫn hiển thị. Tín dụng tệp trả phí, tác vụ chỉ dùng token trả phí và gói đăng ký đang hoạt động bắt đầu ngay không có quảng cáo.',
    'file_rights_unit': 'TỆP',
    'start_cost_one_file_right': 'tệp',
    'wallet_paid_token_label': 'Token trả phí',
    'history_menu_tokens': 'Lịch sử dịch/token',
    'credit_history_title_tokens': 'Lịch sử token',
    'credit_history_add_tokens': 'Đã cộng token',
    'credit_history_spend_tokens': 'Đã trừ token',
    'credit_history_subscription_forfeit_tokens': 'Token gói tháng chưa dùng đã được đặt lại',
    'add_tokens': 'Thêm token',
    'credit_explanation_tokens':
        'Token tính theo độ dài tệp. Tín dụng trả phí còn lại vẫn là 1 tệp = 1 tín dụng.',
    'token_estimate_title': 'Ước tính dùng token',
    'token_estimate_body':
        'Tệp này sẽ dùng khoảng {tokens} token. Còn lại sau đó: {remaining}.',
    'token_estimate_cancel': 'Hủy',
    'token_estimate_confirm': 'Bắt đầu',
    'token_insufficient_title': 'Không đủ token',
    'token_insufficient_body':
        'Tệp này cần {needed} token. Bạn có {balance}.',
    'token_insufficient_shop': 'Thêm token',
    'credit_policy_live_title': 'Thanh toán hiện dùng token',
    'credit_policy_live_intro':
        'Từ 1 tháng 9 năm 2026 bản dịch mới tính bằng token. Tệp dài tốn hơn, tệp ngắn tốn ít hơn. Bạn thấy ước tính trước khi bắt đầu.',
    'credit_policy_live_rule_1':
        'Tín dụng tệp đã mua vẫn là 1 tệp = 1 tín dụng cho đến khi hết.',
    'credit_policy_live_rule_2':
        'Nạp mới là gói 1 / 5 / 10 triệu token. Tín dụng còn lại và số dư token hiện cùng nhau.',
    'credit_policy_live_rule_3':
        'Một việc dùng tín dụng tệp còn lại hoặc token — không trộn hai loại.',
    'credit_policy_live_ads':
        'Quảng cáo thưởng vẫn: 5 quảng cáo = 75.000 token. Hạn ngày và tuần giữ nguyên.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Khoảng {movies} phim hoặc {episodes} tập phim bộ',

  },
  'TA': {
    'wallet_token_label': 'டோக்கன்',
    'wallet_bonus_token_label': 'போனஸ் டோக்கன்',
    'credit_explanation_tokens_paid': 'மீதமுள்ள கட்டண கிரெடிட்கள் இன்னும் 1 கோப்பு = 1 கிரெடிட். மீதமுள்ள போனஸ் கிரெடிட்கள் டோக்கனாக மாறும்.',
    'credit_explanation_tokens_expiry': 'போனஸ் டோக்கன் 1 மாதம் வரை செல்லும். இந்த காலத்தில் சேர்த்து பயன்படுத்தலாம்; 1 மாதம் முடிந்ததும் மீதமுள்ள போனஸ் டோக்கன் உங்கள் கணக்கிலிருந்து நீக்கப்படும்.',
    'bonus_token_expiry_title': 'போனஸ் டோக்கன் காலாவதியாகும்',
    'ad_reward_tile_title_tokens': 'விளம்பரம் பார்த்து டோக்கன் பெறுங்கள்',
    'ad_reward_tile_desc_tokens': 'ஒவ்வொரு விளம்பரமும் 5,000 டோக்கன் தரும்.',
    'ad_reward_limit_desc_tokens': 'ஒரு நாளில் அதிகபட்சம் 10, வாரத்தில் 40 விளம்பரம். போனஸ் டோக்கன் 1 மாதம் வரை செல்லும். இந்த காலத்தில் சேர்த்து பயன்படுத்தலாம்; 1 மாதம் முடிந்ததும் மீதமுள்ள போனஸ் டோக்கன் உங்கள் கணக்கிலிருந்து நீக்கப்படும்.',
    'ad_reward_each_ad_hint': 'ஒவ்வொரு விளம்பரமும் {tokens} டோக்கன் சேர்க்கும்.',
    'token_mix_paid_title': 'போனஸ் டோக்கன் போதாது',
    'token_mix_paid_body': 'இந்த கோப்புக்கு சுமார் {needed} டோக்கன் தேவை: {bonus} போனஸிலிருந்து, {paid} கட்டணத்திலிருந்து.',
    'token_mix_paid_confirm': 'தொடரவும்',
    'referral_cta_tokens': 'பரிந்துரைத்து\nடோக்கன் பெறுங்கள்',
    'referral_dialog_desc_tokens':
        'உங்கள் குறியீட்டை நண்பருடன் பகிரவும். அவர்கள் செயலியில் சேர்ந்து குறியீட்டைப் பயன்படுத்தினால், இருவருக்கும் 150,000 டோக்கன் கிடைக்கும்.',
    'referral_claim_success_tokens': 'பரிந்துரை போனஸ் சேர்க்கப்பட்டது. 150,000 டோக்கன் வழங்கப்பட்டன.',
    'referral_share_message_tokens':
        'என் பரிந்துரைக் குறியீட்டோடு AI SRT Subtitle Translator & Editor-இல் சேருங்கள்: {code}. பயன்படுத்தினால் நாம் இருவரும் 150,000 டோக்கன் பெறுவோம்.',
    'tutorial_referral_desc_tokens':
        'இந்த பொத்தான் பரிந்துரை மையத்தைத் திறக்கும். நண்பர்களை அழைத்தால் இருவருக்கும் 150,000 டோக்கன் கிடைக்கும். Google உள்நுழைவு தேவை.',
    'credit_source_referral': 'பரிந்துரை வெகுமதி',
    'ad_reward_token_cta': 'விளம்பரம் பாருங்கள்\nடோக்கன் பெறுங்கள்',
    'prefer_free_tokens_first': 'முதலில் போனஸ் டோக்கன்களை பயன்படுத்து',
    'subscription_monthly_note_tokens': 'மாதாந்திரம் புதுப்பிக்கப்படும். பயன்படுத்தாத டோக்கன்கள் அடுத்த மாதத்திற்கு மாற்றப்படாது.',
    'ad_gate_desc_tokens': 'போனஸ் டோக்கன்கள் செயலாக்கத்திற்கு முன் வெகுமதி விளம்பரம் காட்டும். போதாவிட்டால், மீதி கட்டண டோக்கன்களிலிருந்து கழிக்கப்படும்; விளம்பரம் தொடரும். கட்டண கோப்பு கிரெடிட்கள், கட்டண டோக்கன் மட்டும் பணிகள் மற்றும் செயலில் உள்ள சந்தாக்கள் விளம்பரமின்றி உடனே தொடங்கும்.',
    'file_rights_unit': 'கோப்பு',
    'start_cost_one_file_right': 'கோப்பு',
    'wallet_paid_token_label': 'கட்டண டோக்கன்',
    'history_menu_tokens': 'மொழிபெயர்ப்பு/டோக்கன் வரலாறு',
    'credit_history_title_tokens': 'டோக்கன் வரலாறு',
    'credit_history_add_tokens': 'டோக்கன் சேர்க்கப்பட்டது',
    'credit_history_spend_tokens': 'டோக்கன் பயன்படுத்தப்பட்டது',
    'credit_history_subscription_forfeit_tokens': 'பயன்படுத்தாத சந்தா டோக்கன்கள் மீட்டமைக்கப்பட்டன',
    'add_tokens': 'டோக்கன் சேர்',
    'credit_explanation_tokens':
        'டோக்கன் கோப்பு நீளத்தைப் பொறுத்தது. மீதமுள்ள கட்டண கிரெடிட்கள் இன்னும் 1 கோப்பு = 1 கிரெடிட்.',
    'token_estimate_title': 'மதிப்பிடப்பட்ட டோக்கன் பயன்பாடு',
    'token_estimate_body':
        'இந்தக் கோப்பு சுமார் {tokens} டோக்கன் பயன்படுத்தும். பிறகு மீதம்: {remaining}.',
    'token_estimate_cancel': 'ரத்து',
    'token_estimate_confirm': 'தொடங்கு',
    'token_insufficient_title': 'போதிய டோக்கன் இல்லை',
    'token_insufficient_body':
        'இந்தக் கோப்புக்கு {needed} டோக்கன் தேவை. உங்களிடம் {balance} உள்ளது.',
    'token_insufficient_shop': 'டோக்கன் சேர்',
    'credit_policy_live_title': 'கட்டணம் இப்போது டோக்கனில்',
    'credit_policy_live_intro':
        '1 செப்டம்பர் 2026 முதல் புதிய மொழிபெயர்ப்புகள் டோக்கனில் வசூலிக்கப்படும். நீண்ட கோப்பு அதிகம், குறுகியது குறைவு. தொடங்கும் முன் மதிப்பீடு காணும்.',
    'credit_policy_live_rule_1':
        'ஏற்கனவே வாங்கிய கோப்பு கிரெடிட்கள் முடியும் வரை 1 கோப்பு = 1 கிரெடிட்.',
    'credit_policy_live_rule_2':
        'புதிய டாப்-அப்கள் 1 / 5 / 10 மில்லியன் டோக்கன் தொகுப்புகள். மீத கிரெடிட் மற்றும் டோக்கன் இருப்பு ஒன்றாகக் காட்டப்படும்.',
    'credit_policy_live_rule_3':
        'ஒரு பணி மீத கோப்பு கிரெடிட் அல்லது டோக்கனை மட்டும் பயன்படுத்தும் — இரண்டையும் கலக்காது.',
    'credit_policy_live_ads':
        'வெகுமதி விளம்பரங்கள் தொடரும்: 5 விளம்பரம் = 75,000 டோக்கன். தினசரி மற்றும் வாராந்திர வரம்புகள் அதே.',
    'credit_policy_live_ok': 'சரி',
    'token_pack_coverage':
        'சுமார் {movies} திரைப்படங்கள் அல்லது {episodes} அத்தியாயங்கள்',

  },
  'TE': {
    'wallet_token_label': 'టోకెన్లు',
    'wallet_bonus_token_label': 'బోనస్ టోకెన్లు',
    'credit_explanation_tokens_paid': 'మిగిలిన చెల్లింపు క్రెడిట్లు ఇంకా 1 ఫైల్ = 1 క్రెడిట్. మిగిలిన బోనస్ క్రెడిట్లు టోకెన్లుగా మారతాయి.',
    'credit_explanation_tokens_expiry': 'బోనస్ టోకెన్లు 1 నెల పాటు చెల్లుబాటు అవుతాయి. ఈ కాలంలో వాటిని కూడబెట్టి వాడొచ్చు; 1 నెల తర్వాత మిగిలిన బోనస్ టోకెన్లు మీ ఖాతా నుండి తొలగించబడతాయి.',
    'bonus_token_expiry_title': 'బోనస్ టోకెన్లు గడువు ముగుస్తాయి',
    'ad_reward_tile_title_tokens': 'ప్రకటన చూసి టోకెన్లు పొందండి',
    'ad_reward_tile_desc_tokens': 'ప్రతి ప్రకటన 5,000 టోకెన్లు ఇస్తుంది.',
    'ad_reward_limit_desc_tokens': 'రోజుకు గరిష్టం 10, వారానికి 40 ప్రకటనలు. బోనస్ టోకెన్లు 1 నెల పాటు చెల్లుబాటు అవుతాయి. ఈ కాలంలో వాటిని కూడబెట్టి వాడొచ్చు; 1 నెల తర్వాత మిగిలిన బోనస్ టోకెన్లు మీ ఖాతా నుండి తొలగించబడతాయి.',
    'ad_reward_each_ad_hint': 'ప్రతి ప్రకటన {tokens} టోకెన్లు జోడిస్తుంది.',
    'token_mix_paid_title': 'బోనస్ టోకెన్లు సరిపోవు లేదు',
    'token_mix_paid_body': 'ఈ ఫైల్‌కు సుమారు {needed} టోకెన్లు కావాలి: {bonus} బోనస్ నుండి, {paid} చెల్లింపు నుండి.',
    'token_mix_paid_confirm': 'కొనసాగించు',
    'referral_cta_tokens': 'రెఫర్ చేసి\nటోకెన్లు సంపాదించండి',
    'referral_dialog_desc_tokens':
        'మీ కోడ్‌ను స్నేహితుడితో పంచుకోండి. వారు యాప్‌లో చేరి కోడ్ వాడితే మీ ఇద్దరికీ 150,000 టోకెన్లు వస్తాయి.',
    'referral_claim_success_tokens': 'రిఫరల్ బోనస్ జోడించబడింది. 150,000 టోకెన్లు జమ అయ్యాయి.',
    'referral_share_message_tokens':
        'నా రిఫరల్ కోడ్‌తో AI SRT Subtitle Translator & Editorలో చేరండి: {code}. వాడినప్పుడు మేమిద్దరం 150,000 టోకెన్లు పొందుతాం.',
    'tutorial_referral_desc_tokens':
        'ఈ బటన్ రిఫరల్ కేంద్రాన్ని తెరుస్తుంది. స్నేహితులను ఆహ్వానిస్తే మీ ఇద్దరూ 150,000 టోకెన్లు పొందవచ్చు. Google సైన్-ఇన్ అవసరం.',
    'credit_source_referral': 'రిఫరల్ బహుమతి',
    'ad_reward_token_cta': 'ప్రకటన చూడండి\nటోకెన్లు సంపాదించండి',
    'prefer_free_tokens_first': 'ముందుగా బోనస్ టోకెన్లు ఉపయోగించండి',
    'subscription_monthly_note_tokens': 'నెలవారీగా పునరుద్ధరించబడుతుంది. ఉపయోగించని టోకెన్లు ముందుకు మారవు.',
    'ad_gate_desc_tokens': 'బోనస్ టోకెన్లు ప్రాసెస్ చేయడానికి ముందు రివార్డ్ ప్రకటన చూపుతాయి. సరిపోకపోతే, మిగిలినవి చెల్లింపు టోకెన్ల నుండి తీసుకుంటారు; ప్రకటన మళ్లీ చూపబడుతుంది. చెల్లింపు ఫైల్ క్రెడిట్లు, చెల్లింపు టోకెన్‌తో మాత్రమే చేసే పనులు మరియు సక్రియ సబ్‌స్క్రిప్షన్‌లు ప్రకటనలు లేకుండా వెంటనే ప్రారంభమవుతాయి.',
    'file_rights_unit': 'ఫైల్',
    'start_cost_one_file_right': 'ఫైల్',
    'wallet_paid_token_label': 'చెల్లింపు టోకెన్లు',
    'history_menu_tokens': 'అనువాద/టోకెన్ చరిత్ర',
    'credit_history_title_tokens': 'టోకెన్ చరిత్ర',
    'credit_history_add_tokens': 'టోకెన్లు జోడించబడ్డాయి',
    'credit_history_spend_tokens': 'టోకెన్లు వినియోగించబడ్డాయి',
    'credit_history_subscription_forfeit_tokens': 'వాడని సబ్‌స్క్రిప్షన్ టోకెన్లు రీసెట్ అయ్యాయి',
    'add_tokens': 'టోకెన్లు జోడించు',
    'credit_explanation_tokens':
        'టోకెన్లు ఫైల్ పొడవును బట్టి ఖర్చవుతాయి. మిగిలిన చెల్లింపు క్రెడిట్లు ఇంకా 1 ఫైల్ = 1 క్రెడిట్.',
    'token_estimate_title': 'అంచనా టోకెన్ వాడకం',
    'token_estimate_body':
        'ఈ ఫైల్ సుమారు {tokens} టోకెన్లు వాడుతుంది. తర్వాత మిగిలేది: {remaining}.',
    'token_estimate_cancel': 'రద్దు',
    'token_estimate_confirm': 'ప్రారంభించు',
    'token_insufficient_title': 'టోకెన్లు సరిపోవు',
    'token_insufficient_body':
        'ఈ ఫైల్‌కు {needed} టోకెన్లు కావాలి. మీ దగ్గర {balance} ఉన్నాయి.',
    'token_insufficient_shop': 'టోకెన్లు జోడించు',
    'credit_policy_live_title': 'బిల్లింగ్ ఇప్పుడు టోకెన్లతో',
    'credit_policy_live_intro':
        '1 సెప్టెంబర్ 2026 నుండి కొత్త అనువాదాలు టోకెన్లతో ఛార్జ్ అవుతాయి. పొడవైన ఫైల్ ఎక్కువ, చిన్నది తక్కువ. ప్రారంభానికి ముందు అంచనా కనిపిస్తుంది.',
    'credit_policy_live_rule_1':
        'మీ వద్ద ఉన్న చెల్లింపు ఫైల్ క్రెడిట్లు అయిపోయే వరకు 1 ఫైల్ = 1 క్రెడిట్.',
    'credit_policy_live_rule_2':
        'కొత్త టాప్-అప్‌లు 1 / 5 / 10 మిలియన్ టోకెన్ ప్యాక్‌లు. మిగిలిన క్రెడిట్లు మరియు టోకెన్ బ్యాలెన్స్ కలిసి కనిపిస్తాయి.',
    'credit_policy_live_rule_3':
        'ఒక జాబ్ మిగిలిన ఫైల్ క్రెడిట్లు లేదా టోకెన్లు మాత్రమే వాడుతుంది — రెండూ కలవవు.',
    'credit_policy_live_ads':
        'రివార్డ్ యాడ్స్ కొనసాగుతాయి: 5 యాడ్స్ = 75,000 టోకెన్లు. రోజువారీ మరియు వారపు పరిమితులు అవే.',
    'credit_policy_live_ok': 'సరే',
    'token_pack_coverage':
        'సుమారు {movies} సినిమాలు లేదా {episodes} ఎపిసోడ్లు',

  },
  'ML': {
    'wallet_token_label': 'ടോക്കൺ',
    'wallet_bonus_token_label': 'ബോണസ് ടോക്കൺ',
    'credit_explanation_tokens_paid': 'ബാക്കി പണമടച്ച ക്രെഡിറ്റുകൾ ഇപ്പോഴും 1 ഫയൽ = 1 ക്രെഡിറ്റ്. ബാക്കി ബോണസ് ക്രെഡിറ്റുകൾ ടോക്കണായി മാറും.',
    'credit_explanation_tokens_expiry': 'ബോണസ് ടോക്കൺ 1 മാസം വരെ സാധുവാണ്. ഈ കാലത്ത് ശേഖരിച്ച് ഉപയോഗിക്കാം; 1 മാസം കഴിഞ്ഞാൽ ബാക്കിയുള്ള ബോണസ് ടോക്കൺ നിങ്ങളുടെ അക്കൗണ്ടിൽ നിന്ന് നീക്കം ചെയ്യും.',
    'bonus_token_expiry_title': 'ബോണസ് ടോക്കൺ കാലഹരണപ്പെടും',
    'ad_reward_tile_title_tokens': 'പരസ്യം കണ്ട് ടോക്കൺ നേടുക',
    'ad_reward_tile_desc_tokens': 'ഓരോ പരസ്യവും 5,000 ടോക്കൺ തരും.',
    'ad_reward_limit_desc_tokens': 'ഒരു ദിവസം പരമാവധി 10, ആഴ്ചയിൽ 40 പരസ്യം. ബോണസ് ടോക്കൺ 1 മാസം വരെ സാധുവാണ്. ഈ കാലത്ത് ശേഖരിച്ച് ഉപയോഗിക്കാം; 1 മാസം കഴിഞ്ഞാൽ ബാക്കിയുള്ള ബോണസ് ടോക്കൺ നിങ്ങളുടെ അക്കൗണ്ടിൽ നിന്ന് നീക്കം ചെയ്യും.',
    'ad_reward_each_ad_hint': 'ഓരോ പരസ്യവും {tokens} ടോക്കൺ ചേർക്കും.',
    'token_mix_paid_title': 'ബോണസ് ടോക്കൺ മതിയല്ല',
    'token_mix_paid_body': 'ഈ ഫയലിന് ഏകദേശം {needed} ടോക്കൺ വേണം: {bonus} ബോണസിൽ നിന്ന്, {paid} പണമടച്ചതിൽ നിന്ന്.',
    'token_mix_paid_confirm': 'തുടരുക',
    'referral_cta_tokens': 'റഫർ ചെയ്ത്\nടോക്കൺ നേടുക',
    'referral_dialog_desc_tokens':
        'നിങ്ങളുടെ കോഡ് ഒരു സുഹൃത്തിനൊപ്പം പങ്കിടുക. അവർ ആപ്പിൽ ചേർന്ന് കോഡ് ഉപയോഗിക്കുമ്പോൾ ഇരുവർക്കും 150,000 ടോക്കൺ ലഭിക്കും.',
    'referral_claim_success_tokens': 'റഫറൽ ബോണസ് ചേർത്തു. 150,000 ടോക്കൺ നൽകി.',
    'referral_share_message_tokens':
        'എന്റെ റഫറൽ കോഡ് ഉപയോഗിച്ച് AI SRT Subtitle Translator & Editor-ലേക്ക് ചേരൂ: {code}. ഉപയോഗിക്കുമ്പോൾ ഞങ്ങൾ ഇരുവരും 150,000 ടോക്കൺ നേടും.',
    'tutorial_referral_desc_tokens':
        'ഈ ബട്ടൺ റഫറൽ സെന്റർ തുറക്കും. സുഹൃത്തുക്കളെ ക്ഷണിച്ചാൽ ഇരുവർക്കും 150,000 ടോക്കൺ ലഭിക്കും. Google സൈൻ-ഇൻ ആവശ്യമാണ്.',
    'credit_source_referral': 'റഫറൽ റിവാർഡ്',
    'ad_reward_token_cta': 'പരസ്യം കാണുക\nടോക്കൺ നേടുക',
    'prefer_free_tokens_first': 'ആദ്യം ബോണസ് ടോക്കൺ ഉപയോഗിക്കുക',
    'subscription_monthly_note_tokens': 'പ്രതിമാസം പുതുക്കുന്നു. ഉപയോഗിക്കാത്ത ടോക്കൺ മുന്നോട്ട് നീക്കില്ല.',
    'ad_gate_desc_tokens': 'ബോണസ് ടോക്കൺ പ്രോസസ്സ് ചെയ്യുന്നതിന് മുമ്പ് റിവാർഡ് പരസ്യം കാണിക്കും. മതിയാകില്ലെങ്കിൽ, ബാക്കി പണമടച്ച ടോക്കണിൽ നിന്ന് കുറയ്ക്കും; പരസ്യം തുടരും. പണമടച്ച ഫയൽ ക്രെഡിറ്റുകൾ, പണമടച്ച ടോക്കൺ മാത്രം ഉപയോഗിക്കുന്ന ജോലികൾ, സജീവ സബ്സ്ക്രിപ്ഷനുകൾ പരസ്യമില്ലാതെ ഉടൻ ആരംഭിക്കും.',
    'file_rights_unit': 'ഫയൽ',
    'start_cost_one_file_right': 'ഫയൽ',
    'wallet_paid_token_label': 'പണമടച്ച ടോക്കൺ',
    'history_menu_tokens': 'വിവർത്തന/ടോക്കൺ ചരിത്രം',
    'credit_history_title_tokens': 'ടോക്കൺ ചരിത്രം',
    'credit_history_add_tokens': 'ടോക്കൺ ചേർത്തു',
    'credit_history_spend_tokens': 'ടോക്കൺ ഉപയോഗിച്ചു',
    'credit_history_subscription_forfeit_tokens': 'ഉപയോഗിക്കാത്ത സബ്‌സ്‌ക്രിപ്ഷൻ ടോക്കണുകൾ റീസെറ്റ് ചെയ്തു',
    'add_tokens': 'ടോക്കൺ ചേർക്കുക',
    'credit_explanation_tokens':
        'ടോക്കൺ ഫയൽ നീളം അനുസരിച്ച് ചെലവാകും. ബാക്കി പണമടച്ച ക്രെഡിറ്റുകൾ ഇപ്പോഴും 1 ഫയൽ = 1 ക്രെഡിറ്റ്.',
    'token_estimate_title': 'കണക്കാക്കിയ ടോക്കൺ ഉപയോഗം',
    'token_estimate_body':
        'ഈ ഫയൽ ഏകദേശം {tokens} ടോക്കൺ ഉപയോഗിക്കും. ശേഷം ബാക്കി: {remaining}.',
    'token_estimate_cancel': 'റദ്ദാക്കുക',
    'token_estimate_confirm': 'ആരംഭിക്കുക',
    'token_insufficient_title': 'മതിയായ ടോക്കൺ ഇല്ല',
    'token_insufficient_body':
        'ഈ ഫയലിന് {needed} ടോക്കൺ വേണം. നിങ്ങളുടെ പക്കൽ {balance} ഉണ്ട്.',
    'token_insufficient_shop': 'ടോക്കൺ ചേർക്കുക',
    'credit_policy_live_title': 'ബില്ലിംഗ് ഇപ്പോൾ ടോക്കൺ ആണ്',
    'credit_policy_live_intro':
        '2026 സെപ്റ്റംബർ 1 മുതൽ പുതിയ വിവർത്തനങ്ങൾ ടോക്കണിൽ ഈടാക്കും. നീണ്ട ഫയൽ കൂടുതൽ, ചെറുത് കുറവ്. തുടങ്ങുന്നതിന് മുമ്പ് കണക്ക് കാണാം.',
    'credit_policy_live_rule_1':
        'നിങ്ങൾക്കുള്ള പണമടച്ച ഫയൽ ക്രെഡിറ്റുകൾ തീരുന്നത് വരെ 1 ഫയൽ = 1 ക്രെഡിറ്റ്.',
    'credit_policy_live_rule_2':
        'പുതിയ ടോപ്പ്-അപ്പുകൾ 1 / 5 / 10 ദശലക്ഷം ടോക്കൺ പായ്ക്കുകളാണ്. ബാക്കി ക്രെഡിറ്റും ടോക്കൺ ബാലൻസും ഒരുമിച്ച് കാണാം.',
    'credit_policy_live_rule_3':
        'ഒരു ജോലി ബാക്കി ഫയൽ ക്രെഡിറ്റോ ടോക്കണോ മാത്രം ഉപയോഗിക്കും — രണ്ടും കലരില്ല.',
    'credit_policy_live_ads':
        'റിവാർഡ് പരസ്യങ്ങൾ തുടരും: 5 പരസ്യം = 75,000 ടോക്കൺ. ദൈനംദിനവും ആഴ്ചയിലെയും പരിധി അതേപടി.',
    'credit_policy_live_ok': 'ശരി',
    'token_pack_coverage':
        'ഏകദേശം {movies} സിനിമകൾ അല്ലെങ്കിൽ {episodes} എപ്പിസോഡുകൾ',

  },
  'KN': {
    'wallet_token_label': 'ಟೋಕನ್',
    'wallet_bonus_token_label': 'ಬೋನಸ್ ಟೋಕನ್',
    'credit_explanation_tokens_paid': 'ಉಳಿದ ಪಾವತಿ ಕ್ರೆಡಿಟ್‌ಗಳು ಇನ್ನೂ 1 ಫೈಲ್ = 1 ಕ್ರೆಡಿಟ್. ಉಳಿದ ಬೋನಸ್ ಕ್ರೆಡಿಟ್‌ಗಳು ಟೋಕನ್‌ಗಳಾಗಿ ಪರಿವರ್ತನೆಯಾಗುತ್ತವೆ.',
    'credit_explanation_tokens_expiry': 'ಬೋನಸ್ ಟೋಕನ್ 1 ತಿಂಗಳವರೆಗೆ ಮಾನ್ಯವಾಗಿರುತ್ತದೆ. ಈ ಅವಧಿಯಲ್ಲಿ ಸಂಗ್ರಹಿಸಿ ಬಳಸಬಹುದು; 1 ತಿಂಗಳ ಬಳಿಕ ಉಳಿದ ಬೋನಸ್ ಟೋಕನ್ ನಿಮ್ಮ ಖಾತೆಯಿಂದ ತೆಗೆದುಹಾಕಲಾಗುತ್ತದೆ.',
    'bonus_token_expiry_title': 'ಬೋನಸ್ ಟೋಕನ್ ಅವಧಿ ಮುಗಿಯುತ್ತದೆ',
    'ad_reward_tile_title_tokens': 'ಜಾಹೀರಾತು ನೋಡಿ ಟೋಕನ್ ಪಡೆಯಿರಿ',
    'ad_reward_tile_desc_tokens': 'ಪ್ರತಿ ಜಾಹೀರಾತು 5,000 ಟೋಕನ್ ನೀಡುತ್ತದೆ.',
    'ad_reward_limit_desc_tokens': 'ದಿನಕ್ಕೆ ಗರಿಷ್ಠ 10, ವಾರಕ್ಕೆ 40 ಜಾಹೀರಾತು. ಬೋನಸ್ ಟೋಕನ್ 1 ತಿಂಗಳವರೆಗೆ ಮಾನ್ಯವಾಗಿರುತ್ತದೆ. ಈ ಅವಧಿಯಲ್ಲಿ ಸಂಗ್ರಹಿಸಿ ಬಳಸಬಹುದು; 1 ತಿಂಗಳ ಬಳಿಕ ಉಳಿದ ಬೋನಸ್ ಟೋಕನ್ ನಿಮ್ಮ ಖಾತೆಯಿಂದ ತೆಗೆದುಹಾಕಲಾಗುತ್ತದೆ.',
    'ad_reward_each_ad_hint': 'ಪ್ರತಿ ಜಾಹೀರಾತು {tokens} ಟೋಕನ್ ಸೇರಿಸುತ್ತದೆ.',
    'token_mix_paid_title': 'ಬೋನಸ್ ಟೋಕನ್ ಸಾಕಾಗಿಲ್ಲ',
    'token_mix_paid_body': 'ಈ ಫೈಲ್‌ಗೆ ಸುಮಾರು {needed} ಟೋಕನ್ ಬೇಕು: {bonus} ಬೋನಸ್‌ನಿಂದ, {paid} ಪಾವತಿಸಿದದ್ದರಿಂದ.',
    'token_mix_paid_confirm': 'ಮುಂದುವರಿಸಿ',
    'referral_cta_tokens': 'ರೆಫರ್ ಮಾಡಿ\nಟೋಕನ್ ಗಳಿಸಿ',
    'referral_dialog_desc_tokens':
        'ನಿಮ್ಮ ಕೋಡ್ ಅನ್ನು ಸ್ನೇಹಿತರೊಂದಿಗೆ ಹಂಚಿಕೊಳ್ಳಿ. ಅವರು ಆ್ಯಪ್‌ಗೆ ಸೇರಿ ಕೋಡ್ ಬಳಸಿದಾಗ ನೀವಿಬ್ಬರೂ 150,000 ಟೋಕನ್ ಪಡೆಯುತ್ತೀರಿ.',
    'referral_claim_success_tokens': 'ರೆಫರಲ್ ಬೋನಸ್ ಸೇರಿಸಲಾಗಿದೆ. 150,000 ಟೋಕನ್ ಜಮಾ ಆಗಿದೆ.',
    'referral_share_message_tokens':
        'ನನ್ನ ರೆಫರಲ್ ಕೋಡ್‌ನೊಂದಿಗೆ AI SRT Subtitle Translator & Editorಗೆ ಸೇರಿ: {code}. ಬಳಸಿದಾಗ ನಾವಿಬ್ಬರೂ 150,000 ಟೋಕನ್ ಪಡೆಯುತ್ತೇವೆ.',
    'tutorial_referral_desc_tokens':
        'ಈ ಬಟನ್ ರೆಫರಲ್ ಕೇಂದ್ರವನ್ನು ತೆರೆಯುತ್ತದೆ. ಸ್ನೇಹಿತರನ್ನು ಆಹ್ವಾನಿಸಿ, ನೀವಿಬ್ಬರೂ 150,000 ಟೋಕನ್ ಗಳಿಸಬಹುದು. Google ಸೈನ್-ಇನ್ ಅಗತ್ಯ.',
    'credit_source_referral': 'ರೆಫರಲ್ ಬಹುಮಾನ',
    'ad_reward_token_cta': 'ಜಾಹೀರಾತು ನೋಡಿ\nಟೋಕನ್ ಗಳಿಸಿ',
    'prefer_free_tokens_first': 'ಮೊದಲು ಬೋನಸ್ ಟೋಕನ್ ಬಳಸಿ',
    'subscription_monthly_note_tokens': 'ಮಾಸಿಕವಾಗಿ ನವೀಕರಿಸಲಾಗುತ್ತದೆ. ಬಳಸದ ಟೋಕನ್ ಮುಂದಕ್ಕೆ ಸಾಗುವುದಿಲ್ಲ.',
    'ad_gate_desc_tokens': 'ಬೋನಸ್ ಟೋಕನ್‌ಗಳು ಪ್ರಕ್ರಿಯೆಗೊಳ್ಳುವ ಮೊದಲು ರಿವಾರ್ಡ್ ಜಾಹೀರಾತು ತೋರಿಸುತ್ತವೆ. ಸಾಕಾಗದಿದ್ದರೆ, ಉಳಿದದನ್ನು ಪಾವತಿಸಿದ ಟೋಕನ್‌ನಿಂದ ಕಡಿತಗೊಳಿಸಲಾಗುತ್ತದೆ; ಜಾಹೀರಾತು ಮತ್ತೆ ತೋರಿಸಲಾಗುತ್ತದೆ. ಪಾವತಿ ಫೈಲ್ ಕ್ರೆಡಿಟ್‌ಗಳು, ಪಾವತಿಸಿದ ಟೋಕನ್‌ಗಳಿಂದ ಮಾತ್ರದ ಕೆಲಸಗಳು ಮತ್ತು ಸಕ್ರಿಯ ಚಂದಾದಾರಿಕೆಗಳು ಜಾಹೀರಾತುಗಳಿಲ್ಲದೆ ತಕ್ಷಣ ಪ್ರಾರಂಭವಾಗುತ್ತವೆ.',
    'file_rights_unit': 'ಫೈಲ್',
    'start_cost_one_file_right': 'ಫೈಲ್',
    'wallet_paid_token_label': 'ಪಾವತಿಸಿದ ಟೋಕನ್',
    'history_menu_tokens': 'ಅನುವಾದ/ಟೋಕನ್ ಇತಿಹಾಸ',
    'credit_history_title_tokens': 'ಟೋಕನ್ ಇತಿಹಾಸ',
    'credit_history_add_tokens': 'ಟೋಕನ್ ಸೇರಿಸಲಾಗಿದೆ',
    'credit_history_spend_tokens': 'ಟೋಕನ್ ಖರ್ಚಾಯಿತು',
    'credit_history_subscription_forfeit_tokens': 'ಬಳಸದ ಚಂದಾದಾರಿಕೆ ಟೋಕನ್‌ಗಳನ್ನು ಮರುಹೊಂದಿಸಲಾಗಿದೆ',
    'add_tokens': 'ಟೋಕನ್ ಸೇರಿಸಿ',
    'credit_explanation_tokens':
        'ಟೋಕನ್ ಫೈಲ್ ಉದ್ದಕ್ಕೆ ಅನುಗುಣವಾಗಿ ಖರ್ಚಾಗುತ್ತದೆ. ಉಳಿದ ಪಾವತಿ ಕ್ರೆಡಿಟ್‌ಗಳು ಇನ್ನೂ 1 ಫೈಲ್ = 1 ಕ್ರೆಡಿಟ್.',
    'token_estimate_title': 'ಅಂದಾಜು ಟೋಕನ್ ಬಳಕೆ',
    'token_estimate_body':
        'ಈ ಫೈಲ್ ಸುಮಾರು {tokens} ಟೋಕನ್ ಬಳಸುತ್ತದೆ. ನಂತರ ಉಳಿಯುವುದು: {remaining}.',
    'token_estimate_cancel': 'ರದ್ದು',
    'token_estimate_confirm': 'ಪ್ರಾರಂಭಿಸಿ',
    'token_insufficient_title': 'ಸಾಕಷ್ಟು ಟೋಕನ್ ಇಲ್ಲ',
    'token_insufficient_body':
        'ಈ ಫೈಲಿಗೆ {needed} ಟೋಕನ್ ಬೇಕು. ನಿಮ್ಮ ಬಳಿ {balance} ಇದೆ.',
    'token_insufficient_shop': 'ಟೋಕನ್ ಸೇರಿಸಿ',
    'credit_policy_live_title': 'ಬಿಲ್ಲಿಂಗ್ ಈಗ ಟೋಕನ್‌ನಲ್ಲಿ',
    'credit_policy_live_intro':
        '1 ಸೆಪ್ಟೆಂಬರ್ 2026 ರಿಂದ ಹೊಸ ಅನುವಾದಗಳು ಟೋಕನ್‌ನಲ್ಲಿ ಶುಲ್ಕ. ಉದ್ದ ಫೈಲ್ ಹೆಚ್ಚು, ಚಿಕ್ಕದು ಕಡಿಮೆ. ಪ್ರಾರಂಭದ ಮೊದಲು ಅಂದಾಜು ಕಾಣುತ್ತದೆ.',
    'credit_policy_live_rule_1':
        'ನೀವು ಈಗಾಗಲೇ ಖರೀದಿಸಿದ ಫೈಲ್ ಕ್ರೆಡಿಟ್‌ಗಳು ಮುಗಿಯುವವರೆಗೆ 1 ಫೈಲ್ = 1 ಕ್ರೆಡಿಟ್.',
    'credit_policy_live_rule_2':
        'ಹೊಸ ಟಾಪ್-ಅಪ್‌ಗಳು 1 / 5 / 10 ದಶಲಕ್ಷ ಟೋಕನ್ ಪ್ಯಾಕ್‌ಗಳು. ಉಳಿದ ಕ್ರೆಡಿಟ್ ಮತ್ತು ಟೋಕನ್ ಬ್ಯಾಲೆನ್ಸ್ ಒಟ್ಟಿಗೆ ಕಾಣುತ್ತವೆ.',
    'credit_policy_live_rule_3':
        'ಒಂದು ಕೆಲಸ ಉಳಿದ ಫೈಲ್ ಕ್ರೆಡಿಟ್ ಅಥವಾ ಟೋಕನ್ ಮಾತ್ರ ಬಳಸುತ್ತದೆ — ಎರಡನ್ನೂ ಮಿಶ್ರಣ ಮಾಡುವುದಿಲ್ಲ.',
    'credit_policy_live_ads':
        'ರಿವಾರ್ಡ್ ಜಾಹೀರಾತು ಮುಂದುವರಿಯುತ್ತದೆ: 5 ಜಾಹೀರಾತು = 75,000 ಟೋಕನ್. ದೈನಂದಿನ ಮತ್ತು ವಾರದ ಮಿತಿ ಅದೇ.',
    'credit_policy_live_ok': 'ಸರಿ',
    'token_pack_coverage':
        'ಸುಮಾರು {movies} ಚಲನಚಿತ್ರಗಳು ಅಥವಾ {episodes} ಕಂತುಗಳು',

  },
  'PA': {
    'wallet_token_label': 'ਟੋਕਨ',
    'wallet_bonus_token_label': 'ਬੋਨਸ ਟੋਕਨ',
    'credit_explanation_tokens_paid': 'ਬਾਕੀ ਭੁਗਤਾਨ ਕ੍ਰੈਡਿਟ ਅਜੇ ਵੀ 1 ਫਾਈਲ = 1 ਕ੍ਰੈਡਿਟ ਹਨ। ਬਾਕੀ ਬੋਨਸ ਕ੍ਰੈਡਿਟ ਟੋਕਨ ਵਿੱਚ ਬਦਲ ਜਾਂਦੇ ਹਨ।',
    'credit_explanation_tokens_expiry': 'ਬੋਨਸ ਟੋਕਨ 1 ਮਹੀਨੇ ਲਈ ਮਾਨ્ય ਹਨ। ਇਸ ਮਿਆਦ ਦੌਰਾਨ ਇਹਨਾਂ ਨੂੰ ਇਕੱਠਾ ਕਰਕੇ ਵਰਤਿਆ ਜਾ ਸਕਦਾ ਹੈ; 1 ਮਹੀਨੇ ਬਾਅਦ ਬਚੇ ਹੋਏ ਬੋਨਸ ਟੋਕਨ ਤੁਹਾਡੇ ਖਾਤੇ ਤੋਂ ਹਟਾ ਦਿੱਤੇ ਜਾਂਦੇ ਹਨ।',
    'bonus_token_expiry_title': 'ਬੋਨਸ ਟੋਕਨ ਮਿਆਦ ਪੁੱਗਦੇ ਹਨ',
    'ad_reward_tile_title_tokens': 'ਇਸ਼ਤਿਹਾਰ ਵੇਖੋ, ਟੋਕਨ ਕਮਾਓ',
    'ad_reward_tile_desc_tokens': 'ਹਰ ਇਸ਼ਤਿਹਾਰ 5,000 ਟੋਕਨ ਦਿੰਦਾ ਹੈ।',
    'ad_reward_limit_desc_tokens': 'ਦਿਨ ਵਿੱਚ ਵੱਧ ਤੋਂ ਵੱਧ 10 ਅਤੇ ਹਫ਼ਤੇ ਵਿੱਚ 40 ਇਸ਼ਤਿਹਾਰ। ਬੋਨਸ ਟੋਕਨ 1 ਮਹੀਨੇ ਲਈ ਮਾਨ્ય ਹਨ। ਇਸ ਮਿਆਦ ਦੌਰਾਨ ਇਹਨਾਂ ਨੂੰ ਇਕੱਠਾ ਕਰਕੇ ਵਰਤਿਆ ਜਾ ਸਕਦਾ ਹੈ; 1 ਮਹੀਨੇ ਬਾਅਦ ਬਚੇ ਹੋਏ ਬੋਨਸ ਟੋਕਨ ਤੁਹਾਡੇ ਖਾਤੇ ਤੋਂ ਹਟਾ ਦਿੱਤੇ ਜਾਂਦੇ ਹਨ।',
    'ad_reward_each_ad_hint': 'ਹਰ ਇਸ਼ਤਿਹਾਰ {tokens} ਟੋਕਨ ਜੋੜਦਾ ਹੈ।',
    'token_mix_paid_title': 'ਬੋਨਸ ਟੋਕਨ ਕਾਫ਼ੀ ਨਹੀਂ',
    'token_mix_paid_body': 'ਇਸ ਫਾਈਲ ਨੂੰ ਲਗਭਗ {needed} ਟੋਕਨ ਚਾਹੀਦੇ: {bonus} ਬੋਨਸ ਤੋਂ, {paid} ਭੁਗਤਾਨ ਤੋਂ।',
    'token_mix_paid_confirm': 'ਜਾਰੀ ਰੱਖੋ',
    'referral_cta_tokens': 'ਰੈਫਰ ਕਰੋ ਅਤੇ\nਟੋਕਨ ਕਮਾਓ',
    'referral_dialog_desc_tokens':
        'ਆਪਣਾ ਕੋਡ ਇੱਕ ਦੋਸਤ ਨਾਲ ਸਾਂਝਾ ਕਰੋ। ਜਦੋਂ ਉਹ ਐਪ ਵਿੱਚ ਆ ਕੇ ਕੋਡ ਵਰਤਦੇ ਹਨ, ਤੁਹਾਡੇ ਦੋਵਾਂ ਨੂੰ 150,000 ਟੋਕਨ ਮਿਲਦੇ ਹਨ।',
    'referral_claim_success_tokens': 'ਰੈਫਰਲ ਬੋਨਸ ਜੋੜਿਆ ਗਿਆ। 150,000 ਟੋਕਨ ਜਮ੍ਹਾਂ ਹੋ ਗਏ।',
    'referral_share_message_tokens':
        'ਮੇਰੇ ਰੈਫਰਲ ਕੋਡ ਨਾਲ AI SRT Subtitle Translator & Editor ਵਿੱਚ ਸ਼ਾਮਲ ਹੋਵੋ: {code}। ਵਰਤਣ ’ਤੇ ਸਾਨੂੰ ਦੋਹਾਂ ਨੂੰ 150,000 ਟੋਕਨ ਮਿਲਣਗੇ।',
    'tutorial_referral_desc_tokens':
        'ਇਹ ਬਟਨ ਰੈਫਰਲ ਕੇਂਦਰ ਖੋਲ੍ਹਦਾ ਹੈ। ਦੋਸਤਾਂ ਨੂੰ ਸੱਦੋ, ਤੁਸੀਂ ਦੋਵੇਂ 150,000 ਟੋਕਨ ਕਮਾ ਸਕਦੇ ਹੋ। Google ਸਾਈਨ-ਇਨ ਲੋੜੀਂਦਾ ਹੈ।',
    'credit_source_referral': 'ਰੈਫਰਲ ਇਨਾਮ',
    'ad_reward_token_cta': 'ਇਸ਼ਤਿਹਾਰ ਦੇਖੋ\nਟੋਕਨ ਕਮਾਓ',
    'prefer_free_tokens_first': 'ਪਹਿਲਾਂ ਬੋਨਸ ਟੋਕਨ ਵਰਤੋ',
    'subscription_monthly_note_tokens': 'ਮਹੀਨਾਵਾਰ ਨਵਿਆਇਆ ਜਾਂਦਾ ਹੈ। ਨਾ ਵਰਤੇ ਟੋਕਨ ਅੱਗੇ ਨਹੀਂ ਜਾਂਦੇ।',
    'ad_gate_desc_tokens': 'ਬੋਨਸ ਟੋਕਨ ਪ੍ਰੋਸੈਸਿੰਗ ਤੋਂ ਪਹਿਲਾਂ ਰਿਵਾਰਡਿਡ ਇਸ਼ਤਿਹਾਰ ਦਿਖਾਉਂਦੇ ਹਨ। ਜੇ ਕਾਫ਼ੀ ਨਹੀਂ, ਬਾਕੀ ਭੁਗਤਾਨ ਟੋਕਨ ਤੋਂ ਕੱਟਿਆ ਜਾਵੇਗਾ; ਇਸ਼ਤਿਹਾਰ ਫਿਰ ਵੀ ਚੱਲੇਗਾ। ਭੁਗਤਾਨ ਫਾਈਲ ਕ੍ਰੈਡਿਟ, ਸਿਰਫ਼ ਭੁਗਤਾਨ ਟੋਕਨ ਵਾਲੇ ਕੰਮ ਅਤੇ ਸਕ੍ਰਿਆ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਬਿਨਾਂ ਇਸ਼ਤਿਹਾਰ ਤੁਰੰਤ ਸ਼ੁਰੂ ਹੁੰਦੇ ਹਨ।',
    'file_rights_unit': 'ਫਾਈਲ',
    'start_cost_one_file_right': 'ਫਾਈਲ',
    'wallet_paid_token_label': 'ਭੁਗਤਾਨ ਟੋਕਨ',
    'history_menu_tokens': 'ਅਨੁਵਾਦ/ਟੋਕਨ ਇਤਿਹਾਸ',
    'credit_history_title_tokens': 'ਟੋਕਨ ਇਤਿਹਾਸ',
    'credit_history_add_tokens': 'ਟੋਕਨ ਜੋੜੇ ਗਏ',
    'credit_history_spend_tokens': 'ਟੋਕਨ ਵਰਤੇ ਗਏ',
    'credit_history_subscription_forfeit_tokens': 'ਨਾ ਵਰਤੇ ਗਏ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਟੋਕਨ ਰੀਸੈੱਟ ਹੋਏ',
    'add_tokens': 'ਟੋਕਨ ਜੋੜੋ',
    'credit_explanation_tokens':
        'ਟੋਕਨ ਫਾਈਲ ਦੀ ਲੰਬਾਈ ਅਨੁਸਾਰ ਖਰਚ ਹੁੰਦੇ ਹਨ। ਬਾਕੀ ਭੁਗਤਾਨ ਕ੍ਰੈਡਿਟ ਅਜੇ ਵੀ 1 ਫਾਈਲ = 1 ਕ੍ਰੈਡਿਟ ਹਨ।',
    'token_estimate_title': 'ਅਨੁਮਾਨਿਤ ਟੋਕਨ ਵਰਤੋਂ',
    'token_estimate_body':
        'ਇਹ ਫਾਈਲ ਲਗਭਗ {tokens} ਟੋਕਨ ਵਰਤੇਗੀ। ਬਾਅਦ ਵਿੱਚ ਬਾਕੀ: {remaining}.',
    'token_estimate_cancel': 'ਰੱਦ',
    'token_estimate_confirm': 'ਸ਼ੁਰੂ',
    'token_insufficient_title': 'ਲੋੜੀਂਦੇ ਟੋਕਨ ਨਹੀਂ',
    'token_insufficient_body':
        'ਇਸ ਫਾਈਲ ਨੂੰ {needed} ਟੋਕਨ ਚਾਹੀਦੇ ਹਨ। ਤੁਹਾਡੇ ਕੋਲ {balance} ਹਨ।',
    'token_insufficient_shop': 'ਟੋਕਨ ਜੋੜੋ',
    'credit_policy_live_title': 'ਬਿਲਿੰਗ ਹੁਣ ਟੋਕਨ ਨਾਲ ਹੈ',
    'credit_policy_live_intro':
        '1 ਸਤੰਬਰ 2026 ਤੋਂ ਨਵੀਆਂ ਅਨੁਵਾਦਾਂ ਟੋਕਨ ਨਾਲ ਚਾਰਜ ਹੁੰਦੀਆਂ ਹਨ। ਲੰਬੀ ਫਾਈਲ ਵੱਧ, ਛੋਟੀ ਘੱਟ ਖਰਚਦੀ ਹੈ। ਸ਼ੁਰੂ ਤੋਂ ਪਹਿਲਾਂ ਅਨੁਮਾਨ ਦਿਖਦਾ ਹੈ।',
    'credit_policy_live_rule_1':
        'ਤੁਹਾਡੇ ਭੁਗਤਾਨ ਫਾਈਲ ਕ੍ਰੈਡਿਟ ਖਤਮ ਹੋਣ ਤੱਕ 1 ਫਾਈਲ = 1 ਕ੍ਰੈਡਿਟ ਰਹਿੰਦੇ ਹਨ।',
    'credit_policy_live_rule_2':
        'ਨਵੀਆਂ ਟਾਪ-ਅੱਪਾਂ 1 / 5 / 10 ਮਿਲੀਅਨ ਟੋਕਨ ਪੈਕ ਹਨ। ਬਾਕੀ ਕ੍ਰੈਡਿਟ ਅਤੇ ਟੋਕਨ ਬੈਲੈਂਸ ਇਕੱਠੇ ਦਿਖਦੇ ਹਨ।',
    'credit_policy_live_rule_3':
        'ਇੱਕ ਕੰਮ ਬਾਕੀ ਫਾਈਲ ਕ੍ਰੈਡਿਟ ਜਾਂ ਟੋਕਨ ਵਰਤਦਾ ਹੈ — ਦੋਵੇਂ ਮਿਲਾ ਕੇ ਨਹੀਂ।',
    'credit_policy_live_ads':
        'ਰਿਵਾਰਡ ਇਸ਼ਤਿਹਾਰ ਜਾਰੀ: 5 ਇਸ਼ਤਿਹਾਰ = 75,000 ਟੋਕਨ। ਰੋਜ਼ਾਨਾ ਅਤੇ ਹਫ਼ਤਾਵਾਰੀ ਸੀਮਾ ਉਹੀ।',
    'credit_policy_live_ok': 'ਠੀਕ ਹੈ',
    'token_pack_coverage':
        'ਲਗਭਗ {movies} ਫਿਲਮਾਂ ਜਾਂ {episodes} ਐਪੀਸੋਡ',

  },
  'GU': {
    'wallet_token_label': 'ટોકન',
    'wallet_bonus_token_label': 'બોનસ ટોકન',
    'credit_explanation_tokens_paid': 'બાકી ચૂકવેલ ક્રેડિટ હજુ 1 ફાઇલ = 1 ક્રેડિટ છે. બાકી બોનસ ક્રેડિટ ટોકનમાં ફેરવાય છે.',
    'credit_explanation_tokens_expiry': 'બોનસ ટોકન 1 મહિનો સુધી માન્ય રહે છે. આ સમયગાળામાં તેમને ભેગા કરીને વાપરી શકાય છે; 1 મહિના પછી બાકીના બોનસ ટોકન તમારા ખાતામાંથી કાઢી નાખાય છે.',
    'bonus_token_expiry_title': 'બોનસ ટોકનની મુદત પૂરી થાય છે',
    'ad_reward_tile_title_tokens': 'જાહેરાત જુઓ, ટોકન કમાઓ',
    'ad_reward_tile_desc_tokens': 'દરેક જાહેરાત 5,000 ટોકન આપે છે.',
    'ad_reward_limit_desc_tokens': 'દિવસે વધુમાં વધુ 10 અને અઠવાડિયે 40 જાહેરાત. બોનસ ટોકન 1 મહિનો સુધી માન્ય રહે છે. આ સમયગાળામાં તેમને ભેગા કરીને વાપરી શકાય છે; 1 મહિના પછી બાકીના બોનસ ટોકન તમારા ખાતામાંથી કાઢી નાખાય છે.',
    'ad_reward_each_ad_hint': 'દરેક જાહેરાત {tokens} ટોકન ઉમેરે છે.',
    'token_mix_paid_title': 'બોનસ ટોકન પૂરતા નથી',
    'token_mix_paid_body': 'આ ફાઇલને લગભગ {needed} ટોકન જોઈએ: {bonus} બોનસમાંથી, {paid} ચૂકવેલમાંથી.',
    'token_mix_paid_confirm': 'ચાલુ રાખો',
    'referral_cta_tokens': 'રેફર કરો અને\nટોકન કમાઓ',
    'referral_dialog_desc_tokens':
        'તમારો કોડ મિત્ર સાથે શેર કરો. તેઓ એપમાં જોડાઈને કોડ વાપરે ત્યારે તમને બંનેને 150,000 ટોકન મળે છે.',
    'referral_claim_success_tokens': 'રેફરલ બોનસ ઉમેરાયું. 150,000 ટોકન જમા થયા.',
    'referral_share_message_tokens':
        'મારા રેફરલ કોડ સાથે AI SRT Subtitle Translator & Editorમાં જોડાઓ: {code}. વાપરશો ત્યારે આપણાં બંનેને 150,000 ટોકન મળશે.',
    'tutorial_referral_desc_tokens':
        'આ બટન રેફરલ કેન્દ્ર ખોલે છે. મિત્રોને આમંત્રો અને તમે બંને 150,000 ટોકન મેળવી શકો છો. Google સાઇન-ઇન જરૂરી છે.',
    'credit_source_referral': 'રેફરલ ઇનામ',
    'ad_reward_token_cta': 'જાહેરાત જુઓ\nટોકન કમાઓ',
    'prefer_free_tokens_first': 'પહેલા બોનસ ટોકન વાપરો',
    'subscription_monthly_note_tokens': 'માસિક નવીકરણ. વપરાય નહીં એવા ટોકન આગળ લઈ જવાતા નથી.',
    'ad_gate_desc_tokens': 'બોનસ ટોકન પ્રોસેસ કરતા પહેલાં રિવોર્ડેડ જાહેરાત બતાવે છે. પૂરતા ન હોય તો, બાકી ચૂકવેલ ટોકનમાંથી કપાશે; જાહેરાત ફરી પણ ચાલશે. ચૂકવેલ ફાઇલ ક્રેડિટ, ફક્ત ચૂકવેલ ટોકનવાળા કામ અને સક્રિય સબ્સ્ક્રિપ્શન જાહેરાત વગર તરત શરૂ થાય છે.',
    'file_rights_unit': 'ફાઇલ',
    'start_cost_one_file_right': 'ફાઇલ',
    'wallet_paid_token_label': 'ચૂકવેલ ટોકન',
    'history_menu_tokens': 'અનુવાદ/ટોકન ઇતિહાસ',
    'credit_history_title_tokens': 'ટોકન ઇતિહાસ',
    'credit_history_add_tokens': 'ટોકન ઉમેરાયા',
    'credit_history_spend_tokens': 'ટોકન ખર્ચાયા',
    'credit_history_subscription_forfeit_tokens': 'ન વપરાયેલા સબ્સ્ક્રિપ્શન ટોકન રીસેટ થયા',
    'add_tokens': 'ટોકન ઉમેરો',
    'credit_explanation_tokens':
        'ટોકન ફાઇલની લંબાઈ પ્રમાણે ખર્ચાય છે. બાકી ચૂકવેલ ક્રેડિટ હજુ 1 ફાઇલ = 1 ક્રેડિટ છે.',
    'token_estimate_title': 'અંદાજિત ટોકન વપરાશ',
    'token_estimate_body':
        'આ ફાઇલ આશરે {tokens} ટોકન વાપરશે. પછી બાકી: {remaining}.',
    'token_estimate_cancel': 'રદ',
    'token_estimate_confirm': 'શરૂ કરો',
    'token_insufficient_title': 'પૂરતા ટોકન નથી',
    'token_insufficient_body':
        'આ ફાઇલને {needed} ટોકન જોઈએ. તમારી પાસે {balance} છે.',
    'token_insufficient_shop': 'ટોકન ઉમેરો',
    'credit_policy_live_title': 'બિલિંગ હવે ટોકનથી છે',
    'credit_policy_live_intro':
        '1 સપ્ટેમ્બર 2026થી નવા અનુવાદ ટોકનથી વસૂલાય છે. લાંબી ફાઇલ વધુ, ટૂંકી ઓછી ખર્ચે છે. શરૂ કરતા પહેલાં અંદાજ દેખાય છે.',
    'credit_policy_live_rule_1':
        'તમારી પાસેના ચૂકવેલ ફાઇલ ક્રેડિટ પૂરા થાય ત્યાં સુધી 1 ફાઇલ = 1 ક્રેડિટ રહે છે.',
    'credit_policy_live_rule_2':
        'નવા ટોપ-અપ 1 / 5 / 10 મિલિયન ટોકન પેક છે. બાકી ક્રેડિટ અને ટોકન બેલેન્સ સાથે દેખાય છે.',
    'credit_policy_live_rule_3':
        'એક કામ બાકી ફાઇલ ક્રેડિટ અથવા ટોકન વાપરે છે — બંને ભેગા નહીં.',
    'credit_policy_live_ads':
        'રિવોર્ડ જાહેરાત ચાલુ: 5 જાહેરાત = 75,000 ટોકન. દૈનિક અને સાપ્તાહિક મર્યાદા એ જ.',
    'credit_policy_live_ok': 'ઠીક છે',
    'token_pack_coverage':
        'લગભગ {movies} ફિલ્મો અથવા {episodes} એપિસોડ',

  },
  'MR': {
    'wallet_token_label': 'टोकन',
    'wallet_bonus_token_label': 'बोनस टोकन',
    'credit_explanation_tokens_paid': 'उरलेली सशुल्क क्रेडिट अजूनही 1 फाइल = 1 क्रेडिट आहेत. उरलेले बोनस क्रेडिट टोकनमध्ये रूपांतरित होतात.',
    'credit_explanation_tokens_expiry': 'बोनस टोकन 1 महिना वैध राहतात. या काळात ते जमा करून वापरता येतात; 1 महिना झाल्यावर उरलेले बोनस टोकन तुमच्या खात्यातून काढले जातात.',
    'bonus_token_expiry_title': 'बोनस टोकन कालबाह्य होतात',
    'ad_reward_tile_title_tokens': 'जाहिरात पहा, टोकन मिळवा',
    'ad_reward_tile_desc_tokens': 'प्रत्येक जाहिरात 5,000 टोकन देते.',
    'ad_reward_limit_desc_tokens': 'दिवसाला जास्तीत जास्त 10 आणि आठवड्याला 40 जाहिराती. बोनस टोकन 1 महिना वैध राहतात. या काळात ते जमा करून वापरता येतात; 1 महिना झाल्यावर उरलेले बोनस टोकन तुमच्या खात्यातून काढले जातात.',
    'ad_reward_each_ad_hint': 'प्रत्येक जाहिरात {tokens} टोकन जोडते.',
    'token_mix_paid_title': 'बोनस टोकन पुरे नाहीत',
    'token_mix_paid_body': 'या फाइलला सुमारे {needed} टोकन लागतील: {bonus} बोनसमधून, {paid} सशुल्कमधून.',
    'token_mix_paid_confirm': 'पुढे जा',
    'referral_cta_tokens': 'रेफर करा आणि\nटोकन मिळवा',
    'referral_dialog_desc_tokens':
        'तुमचा कोड मित्रासोबत शेअर करा. ते अॅपमध्ये येऊन कोड वापरतील तेव्हा तुम्हा दोघांना 150,000 टोकन मिळतात.',
    'referral_claim_success_tokens': 'रेफरल बोनस जोडला. 150,000 टोकन जमा झाले.',
    'referral_share_message_tokens':
        'माझ्या रेफरल कोडने AI SRT Subtitle Translator & Editor मध्ये सामील व्हा: {code}. वापरल्यावर आम्हा दोघांना 150,000 टोकन मिळतील.',
    'tutorial_referral_desc_tokens':
        'हे बटण रेफरल केंद्र उघडते. मित्रांना बोलावा, तुम्हा दोघांना 150,000 टोकन मिळू शकतात. Google साइन-इन आवश्यक आहे.',
    'credit_source_referral': 'रेफरल बक्षीस',
    'ad_reward_token_cta': 'जाहिरात पहा\nटोकन मिळवा',
    'prefer_free_tokens_first': 'प्रथम बोनस टोकन वापरा',
    'subscription_monthly_note_tokens': 'मासिक नूतनीकरण. न वापरलेले टोकन पुढे जात नाहीत.',
    'ad_gate_desc_tokens': 'बोनस टोकन प्रोसेसिंगपूर्वी रिवॉर्डेड जाहिरात दाखवतात. पुरे नसल्यास, उर्वरित सशुल्क टोकनमधून कापले जाईल; जाहिरात तरीही दिसेल. सशुल्क फाइल क्रेडिट, फक्त सशुल्क टोकन कामे आणि सक्रिय सबस्क्रिप्शन जाहिरातीशिवाय लगेच सुरू होतात.',
    'file_rights_unit': 'फाइल',
    'start_cost_one_file_right': 'फाइल',
    'wallet_paid_token_label': 'सशुल्क टोकन',
    'history_menu_tokens': 'भाषांतर/टोकन इतिहास',
    'credit_history_title_tokens': 'टोकन इतिहास',
    'credit_history_add_tokens': 'टोकन जोडले',
    'credit_history_spend_tokens': 'टोकन खर्च झाले',
    'credit_history_subscription_forfeit_tokens': 'न वापरलेली सबस्क्रिप्शन टोकने रीसेट झाली',
    'add_tokens': 'टोकन जोडा',
    'credit_explanation_tokens':
        'टोकन फाइलच्या लांबीनुसार खर्च होतात. उरलेली सशुल्क क्रेडिट अजूनही 1 फाइल = 1 क्रेडिट आहेत.',
    'token_estimate_title': 'अंदाजे टोकन वापर',
    'token_estimate_body':
        'ही फाइल सुमारे {tokens} टोकन वापरेल. नंतर शिल्लक: {remaining}.',
    'token_estimate_cancel': 'रद्द',
    'token_estimate_confirm': 'सुरू करा',
    'token_insufficient_title': 'पुरेसे टोकन नाहीत',
    'token_insufficient_body':
        'या फाइलला {needed} टोकन लागतात. तुमच्याकडे {balance} आहेत.',
    'token_insufficient_shop': 'टोकन जोडा',
    'credit_policy_live_title': 'बिलिंग आता टोकनने आहे',
    'credit_policy_live_intro':
        '1 सप्टेंबर 2026 पासून नवीन भाषांतरे टोकनने आकारली जातात. लांब फाइल जास्त, छोटी कमी खर्च करते. सुरू करण्यापूर्वी अंदाज दिसतो.',
    'credit_policy_live_rule_1':
        'तुमच्याकडील सशुल्क फाइल क्रेडिट संपेपर्यंत 1 फाइल = 1 क्रेडिट राहतात.',
    'credit_policy_live_rule_2':
        'नवीन टॉप-अप 1 / 5 / 10 दशलक्ष टोकन पॅक आहेत. उरलेली क्रेडिट आणि टोकन शिल्लक एकत्र दिसतात.',
    'credit_policy_live_rule_3':
        'एक काम उरलेली फाइल क्रेडिट किंवा टोकन वापरते — दोन्ही मिसळत नाही.',
    'credit_policy_live_ads':
        'रिवॉर्ड जाहिराती सुरूच: 5 जाहिराती = 75,000 टोकन. दैनिक व साप्ताहिक मर्यादा त्याच.',
    'credit_policy_live_ok': 'ठीक आहे',
    'token_pack_coverage':
        'सुमारे {movies} चित्रपट किंवा {episodes} भाग',

  },
  'UK': {
    'wallet_token_label': 'Токени',
    'wallet_bonus_token_label': 'Бонусні токени',
    'credit_explanation_tokens_paid': 'Залишок платних кредитів і далі: 1 файл = 1 кредит. Залишкові бонусні кредити перетворюються на токени.',
    'credit_explanation_tokens_expiry': 'Бонусні токени діють 1 місяць. Їх можна накопичувати та використовувати протягом цього часу; після місяця невикористані бонусні токени видаляються з вашого облікового запису.',
    'bonus_token_expiry_title': 'Бонусні токени згорають',
    'ad_reward_tile_title_tokens': 'Дивіться рекламу — отримуйте токени',
    'ad_reward_tile_desc_tokens': 'Кожен ролик дає 5 000 токенів.',
    'ad_reward_limit_desc_tokens': 'Не більше 10 роликів на день і 40 на тиждень. Бонусні токени діють 1 місяць. Їх можна накопичувати та використовувати протягом цього часу; після місяця невикористані бонусні токени видаляються з вашого облікового запису.',
    'ad_reward_each_ad_hint': 'Кожен ролик додає {tokens} токенів.',
    'token_mix_paid_title': 'Бонусних токенів не вистачить',
    'token_mix_paid_body': 'Цьому файлу потрібно близько {needed} токенів: {bonus} з бонусних, {paid} з платних.',
    'token_mix_paid_confirm': 'Продовжити',
    'referral_cta_tokens': 'Запросити та\nзаробити токени',
    'referral_dialog_desc_tokens':
        'Поділіться кодом із другом. Коли він зайде в застосунок і введе код, ви обоє отримаєте по 150 000 токенів.',
    'referral_claim_success_tokens': 'Реферальний бонус нараховано: 150 000 токенів.',
    'referral_share_message_tokens':
        'Приєднуйтесь до AI SRT Subtitle Translator & Editor за моїм кодом: {code}. Коли ви його введете, ми обоє отримаємо по 150 000 токенів.',
    'tutorial_referral_desc_tokens':
        'Ця кнопка відкриває центр запрошень. Запросіть друзів — ви обоє можете отримати по 150 000 токенів. Потрібен вхід через Google.',
    'credit_source_referral': 'Реферальна винагорода',
    'ad_reward_token_cta': 'Дивитися рекламу\nЗаробити токени',
    'prefer_free_tokens_first': 'Спочатку використовувати бонусні токени',
    'subscription_monthly_note_tokens': 'Оновлюється щомісяця. Невикористані токени не переносяться.',
    'ad_gate_desc_tokens': 'Бонусні токени показують рекламу з винагородою перед обробкою. Якщо їх не вистачає, решта списується з платних токенів, реклама все одно показується. Платні файлові кредити, завдання лише на платних токенах і активні підписки починаються миттєво без реклами.',
    'file_rights_unit': 'ФАЙЛ',
    'start_cost_one_file_right': 'файл',
    'wallet_paid_token_label': 'Платні токени',
    'history_menu_tokens': 'Історія перекладів/токенів',
    'credit_history_title_tokens': 'Історія токенів',
    'credit_history_add_tokens': 'Токени додано',
    'credit_history_spend_tokens': 'Токени витрачено',
    'credit_history_subscription_forfeit_tokens': 'Невикористані токени підписки скинуто',
    'add_tokens': 'Додати токени',
    'credit_explanation_tokens':
        'Витрата токенів залежить від довжини файлу. Залишок платних кредитів і далі: 1 файл = 1 кредит.',
    'token_estimate_title': 'Оцінка витрати токенів',
    'token_estimate_body':
        'Цей файл витратить близько {tokens} токенів. Залишиться: {remaining}.',
    'token_estimate_cancel': 'Скасувати',
    'token_estimate_confirm': 'Почати',
    'token_insufficient_title': 'Недостатньо токенів',
    'token_insufficient_body':
        'Цьому файлу потрібно {needed} токенів. У вас {balance}.',
    'token_insufficient_shop': 'Додати токени',
    'credit_policy_live_title': 'Оплата тепер у токенах',
    'credit_policy_live_intro':
        'З 1 вересня 2026 нові переклади оплачуються токенами. Довгі файли коштують більше, короткі — менше. Перед стартом ви бачите оцінку.',
    'credit_policy_live_rule_1':
        'Вже куплені файлові кредити діють як 1 файл = 1 кредит, доки не закінчаться.',
    'credit_policy_live_rule_2':
        'Нові пакети — 1 / 5 / 10 мільйонів токенів. Залишок кредитів і баланс токенів показано разом.',
    'credit_policy_live_rule_3':
        'Одне завдання витрачає або залишкові файлові кредити, або токени — не обидва разом.',
    'credit_policy_live_ads':
        'Реклама за нагороду: 5 роликів = 75 000 токенів. Денний і тижневий ліміти ті самі.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Близько {movies} фільмів або {episodes} серій',

  },
  'RO': {
    'wallet_token_label': 'Tokeni',
    'wallet_bonus_token_label': 'Tokeni bonus',
    'credit_explanation_tokens_paid': 'Creditele plătite rămase acoperă încă 1 fișier = 1 credit. Creditele bonus rămase devin tokeni.',
    'credit_explanation_tokens_expiry': 'Tokenii bonus sunt valabili 1 lună. Îi poți acumula și folosi în această perioadă; după 1 lună, cei rămași sunt eliminați din contul tău.',
    'bonus_token_expiry_title': 'Tokenii bonus expiră',
    'ad_reward_tile_title_tokens': 'Vezi reclamă, câștigă tokeni',
    'ad_reward_tile_desc_tokens': 'Fiecare reclamă dă 5.000 de tokeni.',
    'ad_reward_limit_desc_tokens': 'Cel mult 10 reclame pe zi și 40 pe săptămână. Tokenii bonus sunt valabili 1 lună. Îi poți acumula și folosi în această perioadă; după 1 lună, cei rămași sunt eliminați din contul tău.',
    'ad_reward_each_ad_hint': 'Fiecare reclamă adaugă {tokens} tokeni.',
    'token_mix_paid_title': 'Tokenii bonus nu ajung',
    'token_mix_paid_body': 'Acest fișier necesită aproximativ {needed} tokeni: {bonus} din bonus, {paid} din cei plătiți.',
    'token_mix_paid_confirm': 'Continuă',
    'referral_cta_tokens': 'Recomandă și\nCâștigă tokeni',
    'referral_dialog_desc_tokens':
        'Distribuie codul unui prieten. Când intră în aplicație și îl folosește, primiți amândoi 150.000 de tokeni.',
    'referral_claim_success_tokens': 'Bonusul de recomandare a fost adăugat. S-au acordat 150.000 de tokeni.',
    'referral_share_message_tokens':
        'Intră în AI SRT Subtitle Translator & Editor cu codul meu: {code}. Când îl folosești, primim amândoi 150.000 de tokeni.',
    'tutorial_referral_desc_tokens':
        'Acest buton deschide centrul de recomandări. Invită prieteni și puteți primi amândoi 150.000 de tokeni. Este nevoie de autentificare Google.',
    'credit_source_referral': 'Recompensă de recomandare',
    'ad_reward_token_cta': 'Vizionează reclamă\nCâștigă tokeni',
    'prefer_free_tokens_first': 'Folosește mai întâi tokenii bonus',
    'subscription_monthly_note_tokens': 'Se reînnoiește lunar. Tokenii nefolosiți nu se reportează.',
    'ad_gate_desc_tokens': 'Tokenii bonus afișează o reclamă recompensată înainte de procesare. Dacă nu ajung, restul se ia din tokenii plătiți și reclama tot apare. Creditele de fișier plătite, lucrările doar cu tokeni plătiți și abonamentele active pornesc imediat fără reclame.',
    'file_rights_unit': 'FIȘIER',
    'start_cost_one_file_right': 'fișier',
    'wallet_paid_token_label': 'Tokeni plătiți',
    'history_menu_tokens': 'Istoric traduceri/tokeni',
    'credit_history_title_tokens': 'Istoric tokeni',
    'credit_history_add_tokens': 'Tokeni adăugați',
    'credit_history_spend_tokens': 'Tokeni cheltuiți',
    'credit_history_subscription_forfeit_tokens': 'Tokenii nefolosiți din abonament au fost resetați',
    'add_tokens': 'Adaugă tokeni',
    'credit_explanation_tokens':
        'Tokenii depind de lungimea fișierului. Creditele plătite rămase acoperă încă 1 fișier = 1 credit.',
    'token_estimate_title': 'Estimare consum de tokeni',
    'token_estimate_body':
        'Acest fișier va folosi circa {tokens} tokeni. Rămân după: {remaining}.',
    'token_estimate_cancel': 'Anulează',
    'token_estimate_confirm': 'Start',
    'token_insufficient_title': 'Tokeni insuficienți',
    'token_insufficient_body':
        'Acest fișier are nevoie de {needed} tokeni. Aveți {balance}.',
    'token_insufficient_shop': 'Adaugă tokeni',
    'credit_policy_live_title': 'Facturarea folosește acum tokeni',
    'credit_policy_live_intro':
        'De la 1 septembrie 2026 traducerile noi se taxează în tokeni. Fișierele lungi costă mai mult, cele scurte mai puțin. Vezi o estimare înainte de start.',
    'credit_policy_live_rule_1':
        'Creditele de fișier deja plătite rămân 1 fișier = 1 credit până se epuizează.',
    'credit_policy_live_rule_2':
        'Reîncărcările noi sunt pachete de 1 / 5 / 10 milioane de tokeni. Creditele rămase și soldul de tokeni apar împreună.',
    'credit_policy_live_rule_3':
        'O lucrare folosește fie credite de fișier rămase, fie tokeni — niciodată amestecate.',
    'credit_policy_live_ads':
        'Reclamele recompensate continuă: 5 reclame = 75.000 tokeni. Limitele zilnice și săptămânale rămân aceleași.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Aproximativ {movies} filme sau {episodes} episoade',

  },
  'CS': {
    'wallet_token_label': 'Tokeny',
    'wallet_bonus_token_label': 'Bonusové tokeny',
    'credit_explanation_tokens_paid': 'Zbývající placené kredity stále platí 1 soubor = 1 kredit. Zbývající bonusové kredity se přemění na tokeny.',
    'credit_explanation_tokens_expiry': 'Bonusové tokeny platí 1 měsíc. Můžete je sbírat a používat během této doby; po uplynutí měsíce se nepoužité bonusové tokeny z vašeho účtu odstraní.',
    'bonus_token_expiry_title': 'Bonusové tokeny vyprší',
    'ad_reward_tile_title_tokens': 'Sledujte reklamu, získejte tokeny',
    'ad_reward_tile_desc_tokens': 'Každá reklama dá 5 000 tokenů.',
    'ad_reward_limit_desc_tokens': 'Nejvýše 10 reklam denně a 40 týdně. Bonusové tokeny platí 1 měsíc. Můžete je sbírat a používat během této doby; po uplynutí měsíce se nepoužité bonusové tokeny z vašeho účtu odstraní.',
    'ad_reward_each_ad_hint': 'Každá reklama přidá {tokens} tokenů.',
    'token_mix_paid_title': 'Bonusové tokeny nestačí',
    'token_mix_paid_body': 'Tento soubor potřebuje asi {needed} tokenů: {bonus} z bonusových, {paid} z placených.',
    'token_mix_paid_confirm': 'Pokračovat',
    'referral_cta_tokens': 'Doporučit a\nZískat tokeny',
    'referral_dialog_desc_tokens':
        'Sdílejte kód s kamarádem. Až vstoupí do aplikace a kód použije, dostanete oba 150 000 tokenů.',
    'referral_claim_success_tokens': 'Referenční bonus připsán. Bylo přidáno 150 000 tokenů.',
    'referral_share_message_tokens':
        'Přidejte se k AI SRT Subtitle Translator & Editor s mým kódem: {code}. Po použití kódu dostaneme oba 150 000 tokenů.',
    'tutorial_referral_desc_tokens':
        'Toto tlačítko otevře centrum doporučení. Pozvěte přátele a oba můžete získat 150 000 tokenů. Je potřeba přihlášení přes Google.',
    'credit_source_referral': 'Odměna za doporučení',
    'ad_reward_token_cta': 'Sledovat reklamu\nZískat tokeny',
    'prefer_free_tokens_first': 'Nejprve použít bonusové tokeny',
    'subscription_monthly_note_tokens': 'Obnovuje se měsíčně. Nevyužité tokeny se nepřenášejí.',
    'ad_gate_desc_tokens': 'Bonusové tokeny před zpracováním zobrazí odměňovanou reklamu. Pokud nestačí, zbytek se bere z placených tokenů a reklama se stejně zobrazí. Placené souborové kredity, práce jen na placených tokenech a aktivní předplatné začínají okamžitě bez reklam.',
    'file_rights_unit': 'SOUBOR',
    'start_cost_one_file_right': 'soubor',
    'wallet_paid_token_label': 'Placené tokeny',
    'history_menu_tokens': 'Historie překladů/tokenů',
    'credit_history_title_tokens': 'Historie tokenů',
    'credit_history_add_tokens': 'Tokeny přidány',
    'credit_history_spend_tokens': 'Tokeny spotřebovány',
    'credit_history_subscription_forfeit_tokens': 'Nevyužité tokeny předplatného byly vynulovány',
    'add_tokens': 'Přidat tokeny',
    'credit_explanation_tokens':
        'Tokeny se odvíjejí od délky souboru. Zbývající placené kredity stále platí 1 soubor = 1 kredit.',
    'token_estimate_title': 'Odhad spotřeby tokenů',
    'token_estimate_body':
        'Tento soubor spotřebuje asi {tokens} tokenů. Poté zbude: {remaining}.',
    'token_estimate_cancel': 'Zrušit',
    'token_estimate_confirm': 'Spustit',
    'token_insufficient_title': 'Nedostatek tokenů',
    'token_insufficient_body':
        'Tento soubor potřebuje {needed} tokenů. Máte {balance}.',
    'token_insufficient_shop': 'Přidat tokeny',
    'credit_policy_live_title': 'Účtování nyní probíhá v tokenech',
    'credit_policy_live_intro':
        'Od 1. září 2026 se nové překlady účtují v tokenech. Delší soubory stojí víc, kratší méně. Před startem uvidíte odhad.',
    'credit_policy_live_rule_1':
        'Již zakoupené souborové kredity platí jako 1 soubor = 1 kredit, dokud nedojdou.',
    'credit_policy_live_rule_2':
        'Nové dobití jsou balíčky 1 / 5 / 10 milionů tokenů. Zbývající kredity a zůstatek tokenů se zobrazují spolu.',
    'credit_policy_live_rule_3':
        'Jedna úloha použije buď zbývající souborové kredity, nebo tokeny — nikdy obojí najednou.',
    'credit_policy_live_ads':
        'Odměňované reklamy pokračují: 5 reklam = 75 000 tokenů. Denní a týdenní limity zůstávají.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Asi {movies} filmů nebo {episodes} dílů',

  },
  'HU': {
    'wallet_token_label': 'Token',
    'wallet_bonus_token_label': 'Bónusz token',
    'credit_explanation_tokens_paid': 'A megmaradt fizetett kreditek továbbra is 1 fájl = 1 kredit. A megmaradt bónuszkreditek tokenné alakulnak.',
    'credit_explanation_tokens_expiry': 'A bónusz tokenek 1 hónapig érvényesek. Ebben az időben összegyűjtheted és felhasználhatod őket; 1 hónap után a megmaradt bónusz tokenek törlődnek a fiókodból.',
    'bonus_token_expiry_title': 'A bónusz tokenek lejárnak',
    'ad_reward_tile_title_tokens': 'Hirdetés megtekintése, token szerzése',
    'ad_reward_tile_desc_tokens': 'Minden hirdetés 5 000 tokent ad.',
    'ad_reward_limit_desc_tokens': 'Naponta legfeljebb 10, hetente 40 hirdetés. A bónusz tokenek 1 hónapig érvényesek. Ebben az időben összegyűjtheted és felhasználhatod őket; 1 hónap után a megmaradt bónusz tokenek törlődnek a fiókodból.',
    'ad_reward_each_ad_hint': 'Minden hirdetés {tokens} tokent ad hozzá.',
    'token_mix_paid_title': 'A bónusz tokenek nem elégségesek',
    'token_mix_paid_body': 'Ehhez a fájlhoz kb. {needed} token kell: {bonus} bónuszból, {paid} fizetettből.',
    'token_mix_paid_confirm': 'Folytatás',
    'referral_cta_tokens': 'Ajánlás és\nToken szerzése',
    'referral_dialog_desc_tokens':
        'Oszd meg a kódod egy barátoddal. Ha belép az alkalmazásba és beváltja, mindketten 150 000 tokent kaptok.',
    'referral_claim_success_tokens': 'Ajánlói bónusz hozzáadva. 150 000 token került a számlára.',
    'referral_share_message_tokens':
        'Csatlakozz az AI SRT Subtitle Translator & Editorhoz az ajánlói kódommal: {code}. Ha beváltod, mindketten 150 000 tokent kapunk.',
    'tutorial_referral_desc_tokens':
        'Ez a gomb megnyitja az ajánlói központot. Hívj barátokat, és mindketten kaphattok 150 000 tokent. Google-bejelentkezés kell.',
    'credit_source_referral': 'Ajánlói jutalom',
    'ad_reward_token_cta': 'Hirdetés megtekintése\nToken szerzése',
    'prefer_free_tokens_first': 'Először a bónusz tokeneket használd',
    'subscription_monthly_note_tokens': 'Havi megújulás. A fel nem használt tokenek nem vihetők tovább.',
    'ad_gate_desc_tokens': 'A bónusz tokenek feldolgozás előtt jutalmazó hirdetést jelenítenek meg. Ha nem elég, a maradék fizetett tokenből vonódik le, a hirdetés ettől még megjelenik. Fizetős fájlkreditek, csak fizetett tokenes feladatok és aktív előfizetések azonnal, reklám nélkül indulnak.',
    'file_rights_unit': 'FÁJL',
    'start_cost_one_file_right': 'fájl',
    'wallet_paid_token_label': 'Fizetett token',
    'history_menu_tokens': 'Fordítás/token előzmények',
    'credit_history_title_tokens': 'Token előzmények',
    'credit_history_add_tokens': 'Token hozzáadva',
    'credit_history_spend_tokens': 'Token felhasználva',
    'credit_history_subscription_forfeit_tokens': 'Fel nem használt előfizetési tokenek nullázva',
    'add_tokens': 'Token hozzáadása',
    'credit_explanation_tokens':
        'A tokenfelhasználás a fájl hosszától függ. A megmaradt fizetett kreditek továbbra is 1 fájl = 1 kredit.',
    'token_estimate_title': 'Becsült tokenfelhasználás',
    'token_estimate_body':
        'Ez a fájl körülbelül {tokens} tokent használ. Utána marad: {remaining}.',
    'token_estimate_cancel': 'Mégse',
    'token_estimate_confirm': 'Indítás',
    'token_insufficient_title': 'Nincs elég token',
    'token_insufficient_body':
        'Ehhez a fájlhoz {needed} token kell. Önnek {balance} van.',
    'token_insufficient_shop': 'Token hozzáadása',
    'credit_policy_live_title': 'A számlázás mostantól tokennel történik',
    'credit_policy_live_intro':
        '2026. szeptember 1-jétől az új fordítások tokent fogyasztanak. A hosszabb fájl többe, a rövidebb kevesebbe kerül. Indítás előtt becslést lát.',
    'credit_policy_live_rule_1':
        'A már megvásárolt fájlkreditek 1 fájl = 1 kreditként maradnak, amíg el nem fogynak.',
    'credit_policy_live_rule_2':
        'Az új feltöltések 1 / 5 / 10 milliós tokencsomagok. A maradék kredit és a tokenegyenleg együtt jelenik meg.',
    'credit_policy_live_rule_3':
        'Egy feladat vagy maradék fájlkreditet, vagy tokent használ — soha nem keverve.',
    'credit_policy_live_ads':
        'A jutalmazott hirdetések maradnak: 5 hirdetés = 75 000 token. A napi és heti limitek változatlanok.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Kb. {movies} film vagy {episodes} epizód',

  },
  'DA': {
    'wallet_token_label': 'Tokens',
    'wallet_bonus_token_label': 'Bonustokens',
    'credit_explanation_tokens_paid': 'Tilbageværende betalte kreditter dækker stadig 1 fil = 1 kredit. Tilbageværende bonuskreditter bliver tokens.',
    'credit_explanation_tokens_expiry': 'Bonustokens er gyldige i 1 måned. Du kan samle dem og bruge dem i den periode; efter 1 måned fjernes ubrugte bonustokens fra din konto.',
    'bonus_token_expiry_title': 'Bonustokens udløber',
    'ad_reward_tile_title_tokens': 'Se annonce, tjen tokens',
    'ad_reward_tile_desc_tokens': 'Hver annonce giver 5.000 tokens.',
    'ad_reward_limit_desc_tokens': 'Højst 10 annoncer om dagen og 40 om ugen. Bonustokens er gyldige i 1 måned. Du kan samle dem og bruge dem i den periode; efter 1 måned fjernes ubrugte bonustokens fra din konto.',
    'ad_reward_each_ad_hint': 'Hver annonce tilføjer {tokens} tokens.',
    'token_mix_paid_title': 'Bonustokens rækker ikke',
    'token_mix_paid_body': 'Denne fil kræver ca. {needed} tokens: {bonus} fra bonus, {paid} fra betalte.',
    'token_mix_paid_confirm': 'Fortsæt',
    'referral_cta_tokens': 'Henvis og\nTjen tokens',
    'referral_dialog_desc_tokens':
        'Del din kode med en ven. Når vedkommende åbner appen og indløser koden, får I begge 150.000 tokens.',
    'referral_claim_success_tokens': 'Henvisningsbonus tilføjet. 150.000 tokens er sat ind.',
    'referral_share_message_tokens':
        'Tilmeld dig AI SRT Subtitle Translator & Editor med min henvisningskode: {code}. Når du indløser den, får vi begge 150.000 tokens.',
    'tutorial_referral_desc_tokens':
        'Denne knap åbner henvisningscentret. Inviter venner, så kan I begge få 150.000 tokens. Google-login er påkrævet.',
    'credit_source_referral': 'Henvisningsbelønning',
    'ad_reward_token_cta': 'Se annonce\nTjen tokens',
    'prefer_free_tokens_first': 'Brug bonustokens først',
    'subscription_monthly_note_tokens': 'Fornyes månedligt. Ubrugte tokens overføres ikke.',
    'ad_gate_desc_tokens': 'Bonustokens viser en belønningsannonce før behandling. Hvis de ikke rækker, tages resten fra betalte tokens, og annoncen vises stadig. Betalte filkreditter, kun-betalte-token opgaver og aktive abonnementer starter med det samme uden annoncer.',
    'file_rights_unit': 'FIL',
    'start_cost_one_file_right': 'fil',
    'wallet_paid_token_label': 'Betalte tokens',
    'history_menu_tokens': 'Oversættelses-/token-historik',
    'credit_history_title_tokens': 'Token-historik',
    'credit_history_add_tokens': 'Tokens tilføjet',
    'credit_history_spend_tokens': 'Tokens brugt',
    'credit_history_subscription_forfeit_tokens': 'Ubrugte abonnementstokens nulstillet',
    'add_tokens': 'Tilføj tokens',
    'credit_explanation_tokens':
        'Tokens afhænger af fillængden. Tilbageværende betalte kreditter dækker stadig 1 fil = 1 kredit.',
    'token_estimate_title': 'Anslået tokenforbrug',
    'token_estimate_body':
        'Denne fil bruger ca. {tokens} tokens. Bagefter tilbage: {remaining}.',
    'token_estimate_cancel': 'Annuller',
    'token_estimate_confirm': 'Start',
    'token_insufficient_title': 'Ikke nok tokens',
    'token_insufficient_body':
        'Denne fil kræver {needed} tokens. Du har {balance}.',
    'token_insufficient_shop': 'Tilføj tokens',
    'credit_policy_live_title': 'Fakturering sker nu med tokens',
    'credit_policy_live_intro':
        'Fra 1. september 2026 opkræves nye oversættelser i tokens. Længere filer koster mere, kortere mindre. Du ser et estimat før start.',
    'credit_policy_live_rule_1':
        'Betalte filkreditter, du allerede har, gælder som 1 fil = 1 kredit, indtil de er brugt.',
    'credit_policy_live_rule_2':
        'Nye opladninger er pakker på 1 / 5 / 10 millioner tokens. Restkreditter og tokensaldo vises sammen.',
    'credit_policy_live_rule_3':
        'Et job bruger enten resterende filkreditter eller tokens — aldrig begge blandet.',
    'credit_policy_live_ads':
        'Belønningsannoncer fortsætter: 5 annoncer = 75.000 tokens. Daglige og ugentlige grænser er uændrede.',
    'credit_policy_live_ok': 'OK',
    'token_pack_coverage':
        'Cirka {movies} film eller {episodes} afsnit',

  },
};
