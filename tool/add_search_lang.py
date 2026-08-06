import os
import glob
import re

for filepath in glob.glob("lib/translations/translations_*.dart"):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "'search_language_hint'" not in content:
        # Find editor_search_hint and add search_language_hint after it based on search_hint
        # We want proper translations. If we can't translate properly for 34 languages, we will just use english "Search language..." for others,
        # but wait! I can extract the word "Search" from editor_search_hint and append " language". 
        # Actually I can just copy the translation for 'search_hint' (Bulutta ara -> Bulutta ara), but remove the "Bulutta".
        
        # Let's just use empty string or fallback. 
        # Actually Google Translate or basic mapping is better. I'll just use English "Search language..." as default, 
        # but I will try to use the language's 'search_hint' word if possible.
        
        match = re.search(r"'search_hint':\s*'(.*?)'", content)
        if match:
            search_cloud = match.group(1) # e.g. "Bulutta ara"
            # It's better to just put a generic "Search..." from editor_search_hint!
            editor_match = re.search(r"'editor_search_hint':\s*'(.*?)'", content)
            
            if editor_match:
                search_word = editor_match.group(1).replace('...', '').strip()
                search_lang = search_word + "..."
            else:
                search_lang = "Search..."
                
            content = re.sub(r"(\s*)('editor_search_hint':\s*'.*?',)", r"\1\2\1'search_language_hint': '" + search_lang + "',", content)
            
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
        
print("Done")