import re

with open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

def extract_method(name, prefix):
    start_idx = text.find(prefix)
    if start_idx == -1:
        return ""
        
    brace_count = 0
    in_method = False
    for i in range(start_idx, len(text)):
        if text[i] == '{':
            if not in_method:
                in_method = True
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if in_method and brace_count == 0:
                return text[start_idx:i+1]
    return ""

methods = [
    ("startBatchTranslationTest", "Future<void> startBatchTranslationTest("),
    ("_checkBatchStatusLoop", "Future<void> _checkBatchStatusLoop("),
    ("_onBatchComplete", "Future<void> _onBatchComplete("),
    ("_startBatchTimer", "void _startBatchTimer()"),
    ("clearBatchResults", "void clearBatchResults()"),
]

out = ""
for m, p in methods:
    out += extract_method(m, p) + "\n\n"

with open("batch_methods.dart", "w", encoding="utf-8") as f:
    f.write(out)
