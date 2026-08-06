import codecs
import re

with open(r'lib\app_settings.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add variable
if 'bool _hideBatchTranslationInfo' not in text:
    text = text.replace('bool _hideInfoButtons = false;', 'bool _hideInfoButtons = false;\n  bool _hideBatchTranslationInfo = false;')

# 2. Add getter
if 'bool get hideBatchTranslationInfo' not in text:
    text = text.replace('bool get hideInfoButtons => _hideInfoButtons;', 'bool get hideInfoButtons => _hideInfoButtons;\n  bool get hideBatchTranslationInfo => _hideBatchTranslationInfo;')

# 3. Modify setHideInfoButtons and add setHideBatchTranslationInfo
old_setter = """  Future<void> setHideInfoButtons(bool value) async {
    _hideInfoButtons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_info_buttons', value);
    notifyListeners();
  }"""

new_setter = """  Future<void> setHideInfoButtons(bool value) async {
    _hideInfoButtons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_info_buttons', value);
    if (!value) {
      _hideBatchTranslationInfo = false;
      await prefs.setBool('hide_batch_info', false);
    }
    notifyListeners();
  }

  Future<void> setHideBatchTranslationInfo(bool value) async {
    _hideBatchTranslationInfo = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_batch_info', value);
    notifyListeners();
  }"""
if 'setHideBatchTranslationInfo' not in text:
    text = text.replace(old_setter, new_setter)

# 4. Modify load from prefs
old_load = "_hideInfoButtons = prefs.getBool('hide_info_buttons') ?? false;"
new_load = "_hideInfoButtons = prefs.getBool('hide_info_buttons') ?? false;\n    _hideBatchTranslationInfo = prefs.getBool('hide_batch_info') ?? false;"
if '_hideBatchTranslationInfo = prefs.getBool(' not in text:
    text = text.replace(old_load, new_load)

with open(r'lib\app_settings.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated app_settings.dart")
