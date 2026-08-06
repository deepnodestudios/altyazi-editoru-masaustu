import re
with open(r"c:\Users\mehme\Desktop\altyazi_editoru\lib\controllers\translation_controller.dart", "r", encoding="utf-8") as f:
    text = f.read()

print("---PROPERTIES---")
for line in text.split('\n'):
    if 'Batch' in line and (line.strip().startswith('bool') or line.strip().startswith('final') or line.strip().startswith('int') or line.strip().startswith('Map') or line.strip().startswith('List')):
        if 'class' not in line:
            print(line.strip())
