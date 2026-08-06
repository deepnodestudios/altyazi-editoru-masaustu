with open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

start_idx = text.find('Future<void> startBatchTranslationTest(')
end_idx = text.find('Future<void> stopTranslation(', start_idx)
with open("batch_test_method.txt", "w", encoding="utf-8") as out:
    out.write(text[start_idx:end_idx if end_idx != -1 else start_idx+10000])
