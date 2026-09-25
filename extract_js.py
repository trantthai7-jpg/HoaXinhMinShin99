content = open('index.html', encoding='utf-8', errors='replace').read()
s = content.rfind('<script>')
e = content.rfind('</script>') + 9
js = content[s:e]
with open('script_section.txt', 'w', encoding='utf-8') as f:
    f.write(js)
print(f"Script section extracted: {len(js)} chars")
print("--- CONTENT ---")
print(js)
