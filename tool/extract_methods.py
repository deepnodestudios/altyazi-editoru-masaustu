import re

with open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

def extract_method(name, is_future=False):
    if is_future:
        start_idx = text.find(f"Future<void> {name}(")
        if start_idx == -1: start_idx = text.find(f"Future<List<String>> {name}(")
        if start_idx == -1: start_idx = text.find(f"Future<Map<String, dynamic>> {name}(")
    else:
        start_idx = text.find(f"void {name}(")
    
    if start_idx == -1:
        return ""
        
    # very simple brace matching
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
    ("startBatchTranslationTest", True),
    ("_checkBatchStatusLoop", True),
    ("_onBatchComplete", True),
    ("_startBatchTimer", False),
    ("clearBatchResults", False),
]

out = ""
for m, is_f in methods:
    out += extract_method(m, is_f) + "\n\n"

with open("batch_methods.dart", "w", encoding="utf-8") as f:
    f.write(out)
