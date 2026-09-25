$src = [System.IO.File]::ReadAllText("index.html")

# ===== STEP 1: Add Firebase config note in the admin note paragraph =====
$oldNote = 'Dữ liệu được lưu trên trình duyệt này bằng LocalStorage.'
$newNote = 'Dữ liệu được đồng bộ qua <b>Firebase Realtime Database</b> – máy khác cũng thấy hoa mới! 🌸'
$src = $src.Replace($oldNote, $newNote)
Write-Host "Step 1 done: $($src.Contains($newNote))"

# ===== STEP 2: Find script tag =====
$sIdx = $src.LastIndexOf('<script>')
$eIdx = $src.LastIndexOf('</script>') + 9
$js = $src.Substring($sIdx, $eIdx - $sIdx)
Write-Host "Script chars $sIdx to $eIdx, len=$($js.Length)"

# ===== STEP 3: Replace STORAGE_KEY line with Firebase config =====
$oldStorageKey = "const STORAGE_KEY='minshin_flowers_v1';"

$firebaseConfig = @"
// ===== FIREBASE DATABASE (đồng bộ dữ liệu giữa các máy) =====
  // Đã cấu hình sẵn – thêm hoa xong sẽ tự lưu online!
  const FIREBASE_URL = 'https://minshin-hoa-default-rtdb.asia-southeast1.firebasedatabase.app';
  const DB_PATH = '/flowers';
  const FIREBASE_KEY = 'AIzaSyDemo_placeholder'; // không cần API key cho Realtime DB public
  
  // ===== Toast notification =====
  function showDbToast(msg, type) {
    let t = document.getElementById('db-toast-notif');
    if (!t) {
      t = document.createElement('div');
      t.id = 'db-toast-notif';
      Object.assign(t.style, {position:'fixed',bottom:'24px',right:'24px',zIndex:'9999',
        padding:'13px 20px',borderRadius:'12px',font:'bold 13px Arial,sans-serif',
        color:'#fff',opacity:'0',transition:'opacity .35s',maxWidth:'320px',
        boxShadow:'0 8px 30px rgba(0,0,0,.22)',pointerEvents:'none'});
      document.body.appendChild(t);
    }
    t.textContent = msg;
    t.style.background = (type === 'error') ? '#e74c3c' : '#27ae60';
    t.style.opacity = '1';
    clearTimeout(t._t);
    t._t = setTimeout(() => { t.style.opacity = '0'; }, 3200);
  }

  // ===== Firebase REST API functions =====
  async function dbGet() {
    try {
      const r = await fetch(FIREBASE_URL + DB_PATH + '.json?orderBy="$key"', {cache: 'no-store'});
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const d = await r.json();
      if (!d || typeof d !== 'object') return [];
      return Object.entries(d).map(([fbId, item]) => ({ ...item, id: item.id || fbId }));
    } catch(e) {
      console.error('Firebase GET error:', e);
      return JSON.parse(localStorage.getItem('minshin_flowers_v1') || '[]');
    }
  }

  async function dbPost(item) {
    const { id, ...data } = item;
    const r = await fetch(FIREBASE_URL + DB_PATH + '.json', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ ...data, createdAt: Date.now() })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const result = await r.json();
    return result.name; // Firebase generated ID
  }

  async function dbPut(id, item) {
    const { id: _id, ...data } = item;
    const r = await fetch(FIREBASE_URL + DB_PATH + '/' + id + '.json', {
      method: 'PUT', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ ...data, updatedAt: Date.now() })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status);
  }

  async function dbDelete(id) {
    const r = await fetch(FIREBASE_URL + DB_PATH + '/' + id + '.json', { method: 'DELETE' });
    if (!r.ok) throw new Error('HTTP ' + r.status);
  }

  // ===== Compat wrappers (loadSaved / saveSaved not used anymore) =====
  function loadSaved() { return []; }    // sync version kept for safety
  function saveSaved() {}                // no-op
"@

if ($js.Contains($oldStorageKey)) {
    $js = $js.Replace($oldStorageKey, $firebaseConfig)
    Write-Host "Step 3 done: replaced STORAGE_KEY"
} else {
    Write-Host "WARNING: STORAGE_KEY not found!"
}

# ===== STEP 4: Replace loadSaved() sync usage =====
$oldLoadSaved = "function loadSaved(){try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]')}catch(e){return []}}"
if ($js.Contains($oldLoadSaved)) {
    $js = $js.Replace($oldLoadSaved, "// loadSaved() replaced by async dbGet() above")
    Write-Host "Step 4 done: replaced loadSaved"
} else {
    Write-Host "Step 4: loadSaved not found (may have already been replaced)"
}

# ===== STEP 5: Replace saveSaved() =====
$oldSaveSaved = "function saveSaved(items){localStorage.setItem(STORAGE_KEY,JSON.stringify(items));}"
if ($js.Contains($oldSaveSaved)) {
    $js = $js.Replace($oldSaveSaved, "// saveSaved() replaced by async dbPost/dbPut() above")
    Write-Host "Step 5 done: replaced saveSaved"
} else {
    Write-Host "Step 5: saveSaved not found"
}

# ===== STEP 6: Replace addSavedToData() function =====
# Find addSavedToData function
$addSavedIdx = $js.IndexOf("function addSavedToData(){")
Write-Host "addSavedToData found at: $addSavedIdx"

# ===== STEP 7: Replace renderAdminList() to use async =====
# Find the function that calls loadSaved in renderAdminList
$oldRenderAdmin = "function renderAdminList(){"
$newRenderAdmin = "async function renderAdminList(){"
if ($js.Contains($oldRenderAdmin)) {
    $js = $js.Replace($oldRenderAdmin, $newRenderAdmin)
    Write-Host "Step 7 done: made renderAdminList async"
}

# Replace: const items=loadSaved(); in renderAdminList context → const items=await dbGet();
# We need to replace the items=loadSaved() call in renderAdminList
$oldItemsLoad = "const items=loadSaved();"
$newItemsLoad = "const items=await dbGet();"
$count = ($js.Split($oldItemsLoad).Length - 1)
Write-Host "Found $count occurrences of 'const items=loadSaved();'"
$js = $js.Replace($oldItemsLoad, $newItemsLoad)
Write-Host "Step 8 done: replaced all 'const items=loadSaved()' with await dbGet()"

# ===== STEP 9: Replace form submit to use async save =====
# The form submit handler needs to be async and use dbPost/dbPut
# Find the save button event handler area
$oldFormSubmit = "form.addEventListener('submit',async e=>{"
if ($js.Contains($oldFormSubmit)) {
    Write-Host "Form submit already async"
} else {
    $js = $js.Replace("form.addEventListener('submit',e=>{", "form.addEventListener('submit',async e=>{")
    Write-Host "Step 9 done: made form submit async"
}

# ===== STEP 10: Replace saveSaved calls in form handler =====
# Find: saveSaved(items); and replace with Firebase calls
# The save flow: if editing (id exists) → PUT, else → POST
# Original: items.push(newItem); saveSaved(items);
# Original edit: item[key]=val; saveSaved(items);
$oldSaveNew = "items.push(newItem);saveSaved(items);"
$newSaveNew = @"
try {
        showDbToast('⏳ Đang lưu hoa lên Firebase...', 'info');
        const newId = await dbPost(newItem);
        newItem.id = newId;
        showDbToast('✅ Đã thêm hoa thành công!', 'success');
      } catch(e) {
        showDbToast('❌ Lỗi lưu: ' + e.message, 'error');
        return;
      }
"@
if ($js.Contains($oldSaveNew)) {
    $js = $js.Replace($oldSaveNew, $newSaveNew)
    Write-Host "Step 10a done: replaced push+saveSaved"
}

# ===== STEP 11: Replace delete handler =====
# Original: items.splice(idx,1);saveSaved(items);
$oldDelete = "items.splice(idx,1);saveSaved(items);"
$newDelete = @"
try {
          showDbToast('⏳ Đang xoá...', 'info');
          await dbDelete(del.dataset.delete);
          showDbToast('🗑️ Đã xoá hoa!', 'success');
        } catch(e) {
          showDbToast('❌ Lỗi xoá: ' + e.message, 'error');
          return;
        }
"@
if ($js.Contains($oldDelete)) {
    $js = $js.Replace($oldDelete, $newDelete)
    Write-Host "Step 11 done: replaced delete+saveSaved"
}

# ===== STEP 12: Find and replace the edit save logic =====
# When editing: item[key]=value; saveSaved(items);
# Find patterns related to editing an existing item
$editPattern = "saveSaved(items);"
if ($js.Contains($editPattern)) {
    Write-Host "Found remaining saveSaved(items) calls - replacing with dbPut"
    $js = $js.Replace($editPattern, @"
try {
          showDbToast('⏳ Đang cập nhật...', 'info');
          await dbPut(item.id, item);
          showDbToast('✅ Đã cập nhật hoa!', 'success');
        } catch(e) {
          showDbToast('❌ Lỗi cập nhật: ' + e.message, 'error');
        }
"@)
}

# ===== STEP 13: Replace addSavedToData function =====
# This function loaded saved items and added them to the data object
$oldAddSaved = "function addSavedToData(){"
$newAddSaved = "async function addSavedToData(){"
$js = $js.Replace($oldAddSaved, $newAddSaved)

# ===== STEP 14: Replace openAdmin to be async =====
$oldOpenAdmin = "function openAdmin(){"
$newOpenAdmin = "async function openAdmin(){"
$js = $js.Replace($oldOpenAdmin, $newOpenAdmin)

# ===== STEP 15: Replace addSavedToData() call with await =====
$js = $js.Replace("addSavedToData();renderAdminList();", "await addSavedToData();renderAdminList();")
$js = $js.Replace("addSavedToData();", "await addSavedToData();")

# ===== STEP 16: Make delete handler async =====
$oldAdminListClick = "adminList.addEventListener('click',e=>{"
$newAdminListClick = "adminList.addEventListener('click',async e=>{"
$js = $js.Replace($oldAdminListClick, $newAdminListClick)

# ===== Reconstruct HTML =====
$newContent = $src.Substring(0, $sIdx) + $js + $src.Substring($eIdx)

Write-Host "Writing output..."
[System.IO.File]::WriteAllText("index.html.firebase_backup", $src)
[System.IO.File]::WriteAllText("index.html", $newContent)
Write-Host "DONE! Backup saved as index.html.firebase_backup"
