// Tanıtım görselleri için uydurma (telifsiz) film adları ve diyaloglar.

const List<String> kTimes = [
  '00:00:02,000 --> 00:00:04,200',
  '00:00:04,400 --> 00:00:06,800',
  '00:00:07,000 --> 00:00:09,300',
  '00:00:09,600 --> 00:00:12,000',
  '00:00:12,400 --> 00:00:14,900',
  '00:00:15,200 --> 00:00:17,600',
  '00:00:18,000 --> 00:00:20,400',
  '00:00:20,700 --> 00:00:23,500',
  '00:00:23,900 --> 00:00:26,100',
  '00:00:26,400 --> 00:00:28,800',
  '00:00:29,200 --> 00:00:31,600',
  '00:00:32,000 --> 00:00:34,500',
];

/// "Starlight Cartographers" — kaynak (İngilizce).
const List<String> kStarlightEn = [
  'Hold the lantern higher, Mara.',
  'The old maps never showed this ridge.',
  'Maps only show what someone once dared to measure.',
  "Then we'll measure it ourselves.",
  'Look. The stars are lining up with the valley.',
  'My grandmother called it the Silver Road.',
  'Did she ever walk it?',
  "Once. She said it led somewhere\nthat isn't on any chart.",
  'No, the whole sky is turning.',
  'We are the ones standing still.',
  'Write it down. Every star, every step.',
  "Then let's map it together.",
];

const List<String> kStarlightTr = [
  'Feneri biraz daha yukarı tut, Mara.',
  'Eski haritalar bu sırtı hiç göstermemişti.',
  'Haritalar yalnızca birinin ölçmeye cesaret ettiği yerleri gösterir.',
  'O zaman biz kendimiz ölçeriz.',
  'Bak. Yıldızlar vadiyle aynı hizaya giriyor.',
  'Büyükannem buna Gümüş Yol derdi.',
  'Hiç bu yolda yürümüş mü?',
  'Bir kez. Hiçbir haritada olmayan\nbir yere çıktığını söylerdi.',
  'Hayır, bütün gökyüzü dönüyor.',
  'Duran biziz.',
  'Yaz bunu. Her yıldızı, her adımı.',
  'O zaman burayı birlikte haritalayalım.',
];

const List<String> kStarlightEs = [
  'Sostén el farol más alto, Mara.',
  'Los mapas antiguos nunca mostraron esta cresta.',
  'Los mapas solo muestran lo que alguien se atrevió a medir.',
  'Entonces lo mediremos nosotros.',
  'Mira. Las estrellas se alinean con el valle.',
  'Mi abuela lo llamaba el Camino de Plata.',
  '¿Alguna vez lo recorrió?',
  'Una vez. Decía que llevaba a un lugar\nque no aparece en ningún mapa.',
  'No, todo el cielo está girando.',
  'Somos nosotros los que estamos quietos.',
  'Anótalo. Cada estrella, cada paso.',
  'Entonces cartografiémoslo juntos.',
];

/// Editör sahnesi için ikinci uydurma diyalog ("Demo_Movie").
const List<String> kEditorTimes = [
  '00:00:02,000 --> 00:00:06,005',
  '00:00:06,400 --> 00:00:09,800',
  '00:00:10,760 --> 00:00:14,540',
  '00:00:15,000 --> 00:00:18,320',
  '00:00:18,900 --> 00:00:22,150',
  '00:00:22,600 --> 00:00:25,900',
  '00:00:26,300 --> 00:00:29,700',
  '00:00:30,100 --> 00:00:33,400',
];

const List<String> kEditorEn = [
  'Mira, wake up. The lighthouse lamp just went out.',
  'Again? That is the third time this week.',
  "Grab the lantern. I'll find the spare bulbs.",
  '- Is the storm getting closer?\n- It is already here.',
  'Ships are counting on that light tonight.',
  'Then we keep it burning, no matter what.',
  'Hand me the wrench. Quickly.',
  "There. Look at it shine. We did it.",
];

const List<String> kEditorTr = [
  'Mira, uyan. Deniz fenerinin lambası söndü.',
  'Yine mi? Bu hafta üçüncü oldu.',
  'Feneri al. Ben yedek ampulleri bulurum.',
  '- Fırtına yaklaşıyor mu?\n- Çoktan geldi bile.',
  'Bu gece gemiler o ışığa güveniyor.',
  'O zaman ne olursa olsun yanık tutacağız.',
  'İngiliz anahtarını ver. Çabuk.',
  'İşte. Şu parlayışa bak. Başardık.',
];

/// Geçmiş listesinde görünecek uydurma film adları.
const List<String> kHistoryTitles = [
  'Starlight Cartographers.srt',
  'Echoes of Paper Cities.srt',
  'Neon Harvest.srt',
  'Harbor of Lost Clocks.srt',
  'The Quiet Orchard.srt',
];

String buildSrt(List<String> times, List<String> lines) {
  final b = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    b
      ..writeln(i + 1)
      ..writeln(times[i])
      ..writeln(lines[i])
      ..writeln();
  }
  return b.toString();
}
