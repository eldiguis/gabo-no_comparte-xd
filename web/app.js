/**
 * MODO Store Admin — Optimized Web Controller
 * Project: modo-31d0e
 */

// 1. Firebase Configuration
const firebaseConfig = {
  projectId: "modo-31d0e",
  appId: "1:1061048654903:web:4276630759dfb5f2deb3b2",
  databaseURL: "https://modo-31d0e-default-rtdb.firebaseio.com",
  storageBucket: "modo-31d0e.firebasestorage.app",
  apiKey: "AIzaSyBoSe_Wp83gBdFgq4Je-w3zQRnKT4iqHiw",
  authDomain: "modo-31d0e.firebaseapp.com",
  messagingSenderId: "1061048654903",
  measurementId: "G-ZRX46K7ZMN"
};

let db = null;
let auth = null;

try {
  if (typeof firebase !== 'undefined') {
    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }
    db = firebase.firestore();
    auth = firebase.auth();
  }
} catch (err) {
  console.error('[Firebase Init Error]', err);
}

// 2. Constants & State
const CACHE_KEY = 'modo_admin_products_cache';
const CACHE_TIMESTAMP_KEY = 'modo_admin_cache_time';
const CATEGORIES_KEY = 'modo_admin_categories';
const CACHE_TTL_MS = 3 * 60 * 1000; // 3 minutes

const DEFAULT_CATEGORIES = ['Hombre', 'Mujer', 'Niños', 'Niñas', 'Accesorios'];
let customCategories = [...DEFAULT_CATEGORIES];
let isDemoMode = false;

const STORE_LABELS = {
  store_real_plaza_huancayo: 'Real Plaza Huancayo',
  store_open_plaza_huancayo: 'Open Plaza Huancayo',
  store_plaza_constitucion: 'Centro Huancayo',
  // Compatibilidad con registros anteriores
  store_jockey: 'Real Plaza Huancayo',
  store_salaverry: 'Open Plaza Huancayo',
  store_san_miguel: 'Centro Huancayo'
};

function normalizeStoreId(rawStore) {
  if (rawStore === 'store_jockey') return 'store_real_plaza_huancayo';
  if (rawStore === 'store_salaverry') return 'store_open_plaza_huancayo';
  if (rawStore === 'store_san_miguel') return 'store_plaza_constitucion';
  return rawStore || 'store_real_plaza_huancayo';
}

const SVG_FALLBACK_IMAGE = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='120' height='150' fill='%23898780'><rect width='120' height='150' fill='%23faf9f6'/><text x='50%' y='50%' text-anchor='middle' dy='.3em' font-family='sans-serif' font-size='11'>Sin imagen</text></svg>";

let allProducts = [];
let filteredProducts = [];
let currentPage = 0;
let pageSize = 8;
let editingId = null;
let deletingId = null;
let searchDebounceTimer = null;
let currentUser = null;
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// 3. DOM Elements
const loginView = document.getElementById('loginView');
const dashboardView = document.getElementById('dashboardView');
const emailLoginForm = document.getElementById('emailLoginForm');
const adminEmailInput = document.getElementById('adminEmail');
const adminPasswordInput = document.getElementById('adminPassword');
const googleLoginBtn = document.getElementById('googleLoginBtn');
const demoLoginBtn = document.getElementById('demoLoginBtn');
const loginError = document.getElementById('loginError');
const sessionBadge = document.getElementById('sessionBadge');
const sessionLabel = document.getElementById('sessionLabel');
const logoutBtn = document.getElementById('logoutBtn');

const productForm = document.getElementById('productForm');
const formTitle = document.getElementById('formTitle');
const cancelEditBtn = document.getElementById('cancelEditBtn');
const saveProductBtn = document.getElementById('saveProductBtn');
const imageInput = document.getElementById('image');
const imagePreview = document.getElementById('imagePreview');
const imagePreviewWrap = document.getElementById('imagePreviewWrap');

function updateImagePreview(url) {
  const cleanUrl = cleanString(url);
  if (!imagePreview || !imagePreviewWrap) return;
  if (!cleanUrl) {
    imagePreview.removeAttribute('src');
    imagePreviewWrap.classList.add('hidden');
  } else {
    imagePreview.src = cleanUrl;
    imagePreviewWrap.classList.remove('hidden');
  }
}

const productsBody = document.getElementById('productsBody');
const searchInput = document.getElementById('searchInput');
const searchClearBtn = document.getElementById('searchClearBtn');
const categoryFilter = document.getElementById('categoryFilter');
const categorySelect = document.getElementById('category');
const storeFilter = document.getElementById('storeFilter');
const sortFilter = document.getElementById('sortFilter');
const pageSizeSelect = document.getElementById('pageSizeSelect');

const manageCategoriesBtn = document.getElementById('manageCategoriesBtn');
const categoriesModal = document.getElementById('categoriesModal');
const newCategoryInput = document.getElementById('newCategoryInput');
const addCategoryBtn = document.getElementById('addCategoryBtn');
const categoriesTableBody = document.getElementById('categoriesTableBody');
const closeCategoriesBtn = document.getElementById('closeCategoriesBtn');

const statTotal = document.getElementById('statTotal');
const statCats = document.getElementById('statCats');
const pagerInfo = document.getElementById('pagerInfo');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const pageDots = document.getElementById('pageDots');

const deleteModal = document.getElementById('deleteModal');
const deleteModalDesc = document.getElementById('deleteModalDesc');
const deleteCancelBtn = document.getElementById('deleteCancelBtn');
const deleteConfirmBtn = document.getElementById('deleteConfirmBtn');

const loadingOverlay = document.getElementById('loadingOverlay');
const loadingText = document.getElementById('loadingText');
const toastContainer = document.getElementById('toastContainer');

// 4. Utility Functions
function withTimeout(promise, ms, fallbackMsg = 'Tiempo de espera agotado') {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(fallbackMsg)), ms))
  ]);
}

async function checkFirebaseHealth() {
  const dot = document.getElementById('firebaseHealthDot');
  const text = document.getElementById('firebaseHealthText');
  if (!db) {
    if (dot) dot.style.background = '#f39c12';
    if (text) text.textContent = 'Modo Local (Offline)';
    return;
  }
  const start = Date.now();
  try {
    await withTimeout(db.collection('productos').limit(1).get(), 3500, 'Timeout');
    const ms = Date.now() - start;
    if (dot) dot.style.background = '#27ae60';
    if (text) text.textContent = `Firebase OK (${ms}ms)`;
  } catch (err) {
    if (dot) dot.style.background = '#f39c12';
    if (text) text.textContent = 'Modo Local / Lento';
  }
}

function showToast(message, type = 'success') {
  if (!toastContainer) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  toastContainer.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 250);
  }, 3200);
}

function showLoading(text = 'Cargando catálogo…') {
  if (loadingOverlay) {
    if (loadingText) loadingText.textContent = text;
    loadingOverlay.classList.remove('hidden');
  }
}

function hideLoading() {
  if (loadingOverlay) loadingOverlay.classList.add('hidden');
}

function showView(name) {
  document.querySelectorAll('.view').forEach(v => {
    v.classList.remove('active');
    v.style.display = 'none';
  });
  const el = document.getElementById(name);
  if (el) {
    el.style.display = 'block';
    el.classList.add('active');
  }
}

function cleanString(val) {
  return typeof val === 'string' ? val.trim() : '';
}

function formatPriceDisplay(price) {
  if (typeof price === 'number') {
    return `S/ ${price.toFixed(2)}`;
  }
  const str = cleanString(price);
  if (!str) return 'S/ 0';
  if (str.startsWith('S/')) return str;
  return `S/ ${str}`;
}

function parsePriceNumber(price) {
  if (typeof price === 'number') return price;
  const num = parseFloat(String(price).replace(/[^\d.-]/g, ''));
  return isNaN(num) ? 0 : num;
}

// 5. Cache Layer
function getCachedProducts() {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    const time = localStorage.getItem(CACHE_TIMESTAMP_KEY);
    if (!raw || !time) return null;
    if (Date.now() - parseInt(time, 10) > CACHE_TTL_MS) {
      localStorage.removeItem(CACHE_KEY);
      localStorage.removeItem(CACHE_TIMESTAMP_KEY);
      return null;
    }
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

function setCachedProducts(items) {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(items));
    localStorage.setItem(CACHE_TIMESTAMP_KEY, Date.now().toString());
  } catch (_) {}
}

function invalidateCache() {
  try {
    localStorage.removeItem(CACHE_KEY);
    localStorage.removeItem(CACHE_TIMESTAMP_KEY);
  } catch (_) {}
}

// 6. Firestore Catalog Service
async function fetchProductsFromFirestore() {
  if (!db) throw new Error('Firestore no está disponible.');
  const snapshot = await db.collection('productos').get();
  const items = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      id: doc.id,
      name: d.name || d.nombre || 'Prenda sin nombre',
      category: d.category || d.categoria || 'Hombre',
      price: d.price || d.precio || '0',
      image: d.image || d.imageUrl || d.imagen || SVG_FALLBACK_IMAGE,
      store: d.tienda || d.store || 'store_jockey',
      tag: d.tag || d.etiqueta || '',
      color: d.color || '',
      sizes: Array.isArray(d.sizes) ? d.sizes : (typeof d.sizes === 'string' ? d.sizes.split(',').map(s => s.trim()).filter(Boolean) : []),
      material: d.material || '',
      fit: d.fit || '',
      care: d.care || '',
      description: d.description || '',
      updatedAt: d.updatedAt || null
    };
  });
  return items;
}

async function loadProducts(forceRefresh = false) {
  showLoading('Obteniendo prendas...');
  try {
    if (isDemoMode) {
      const cached = getCachedProducts();
      if (cached && Array.isArray(cached) && cached.length > 0) {
        allProducts = cached;
      } else if (Array.isArray(window.SEED_PRODUCTS_50)) {
        allProducts = window.SEED_PRODUCTS_50.map(p => ({ ...p }));
        setCachedProducts(allProducts);
      }
      syncCategoriesFromProducts();
      applyFilters();
      return;
    }

    if (!forceRefresh) {
      const cached = getCachedProducts();
      if (cached && Array.isArray(cached) && cached.length > 0) {
        allProducts = cached;
        syncCategoriesFromProducts();
        applyFilters();
        hideLoading();
        return;
      }
    }
    allProducts = await withTimeout(fetchProductsFromFirestore(), 4500, 'Tiempo de espera agotado');
    if (allProducts.length === 0 && Array.isArray(window.SEED_PRODUCTS_50)) {
      allProducts = window.SEED_PRODUCTS_50.map(p => ({ ...p }));
    }
    setCachedProducts(allProducts);
    syncCategoriesFromProducts();
    applyFilters();
  } catch (err) {
    console.warn('[LoadProducts Fallback]', err);
    const cached = getCachedProducts();
    if (cached && Array.isArray(cached) && cached.length > 0) {
      allProducts = cached;
    } else if (Array.isArray(window.SEED_PRODUCTS_50)) {
      allProducts = window.SEED_PRODUCTS_50.map(p => ({ ...p }));
    }
    syncCategoriesFromProducts();
    applyFilters();
    showToast('Cargado catálogo local (' + (err.message || 'offline') + ')', 'error');
  } finally {
    hideLoading();
  }
}

// 6.5 Category Management
function loadSavedCategories() {
  try {
    const raw = localStorage.getItem(CATEGORIES_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) {
        customCategories = parsed;
        return;
      }
    }
  } catch (_) {}
  customCategories = [...DEFAULT_CATEGORIES];
}

function saveCategoriesLocal() {
  try {
    localStorage.setItem(CATEGORIES_KEY, JSON.stringify(customCategories));
  } catch (_) {}
}

function syncCategoriesFromProducts() {
  loadSavedCategories();
  const productCats = allProducts.map(p => cleanString(p.category)).filter(Boolean);
  let changed = false;
  productCats.forEach(c => {
    if (!customCategories.includes(c)) {
      customCategories.push(c);
      changed = true;
    }
  });
  if (changed) saveCategoriesLocal();
  renderCategorySelects();
}

function renderCategorySelects() {
  if (categorySelect) {
    const prevVal = categorySelect.value;
    categorySelect.innerHTML = '';
    customCategories.forEach(cat => {
      const opt = document.createElement('option');
      opt.value = cat;
      opt.textContent = cat;
      categorySelect.appendChild(opt);
    });
    if (customCategories.includes(prevVal)) {
      categorySelect.value = prevVal;
    }
  }
  if (categoryFilter) {
    const prevFilter = categoryFilter.value;
    categoryFilter.innerHTML = '<option value="">Todas las categorías</option>';
    customCategories.forEach(cat => {
      const opt = document.createElement('option');
      opt.value = cat;
      opt.textContent = cat;
      categoryFilter.appendChild(opt);
    });
    if (customCategories.includes(prevFilter) || prevFilter === '') {
      categoryFilter.value = prevFilter;
    }
  }
}

function renderCategoriesModal() {
  if (!categoriesTableBody) return;
  categoriesTableBody.innerHTML = '';
  customCategories.forEach(cat => {
    const count = allProducts.filter(p => p.category === cat).length;
    const tr = document.createElement('tr');
    tr.style.borderBottom = '1px solid var(--line)';
    tr.innerHTML = `
      <td style="padding: 10px 12px; font-weight: 600;">${cat}</td>
      <td style="padding: 10px 12px; text-align: center;"><span class="badge">${count}</span></td>
      <td style="padding: 10px 12px; text-align: right;">
        <button type="button" class="btn sm" data-cat-action="rename" data-cat="${cat}">Editar</button>
        <button type="button" class="btn sm danger" data-cat-action="delete" data-cat="${cat}" style="margin-left:4px;">Eliminar</button>
      </td>
    `;
    categoriesTableBody.appendChild(tr);
  });
}

async function renameCategoryGlobal(oldName, newName) {
  const cleanNew = cleanString(newName);
  if (!cleanNew || cleanNew === oldName) return;
  if (customCategories.includes(cleanNew)) {
    showToast(`La categoría "${cleanNew}" ya existe.`, 'error');
    return;
  }

  const idx = customCategories.indexOf(oldName);
  if (idx !== -1) customCategories[idx] = cleanNew;
  saveCategoriesLocal();

  // Update products locally and in Firestore
  const affected = allProducts.filter(p => p.category === oldName);
  affected.forEach(p => { p.category = cleanNew; });
  setCachedProducts(allProducts);

  if (db && !isDemoMode && affected.length > 0) {
    showLoading(`Actualizando ${affected.length} prendas…`);
    try {
      const batch = db.batch();
      affected.forEach(p => {
        const ref = db.collection('productos').doc(p.id);
        batch.update(ref, { category: cleanNew, categoria: cleanNew });
      });
      await batch.commit();
    } catch (err) {
      console.warn('Error actualizando categoría en Firestore:', err);
    } finally {
      hideLoading();
    }
  }

  renderCategorySelects();
  renderCategoriesModal();
  applyFilters();
  showToast(`Categoría "${oldName}" renombrada a "${cleanNew}".`);
}

function deleteCategoryGlobal(catName) {
  const count = allProducts.filter(p => p.category === catName).length;
  if (count > 0) {
    showToast(`No puedes eliminar "${catName}" porque tiene ${count} prendas asignadas.`, 'error');
    return;
  }
  customCategories = customCategories.filter(c => c !== catName);
  saveCategoriesLocal();
  renderCategorySelects();
  renderCategoriesModal();
  showToast(`Categoría "${catName}" eliminada.`);
}

// 7. Filtering, Sorting & Pagination
function applyFilters() {
  const query = cleanString(searchInput.value).toLowerCase();
  const cat = categoryFilter.value;
  const store = storeFilter.value;
  const sort = sortFilter.value;

  filteredProducts = allProducts.filter(item => {
    if (cat && item.category !== cat) return false;
    if (store && normalizeStoreId(item.store) !== store) return false;
    if (query) {
      const matchName = item.name.toLowerCase().includes(query);
      const matchTag = item.tag.toLowerCase().includes(query);
      const matchColor = item.color.toLowerCase().includes(query);
      if (!matchName && !matchTag && !matchColor) return false;
    }
    return true;
  });

  // Sorting
  filteredProducts.sort((a, b) => {
    if (sort === 'price_asc') return parsePriceNumber(a.price) - parsePriceNumber(b.price);
    if (sort === 'price_desc') return parsePriceNumber(b.price) - parsePriceNumber(a.price);
    if (sort === 'name_asc') return a.name.localeCompare(b.name);
    return 0; // newest / default order
  });

  currentPage = 0;
  updateStats();
  renderTable();
  updatePager();
}

function updateStats() {
  if (statTotal) statTotal.textContent = allProducts.length;
  if (statCats) {
    const cats = new Set(allProducts.map(p => p.category));
    statCats.textContent = cats.size;
  }
}

function renderTable() {
  if (!productsBody) return;
  productsBody.innerHTML = '';

  if (filteredProducts.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="6" style="text-align:center;padding:36px;color:var(--muted);">No se encontraron prendas con los filtros aplicados.</td>`;
    productsBody.appendChild(tr);
    return;
  }

  const start = currentPage * pageSize;
  const pageItems = filteredProducts.slice(start, start + pageSize);

  pageItems.forEach(item => {
    const tr = document.createElement('tr');
    const storeLabel = STORE_LABELS[item.store] || item.store;
    const tagBadge = item.tag ? `<span class="badge lime" style="margin-left:6px;">${item.tag}</span>` : '';

    tr.innerHTML = `
      <td>
        <img class="product-thumb" src="${item.image || SVG_FALLBACK_IMAGE}" alt="${item.name}" loading="lazy" onerror="this.src='${SVG_FALLBACK_IMAGE}';" />
      </td>
      <td>
        <strong>${item.name}</strong>
        ${tagBadge}
        ${item.color ? `<div class="muted" style="font-size:12px;">Color: ${item.color}</div>` : ''}
      </td>
      <td><span class="badge">${item.category}</span></td>
      <td><strong>${formatPriceDisplay(item.price)}</strong></td>
      <td><span class="muted">${storeLabel}</span></td>
      <td>
        <div class="actions-cell">
          <button type="button" class="btn sm" data-action="edit" data-id="${item.id}">Editar</button>
          <button type="button" class="btn sm danger" data-action="delete" data-id="${item.id}">Eliminar</button>
        </div>
      </td>
    `;
    productsBody.appendChild(tr);
  });
}

function updatePager() {
  const total = filteredProducts.length;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  if (pagerInfo) {
    if (total === 0) {
      pagerInfo.textContent = 'Mostrando 0 prendas';
    } else {
      const start = currentPage * pageSize + 1;
      const end = Math.min((currentPage + 1) * pageSize, total);
      pagerInfo.textContent = `Mostrando ${start}–${end} de ${total} prendas`;
    }
  }

  if (prevPageBtn) prevPageBtn.disabled = currentPage === 0;
  if (nextPageBtn) nextPageBtn.disabled = currentPage >= totalPages - 1;

  if (pageDots) {
    pageDots.innerHTML = '';
    const maxDots = 5;
    let startPage = Math.max(0, currentPage - 2);
    let endPage = Math.min(totalPages, startPage + maxDots);
    if (endPage - startPage < maxDots) {
      startPage = Math.max(0, endPage - maxDots);
    }

    for (let i = startPage; i < endPage; i++) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `page-dot ${i === currentPage ? 'active' : ''}`;
      btn.textContent = (i + 1).toString();
      btn.addEventListener('click', () => {
        currentPage = i;
        renderTable();
        updatePager();
      });
      pageDots.appendChild(btn);
    }
  }
}

// 8. Product Actions (CRUD)
function startEdit(id) {
  const p = allProducts.find(x => x.id === id);
  if (!p) {
    showToast('No se encontró la prenda para editar.', 'error');
    return;
  }
  editingId = id;

  if (formTitle) formTitle.textContent = 'Editar prenda';
  if (saveProductBtn) saveProductBtn.textContent = 'Actualizar prenda';
  if (cancelEditBtn) cancelEditBtn.classList.remove('hidden');

  document.getElementById('productId').value = id;
  const nameEl = document.getElementById('name');
  if (nameEl) nameEl.value = p.name || '';

  const catEl = document.getElementById('category');
  if (catEl) {
    const catVal = p.category || 'Hombre';
    if (!Array.from(catEl.options).some(opt => opt.value === catVal)) {
      const opt = document.createElement('option');
      opt.value = catVal;
      opt.textContent = catVal;
      catEl.appendChild(opt);
    }
    catEl.value = catVal;
  }

  document.getElementById('price').value = p.price || '';
  const imgUrl = (p.image && !p.image.startsWith('data:image/svg')) ? p.image : '';
  document.getElementById('image').value = imgUrl;
  updateImagePreview(imgUrl);

  const storeEl = document.getElementById('store');
  if (storeEl) {
    storeEl.value = normalizeStoreId(p.store);
  }

  document.getElementById('tag').value = p.tag || '';
  document.getElementById('color').value = p.color || '';
  document.getElementById('sizes').value = Array.isArray(p.sizes)
    ? p.sizes.join(', ')
    : (typeof p.sizes === 'string' ? p.sizes : '');
  document.getElementById('material').value = p.material || '';
  document.getElementById('fit').value = p.fit || '';
  document.getElementById('care').value = p.care || '';
  document.getElementById('description').value = p.description || '';

  if (productForm) {
    productForm.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  if (nameEl) nameEl.focus();
}

function resetForm() {
  editingId = null;
  if (formTitle) formTitle.textContent = 'Agregar prenda';
  if (saveProductBtn) saveProductBtn.textContent = 'Guardar prenda';
  if (cancelEditBtn) cancelEditBtn.classList.add('hidden');
  productForm.reset();
  document.getElementById('productId').value = '';
  updateImagePreview('');
}

productForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!db && !isDemoMode) {
    showToast('Firestore no está disponible', 'error');
    return;
  }

  const nameVal = cleanString(document.getElementById('name').value);
  const catVal = cleanString(document.getElementById('category').value);
  const priceVal = cleanString(document.getElementById('price').value);
  const imageVal = cleanString(document.getElementById('image').value);
  const storeVal = cleanString(document.getElementById('store').value);
  const tagVal = cleanString(document.getElementById('tag').value);
  const colorVal = cleanString(document.getElementById('color').value);
  const sizesRaw = cleanString(document.getElementById('sizes').value);
  const sizesArr = sizesRaw ? sizesRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
  const materialVal = cleanString(document.getElementById('material').value);
  const fitVal = cleanString(document.getElementById('fit').value);
  const careVal = cleanString(document.getElementById('care').value);
  const descVal = cleanString(document.getElementById('description').value);

  // Synchronized bilingual payload for full Flutter compatibility
  const payload = {
    name: nameVal,
    nombre: nameVal,
    category: catVal,
    categoria: catVal,
    price: priceVal,
    precio: priceVal,
    image: imageVal,
    imageUrl: imageVal,
    imagen: imageVal,
    store: storeVal,
    tienda: storeVal,
    tag: tagVal || catVal,
    etiqueta: tagVal || catVal,
    sizes: sizesArr,
    color: colorVal,
    material: materialVal,
    fit: fitVal,
    care: careVal,
    description: descVal
  };

  if (isDemoMode || !db) {
    if (editingId) {
      const idx = allProducts.findIndex(x => x.id === editingId);
      if (idx !== -1) {
        allProducts[idx] = { ...allProducts[idx], ...payload, id: editingId };
      }
      showToast(`"${nameVal}" actualizada en modo local.`);
    } else {
      const newId = 'prod_local_' + Date.now();
      allProducts.unshift({ ...payload, id: newId });
      showToast(`"${nameVal}" agregada en modo local.`);
    }
    setCachedProducts(allProducts);
    resetForm();
    syncCategoriesFromProducts();
    applyFilters();
    return;
  }

  payload.updatedAt = firebase.firestore.FieldValue.serverTimestamp();
  showLoading(editingId ? 'Actualizando prenda…' : 'Guardando prenda…');
  try {
    if (editingId) {
      await db.collection('productos').doc(editingId).set(payload, { merge: true });
      showToast(`"${nameVal}" actualizada con éxito.`);
    } else {
      payload.createdAt = firebase.firestore.FieldValue.serverTimestamp();
      await db.collection('productos').add(payload);
      showToast(`"${nameVal}" agregada al catálogo.`);
    }
    resetForm();
    invalidateCache();
    await loadProducts(true);
  } catch (err) {
    showToast('Error al guardar: ' + err.message, 'error');
  } finally {
    hideLoading();
  }
});

// Table delegate for Edit / Delete actions
productsBody.addEventListener('click', (e) => {
  const target = e.target.closest('button');
  if (!target) return;
  const action = target.getAttribute('data-action');
  const id = target.getAttribute('data-id');
  if (!id) return;

  if (action === 'edit') {
    startEdit(id);
  } else if (action === 'delete') {
    const item = allProducts.find(x => x.id === id);
    deletingId = id;
    if (deleteModalDesc) {
      deleteModalDesc.textContent = `¿Estás seguro de eliminar "${item ? item.name : 'esta prenda'}"? Esta acción no se puede deshacer.`;
    }
    deleteModal.classList.remove('hidden');
  }
});

deleteCancelBtn.addEventListener('click', () => {
  deletingId = null;
  deleteModal.classList.add('hidden');
});

deleteConfirmBtn.addEventListener('click', async () => {
  if (!deletingId) return;
  deleteModal.classList.add('hidden');
  if (isDemoMode || !db) {
    allProducts = allProducts.filter(x => x.id !== deletingId);
    setCachedProducts(allProducts);
    deletingId = null;
    applyFilters();
    showToast('Prenda eliminada en modo local.');
    return;
  }
  showLoading('Eliminando prenda…');
  try {
    await db.collection('productos').doc(deletingId).delete();
    showToast('Prenda eliminada del catálogo.');
    deletingId = null;
    invalidateCache();
    await loadProducts(true);
  } catch (err) {
    showToast('Error al eliminar: ' + err.message, 'error');
  } finally {
    hideLoading();
  }
});

// Seed 50 products action
const seed50Btn = document.getElementById('seed50Btn');
if (seed50Btn) {
  seed50Btn.addEventListener('click', async () => {
    if (!db) {
      showToast('Firestore no está disponible.', 'error');
      return;
    }
    const list = window.SEED_PRODUCTS_50;
    if (!list || !Array.isArray(list) || list.length === 0) {
      showToast('No se encontraron los datos del seed.', 'error');
      return;
    }
    if (!confirm(`¿Deseas poblar Firestore con ${list.length} prendas oficiales (Hombre, Mujer, Niños, Niñas, Accesorios)?`)) {
      return;
    }
    showLoading(`Sembrando ${list.length} prendas en Firestore…`);
    try {
      const batch = db.batch();
      list.forEach(item => {
        const docRef = db.collection('productos').doc(item.id);
        const docData = Object.assign({}, item, {
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        batch.set(docRef, docData, { merge: true });
      });
      await batch.commit();
      showToast(`¡${list.length} prendas sembradas con éxito!`);
      invalidateCache();
      await loadProducts(true);
    } catch (err) {
      showToast('Error sembrando catálogo: ' + err.message, 'error');
    } finally {
      hideLoading();
    }
  });
}

cancelEditBtn.addEventListener('click', resetForm);

// Image preview live update with error handling
imageInput.addEventListener('input', (e) => {
  updateImagePreview(e.target.value);
});
imagePreview.addEventListener('error', () => {
  if (imagePreviewWrap) imagePreviewWrap.classList.add('hidden');
});

// Search input debounced
searchInput.addEventListener('input', () => {
  if (searchClearBtn) {
    searchClearBtn.classList.toggle('visible', searchInput.value.length > 0);
  }
  clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(applyFilters, 280);
});

searchClearBtn.addEventListener('click', () => {
  searchInput.value = '';
  searchClearBtn.classList.remove('visible');
  applyFilters();
});

categoryFilter.addEventListener('change', applyFilters);
storeFilter.addEventListener('change', applyFilters);
sortFilter.addEventListener('change', applyFilters);
pageSizeSelect.addEventListener('change', (e) => {
  pageSize = parseInt(e.target.value, 10) || 8;
  currentPage = 0;
  renderTable();
  updatePager();
});

prevPageBtn.addEventListener('click', () => {
  if (currentPage > 0) {
    currentPage--;
    renderTable();
    updatePager();
  }
});

nextPageBtn.addEventListener('click', () => {
  const totalPages = Math.ceil(filteredProducts.length / pageSize);
  if (currentPage < totalPages - 1) {
    currentPage++;
    renderTable();
    updatePager();
  }
});

// 9. Authentication Flow
function handleUserLoggedIn(user) {
  currentUser = user;
  if (sessionBadge) sessionBadge.classList.remove('hidden');
  if (sessionLabel) sessionLabel.textContent = user.displayName || user.email || 'Admin';
  if (logoutBtn) logoutBtn.classList.remove('hidden');
  showView('dashboardView');

  if (window.gsap && !prefersReducedMotion) {
    gsap.from('.dashboard-grid > .panel', {
      y: 20,
      opacity: 0,
      duration: 0.5,
      stagger: 0.08,
      ease: 'power2.out'
    });
  }

  loadProducts();
}

function handleUserLoggedOut() {
  currentUser = null;
  if (sessionBadge) sessionBadge.classList.add('hidden');
  if (logoutBtn) logoutBtn.classList.add('hidden');
  showView('loginView');
}

async function verifyAdminRoleAndLogin(user) {
  if (!user || !user.email) {
    if (auth && auth.currentUser) await auth.signOut();
    loginError.textContent = 'No se pudo obtener el correo de la cuenta de Google.';
    handleUserLoggedOut();
    return;
  }

  const email = user.email.toLowerCase().trim();
  showLoading('Verificando privilegios de administrador…');

  try {
    const adminDoc = await db.collection('admins').doc(email).get();

    if (adminDoc.exists && adminDoc.data().role === 'admin') {
      showToast(`Acceso concedido: ${user.displayName || email}`);
      handleUserLoggedIn(user);
    } else {
      console.warn(`[Acceso Denegado] ${email} no tiene rol admin en Firestore.`);
      if (auth && auth.currentUser) {
        await auth.signOut();
      }
      handleUserLoggedOut();
      loginError.textContent = `Acceso denegado: El correo "${email}" no cuenta con permisos de administrador en MODO.`;
    }
  } catch (err) {
    console.error('Error al verificar admin en Firestore:', err);
    if (auth && auth.currentUser) await auth.signOut();
    handleUserLoggedOut();
    loginError.textContent = 'Error al verificar permisos en la base de datos: ' + (err.message || err);
  } finally {
    hideLoading();
  }
}

// Email & Password Sign-In con Verificación de Rol Admin
if (emailLoginForm) {
  emailLoginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!auth || !db) {
      loginError.textContent = 'Firebase Auth o Firestore no están inicializados.';
      return;
    }
    const email = adminEmailInput ? adminEmailInput.value.trim() : '';
    const password = adminPasswordInput ? adminPasswordInput.value : '';

    if (!email || !password) {
      loginError.textContent = 'Por favor ingresa tu correo y contraseña.';
      return;
    }

    loginError.textContent = '';
    showLoading('Autenticando administrador…');

    try {
      const userCredential = await auth.signInWithEmailAndPassword(email, password);
      await verifyAdminRoleAndLogin(userCredential.user);
    } catch (err) {
      console.error('Email Admin Sign-In Error:', err);
      if (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
        loginError.textContent = 'Correo o contraseña incorrectos.';
      } else if (err.code === 'auth/too-many-requests') {
        loginError.textContent = 'Demasiados intentos fallidos. Intenta más tarde.';
      } else {
        loginError.textContent = err.message || 'Error al iniciar sesión.';
      }
    } finally {
      hideLoading();
    }
  });
}

// Google OAuth Sign-In Exclusivo con Verificación de Rol Admin
googleLoginBtn.addEventListener('click', async () => {
  if (!auth || !db) {
    loginError.textContent = 'Firebase Auth o Firestore no están inicializados.';
    return;
  }
  loginError.textContent = '';
  showLoading('Conectando con Google…');
  try {
    const provider = new firebase.auth.GoogleAuthProvider();
    provider.addScope('profile');
    provider.addScope('email');
    provider.setCustomParameters({ prompt: 'select_account' });

    const userCredential = await auth.signInWithPopup(provider);
    await verifyAdminRoleAndLogin(userCredential.user);
  } catch (err) {
    console.error('Google Sign-In Error:', err);
    if (err.code === 'auth/popup-blocked' || err.code === 'auth/cancelled-popup-request') {
      try {
        showLoading('Redirigiendo a Google…');
        const provider = new firebase.auth.GoogleAuthProvider();
        provider.setCustomParameters({ prompt: 'select_account' });
        await auth.signInWithRedirect(provider);
        return;
      } catch (redirectErr) {
        loginError.textContent = redirectErr.message;
      }
    } else if (err.code === 'auth/configuration-not-found') {
      loginError.textContent = 'Error de configuración de Auth en Firebase. Revisa el dominio autorizado en Firebase Console.';
    } else {
      loginError.textContent = err.message || 'Error al autenticar con Google.';
    }
  } finally {
    hideLoading();
  }
});

if (demoLoginBtn) {
  demoLoginBtn.addEventListener('click', () => {
    isDemoMode = true;
    loginError.textContent = '';
    showToast('Modo Administrador Local activado');
    handleUserLoggedIn({
      uid: 'demo_admin',
      displayName: 'Admin MODO (Local)',
      email: 'admin@modo.pe'
    });
  });
}

if (manageCategoriesBtn) {
  manageCategoriesBtn.addEventListener('click', () => {
    renderCategoriesModal();
    if (categoriesModal) categoriesModal.classList.remove('hidden');
  });
}

if (closeCategoriesBtn) {
  closeCategoriesBtn.addEventListener('click', () => {
    if (categoriesModal) categoriesModal.classList.add('hidden');
  });
}

if (addCategoryBtn) {
  addCategoryBtn.addEventListener('click', () => {
    const val = cleanString(newCategoryInput ? newCategoryInput.value : '');
    if (!val) return;
    if (customCategories.includes(val)) {
      showToast(`La categoría "${val}" ya existe.`, 'error');
      return;
    }
    customCategories.push(val);
    saveCategoriesLocal();
    if (newCategoryInput) newCategoryInput.value = '';
    renderCategorySelects();
    renderCategoriesModal();
    showToast(`Categoría "${val}" agregada.`);
  });
}

if (categoriesTableBody) {
  categoriesTableBody.addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-cat-action]');
    if (!btn) return;
    const action = btn.dataset.catAction;
    const cat = btn.dataset.cat;
    if (action === 'rename') {
      const nuevo = prompt(`Nuevo nombre para la categoría "${cat}":`, cat);
      if (nuevo && cleanString(nuevo) !== cat) {
        await renameCategoryGlobal(cat, nuevo);
      }
    } else if (action === 'delete') {
      deleteCategoryGlobal(cat);
    }
  });
}

logoutBtn.addEventListener('click', async () => {
  isDemoMode = false;
  if (auth && auth.currentUser) {
    await auth.signOut();
  }
  handleUserLoggedOut();
});

// Process Google Redirect Result & listen for Firebase Auth changes con validación de admin
if (auth) {
  auth.getRedirectResult().then(async (result) => {
    if (result && result.user) {
      await verifyAdminRoleAndLogin(result.user);
    }
  }).catch((err) => {
    console.error('Redirect sign-in error:', err);
    loginError.textContent = err.message || 'Error en autenticación redirigida.';
  });

  auth.onAuthStateChanged(async (user) => {
    if (user) {
      if (!currentUser || currentUser.uid !== user.uid) {
        await verifyAdminRoleAndLogin(user);
      }
    } else if (!isDemoMode) {
      handleUserLoggedOut();
    }
  });
}

// Background slideshow
(function bgSlideshow() {
  if (prefersReducedMotion) return;
  const slides = document.querySelectorAll('.login-bg .bg-slide');
  if (!slides.length) return;
  let i = 0;
  setInterval(() => {
    slides[i].classList.remove('active');
    i = (i + 1) % slides.length;
    slides[i].classList.add('active');
    if (window.gsap) {
      gsap.fromTo(slides[i], { opacity: 0, scale: 1.05 }, { opacity: 1, scale: 1, duration: 1.2 });
    }
  }, 4200);
})();

// Health check & initial UI safeguard on load
hideLoading();
loadSavedCategories();
renderCategorySelects();
checkFirebaseHealth();
