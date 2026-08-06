import sys

with open(r"lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

with open("batch_methods.dart", "r", encoding="utf-8") as f:
    methods = f.read()

# Add _isCloudBatchMode
if "_isCloudBatchMode" not in text:
    text = text.replace(
        "bool _isBatchMode = false;\n  bool get isBatchProcessing => _isBatchMode;",
        "bool _isBatchMode = false;\n  bool _isCloudBatchMode = false;\n  bool get isCloudBatchMode => _isCloudBatchMode;\n  bool get isBatchProcessing => _isBatchMode || _isCloudBatchMode;"
    )

# activeBatchFilePaths, batchResults are not existing in desktop? Let's check:
if "Map<String, String> batchResults" not in text:
    text = text.replace(
        "final List<String> _batchCompletedPaths = [];",
        "final Map<String, String> batchResults = {};\n  final List<String> activeBatchFilePaths = [];\n  final List<String> _batchCompletedPaths = [];"
    )

# the original mobile startBatchTranslationTest references `startBatchTranslationTest`
# Replace the nameToUse in _updateHistory
text = text.replace(
    "final nameToUse = _isBatchMode",
    "final nameToUse = (_isBatchMode || _isCloudBatchMode)"
)

# Insert the methods
insert_pos = text.find("Future<void> stopTranslation(")
if insert_pos == -1:
    print("Error finding stopTranslation")
    sys.exit(1)

new_text = text[:insert_pos] + "\n\n" + methods + "\n\n  " + text[insert_pos:]

with open(r"lib\controllers\translation_controller.dart", "w", encoding="utf-8") as f:
    f.write(new_text)

print("Patch applied successfully.")
