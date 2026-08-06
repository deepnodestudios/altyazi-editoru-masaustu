import re

with open(r"lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Add activeBatchFilePaths, check where best
if "List<String> activeBatchFilePaths" not in text:
    text = text.replace("final Map<String, String> batchResults = {};", "final Map<String, String> batchResults = {};\n  final List<String> activeBatchFilePaths = [];")

# The replacement for Future<void> stopTranslation in my previous script probably failed
if "String _buildSessionChargeKey" not in text:
    func_text = """
  String _buildSessionChargeKey(String sourceHash, String targetLanguage) {     
    final now = DateTime.now().microsecondsSinceEpoch;
    final normalizedTarget = targetLanguage
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeTarget = normalizedTarget.isEmpty ? 'unknown' : normalizedTarget; 
    return 'run_${now}_${sourceHash}_$safeTarget';
  }
"""
    text = text.replace("Future<void> stopTranslation(", func_text + "\n\n  Future<void> stopTranslation(")

# fix rate us
text = text.replace("await _checkAndShowRateUs();", "// await _checkAndShowRateUs();")

# suppressNotification might be a parameter on _onLog or whatever method it was.
# E.g., `_saveTranslatedFile(..., suppressNotification: true)`
text = re.sub(r'suppressNotification:\s*true\s*,?', '', text)
text = re.sub(r'suppressNotification:\s*false\s*,?', '', text)

# clearBatchResults double definition
parts = text.split("void clearBatchResults() {")
if len(parts) > 2:
    # remove the second one. The second one ends with '}\n'
    # we can just use regex to remove exactly the block if it looks like `void clearBatchResults() {\n    batchResults.clear();\n    notifyListeners();\n  }`
    text = re.sub(r'void clearBatchResults\(\)\s*\{\s*batchResults\.clear\(\);\s*notifyListeners\(\);\s*\}', '', text, count=1)


with open(r"lib\controllers\translation_controller.dart", "w", encoding="utf-8") as f:
    f.write(text)

