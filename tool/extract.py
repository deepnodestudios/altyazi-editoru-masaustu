import io

with open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

# startBatchTranslationTest
start_idx = text.find('Future<void> startBatchTranslationTest(')
if start_idx != -1:
    end_idx = text.find('Future<void> stopTranslation(', start_idx)
    with open("extracted_batch.txt", "w", encoding="utf-8") as out:
        out.write(text[start_idx:end_idx if end_idx != -1 else start_idx + 8000])

text2 = text[text.find('Future<void> _checkBatchStatusLoop'):]
end_idx2 = text2.find('Future<void> _onBatchComplete')
if end_idx2 != -1:
    with open("extracted_batch_2.txt", "w", encoding="utf-8") as out:
        out.write(text2[:end_idx2 + 5000])
