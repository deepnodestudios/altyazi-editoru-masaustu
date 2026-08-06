import sys

with open(r"lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    orig_text = f.read()

with open("batch_test_method.txt", "r", encoding="utf-8") as f:
    batch_method_text = f.read()

# I also need the _isCloudBatchMode variable if it doesn't exist
if "_isCloudBatchMode" not in orig_text:
    orig_text = orig_text.replace(
        "bool _isBatchMode = false;",
        "bool _isBatchMode = false;\n  bool _isCloudBatchMode = false;\n  bool get isCloudBatchMode => _isCloudBatchMode;"
    )
    orig_text = orig_text.replace(
        "bool get isBatchProcessing => _isBatchMode;",
        "bool get isBatchProcessing => _isBatchMode || _isCloudBatchMode;"
    )

insert_idx = orig_text.find('Future<void> stopTranslation(')
if insert_idx == -1:
    print("Could not find stopTranslation")
    sys.exit(1)

new_text = orig_text[:insert_idx] + batch_method_text + "\n  " + orig_text[insert_idx:]

with open(r"lib\controllers\translation_controller.dart", "w", encoding="utf-8") as f:
    f.write(new_text)

print("Injected startBatchTranslationTest")
