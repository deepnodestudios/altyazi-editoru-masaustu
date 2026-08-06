import codecs

with open(r'lib\tabs\ai_panel.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_code = """            if (dontShowAgain) {
              await settings.setHideBatchTranslationInfo(true);
            }
          }

          if (!mounted) return;

          final files = pendingSelected.map((f) => File(f.path)).toList();"""

new_code = """            if (dontShowAgain) {
              await settings.setHideBatchTranslationInfo(true);
            }
          }

          if (!context.mounted) return;

          final files = pendingSelected.map((f) => File(f.path)).toList();"""

if old_code in text:
    text = text.replace(old_code, new_code)
    with open(r'lib\tabs\ai_panel.dart', 'w', encoding='utf-8') as f:
        f.write(text)
    print("Replaced!")
else:
    print("Not found.")
