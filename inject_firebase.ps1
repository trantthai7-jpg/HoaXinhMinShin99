# Script to replace localStorage section with Firebase in index.html
$content = [System.IO.File]::ReadAllText("index.html")

# The localStorage-based JS code to find and replace
$oldCode = 'const STORAGE_KEY=''minshin_flowers_v1'';'

$newScript = @'
// ===== FIREBASE REALTIME DATABASE CONFIGURATION =====
// Thay YOUR_PROJECT_ID bằng ID project Firebase của bạn
// Hướng dẫn: https://console.firebase.google.com/
const FIREBASE_URL = 'https://minshin-flowers-default-rtdb.firebaseio.com';
const DB_PATH = '/flowers';

// ===== DATABASE FUNCTIONS =====
async function loadSaved() {
  try {
    const res = await fetch(FIREBASE_URL + DB_PATH + '.json');
    if (!res.ok) throw new Error('Network error');
    const data = await res.json();
    if (!data) return [];
    // Convert object to array
    return Object.entries(data).map(([id, item]) => ({ ...item, id }));
  } catch (e) {
    console.error('Firebase load error:', e);
    // Fallback to localStorage if Firebase fails
    try { return JSON.parse(localStorage.getItem('minshin_flowers_v1') || '[]'); } catch(e2){ return []; }
  }
}

async function saveSaved(items) {
  // This is called with the full array - we handle individual saves instead
}

async function saveItem(item) {
  try {
    const url = item.id 
      ? FIREBASE_URL + DB_PATH + '/' + item.id + '.json'
      : FIREBASE_URL + DB_PATH + '.json';
    const method = item.id ? 'PUT' : 'POST';
    const { id, ...data } = item;
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!res.ok) throw new Error('Save error');
    const result = await res.json();
    return item.id || result.name; // Firebase POST returns {name: 'generatedId'}
  } catch (e) {
    console.error('Firebase save error:', e);
    throw e;
  }
}

async function deleteItem(id) {
  try {
    const res = await fetch(FIREBASE_URL + DB_PATH + '/' + id + '.json', {
      method: 'DELETE'
    });
    if (!res.ok) throw new Error('Delete error');
  } catch (e) {
    console.error('Firebase delete error:', e);
    throw e;
  }
}

function showToast(msg, type='success') {
  let t = document.getElementById('fb-toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'fb-toast';
    t.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;padding:14px 22px;border-radius:14px;font:bold 14px Arial,sans-serif;color:#fff;opacity:0;transition:opacity .3s;max-width:340px;box-shadow:0 8px 30px rgba(0,0,0,.2)';
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.style.background = type==='error' ? '#c0392b' : '#27ae60';
  t.style.opacity = '1';
  clearTimeout(t._timer);
  t._timer = setTimeout(()=>{ t.style.opacity='0'; }, 3200);
}
'@

# Find and replace in the script section
$scriptStart = $content.LastIndexOf('<script>')
$scriptEnd = $content.LastIndexOf('</script>') + 9
$scriptContent = $content.Substring($scriptStart, $scriptEnd - $scriptStart)

Write-Host "Original script length: $($scriptContent.Length)"

# Replace STORAGE_KEY declaration with Firebase config
$newScriptContent = $scriptContent -replace "const STORAGE_KEY='minshin_flowers_v1';", $newScript

Write-Host "Modified script length: $($newScriptContent.Length)"

# Now replace the loadSaved and saveSaved functions  
# loadSaved: function loadSaved(){try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]')}catch(e){return []}}
$oldLoadSaved = "function loadSaved\(\){try\{return JSON\.parse\(localStorage\.getItem\(STORAGE_KEY\)\|\|'\[\]'\)\}catch\(e\)\{return \[\]\}\}"
$newLoadSaved = "// loadSaved replaced by async version above"
$newScriptContent = $newScriptContent -replace $oldLoadSaved, $newLoadSaved

# saveSaved
$oldSaveSaved = "function saveSaved\(items\)\{localStorage\.setItem\(STORAGE_KEY,JSON\.stringify\(items\)\);\}"
$newSaveSaved = "// saveSaved replaced by async version above"
$newScriptContent = $newScriptContent -replace $oldSaveSaved, $newSaveSaved

# Write the result
$newContent = $content.Substring(0, $scriptStart) + $newScriptContent + $content.Substring($scriptEnd)
[System.IO.File]::WriteAllText("index_firebase.html", $newContent)
Write-Host "Done! Written to index_firebase.html"
