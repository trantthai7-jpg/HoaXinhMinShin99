const fs = require('fs');
const content = fs.readFileSync('index.html', 'utf8');

// Find the script tag
const scriptStart = content.lastIndexOf('<script>');
const scriptEnd = content.lastIndexOf('</script>') + 9;
const scriptContent = content.slice(scriptStart, scriptEnd);

// Write script content to file
fs.writeFileSync('js_only.txt', scriptContent);

// Also check for the note about localStorage
const noteIdx = content.indexOf('LocalStorage');
console.log('localStorage note at char:', noteIdx);
console.log('Note context:', content.slice(noteIdx - 200, noteIdx + 200));
