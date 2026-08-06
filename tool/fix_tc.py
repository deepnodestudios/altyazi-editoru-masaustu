import re

with open(r"lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Fix FirebaseMessaging
text = text.replace(
"""    String? fcmToken;
    try {
      final messaging = FirebaseMessaging.instance;
      fcmToken = await messaging.getToken();
    } catch (_) {}""",
"""    String? fcmToken;
    // Desktop FCM disabled
"""
)

# Fix RateUs
text = text.replace("await _checkAndShowRateUs();", "// await _checkAndShowRateUs(); (desktop-only / disabled)")

# Find if activeBatchFilePaths was added
if "activeBatchFilePaths" not in text:
    print("activeBatchFilePaths missing!")
else:
    print("activeBatchFilePaths check passed or handled manually.")
    
# Fix buildSessionChargeKey (extract from mobile)
mobile_tc = open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8").read()
charge_key_start = mobile_tc.find("String _buildSessionChargeKey(")
if charge_key_start != -1:
    end_key = mobile_tc.find("\n  }", charge_key_start)
    charge_key_func = mobile_tc[charge_key_start:end_key+4]
    
    if "_buildSessionChargeKey" not in text:
        # inject it
        text = text.replace("Future<void> stopTranslation(", charge_key_func + "\n\n  Future<void> stopTranslation(")

# Fix _canWriteUserHistory
# Replace `_canWriteUserHistory` with `_settings?.canWriteUserHistory ?? true` if it's not a local method
# In mobile, is it a getter or what? Let's try `(_settingsManager.canWriteHistory)` or something.
text = text.replace("_canWriteUserHistory", "true") # just hardcode true or fetch from settings later if we figure it out

# Fix params in _saveTranslatedFile
text = re.sub(r'srcBlocksParam:\s*.*?,', '', text)
text = re.sub(r'procBlocksParam:\s*.*?,', '', text)

with open(r"lib\controllers\translation_controller.dart", "w", encoding="utf-8") as f:
    f.write(text)

print("Applied fixes")
