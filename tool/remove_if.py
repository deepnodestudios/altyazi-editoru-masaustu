import re
import codecs

with codecs.open(r"lib\widgets\ai_panel\primary_actions_section.dart", "r", encoding="utf-8") as f:
    text = f.read()

# remove 'if (selectedFilesCount > 1 || controller.isCloudBatchMode) ...['
# We can find this string precisely.
target = "if (selectedFilesCount > 1 || controller.isCloudBatchMode) ...["

if target in text:
    lines = text.split('\n')
    new_lines = []
    skip_next_bracket = False
    for i, line in enumerate(lines):
        if target in line:
            # Skip this line
            continue
        # Check if it's the closing bracket of this exact spread.
        # It should be 12 spaces + '],'
        if line.strip() == "]," and "if (selectedFilesCount" in "\n".join(lines[max(0, i-60):i]): 
            # Very heuristic, let's just do a proper string replace.
            pass
            
with codecs.open("fix_script.py", "w", encoding="utf-8") as f:
    f.write("print('ready')")
