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
                # Need to verify if this is the start of the body or just a block in args.
                # Actually let's assume body starts AFTER 'async {' or ')' in standard forms.
                pass
            
            brace_count += 1
            in_method = True
        elif text[i] == '}':
            brace_count -= 1
            if in_method and brace_count == 0:
                return text[start_idx:i+1]
    return ""

def extract_method_better(name, prefix):
    start_idx = text.find(prefix)
    if start_idx == -1:
        return ""
    
    # find the open brace for the body. It follows ') {' or ') async {'
    # but could be params '{ ... }'
    cPos = start_idx
    parenCount = 0
    inParams = False
    
    for i in range(start_idx, len(text)):
        if text[i] == '(':
            if parenCount == 0:
                inParams = True
            parenCount += 1
        elif text[i] == ')':
            parenCount -= 1
            if inParams and parenCount == 0:
                inParams = False
                cPos = i
                break
                
    # Now find the first '{' after cPos
    bodyStart = text.find('{', cPos)
    if bodyStart == -1: return ""
    
    brace_count = 0
    for i in range(bodyStart, len(text)):
        if text[i] == '{':
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if brace_count == 0:
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
    out += extract_method_better(m, p) + "\n\n"

with open("batch_methods.dart", "w", encoding="utf-8") as f:
    f.write(out)
