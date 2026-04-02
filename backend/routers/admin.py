from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["Admin"])

ADMIN_HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>智能记忆助手 - 管理后台</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>
  .tab-btn { transition: all 0.15s; }
  .tab-btn.active { border-bottom: 2px solid #6366f1; color: #6366f1; font-weight: 600; }
  .card { background: white; border-radius: 0.75rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.25rem; }
  body { background: #f3f4f6; }
  .badge-local { background: #dbeafe; color: #1e40af; }
  .badge-web { background: #dcfce7; color: #166534; }
  .spinner { border: 3px solid #e5e7eb; border-top: 3px solid #6366f1; border-radius: 50%; width: 20px; height: 20px; animation: spin 0.8s linear infinite; display: inline-block; }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
</head>
<body class="min-h-screen">

<!-- Header -->
<header class="bg-white border-b shadow-sm">
  <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
    <h1 class="text-xl font-bold text-gray-800">&#x1f9e0; 智能记忆助手 &mdash; 管理后台</h1>
    <span id="health-badge" class="text-sm px-3 py-1 rounded-full bg-gray-200 text-gray-500">检测中...</span>
  </div>
</header>

<!-- Tabs -->
<div class="max-w-7xl mx-auto px-4 mt-4">
  <div class="flex gap-6 border-b">
    <button class="tab-btn active pb-2 text-sm" onclick="switchTab('docs')">本地知识库</button>
    <button class="tab-btn pb-2 text-sm" onclick="switchTab('rag')">RAG 测试</button>
  </div>
</div>

<!-- ==================== Docs Panel ==================== -->
<div id="panel-docs" class="max-w-7xl mx-auto px-4 py-4">
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <!-- Left: Doc list -->
    <div class="card">
      <h2 class="font-semibold text-gray-700 mb-3">文档列表</h2>
      <div id="doc-list" class="max-h-96 overflow-y-auto">
        <p class="text-gray-400 text-sm">加载中...</p>
      </div>
    </div>
    <!-- Right: Add -->
    <div class="card">
      <h2 class="font-semibold text-gray-700 mb-3">添加内容</h2>
      <div class="space-y-3">
        <input id="doc-title" placeholder="标题" class="w-full border rounded px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-300 outline-none">
        <textarea id="doc-content" rows="8" placeholder="粘贴学习笔记、知识点整理…" class="w-full border rounded px-3 py-1.5 text-sm focus:ring-2 focus:ring-indigo-300 outline-none resize-y"></textarea>
        <button onclick="addDocText()" class="bg-indigo-500 text-white px-4 py-2 rounded text-sm hover:bg-indigo-600 w-full">添加文本</button>
      </div>
      <div class="mt-4 border-t pt-4">
        <h3 class="text-sm font-medium text-gray-600 mb-2">或上传文件</h3>
        <div id="drop-zone" class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center text-gray-400 hover:border-indigo-400 cursor-pointer transition">
          <p>拖拽 .txt / .md 文件到这里，或点击选择</p>
          <input id="file-input" type="file" accept=".txt,.md" class="hidden" onchange="uploadFile()">
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ==================== RAG Panel ==================== -->
<div id="panel-rag" class="max-w-7xl mx-auto px-4 py-4 hidden">
  <div class="card max-w-3xl mx-auto">
    <h2 class="font-semibold text-gray-700 mb-3">RAG 问答测试</h2>
    <textarea id="rag-question" rows="3" placeholder="输入你的问题…" class="w-full border rounded px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-300 outline-none resize-y mb-3"></textarea>
    <div class="flex items-center gap-4 mb-3">
      <label class="flex items-center gap-1.5 text-sm text-gray-600">
        <input type="checkbox" id="rag-web" checked class="accent-indigo-500"> 联网搜索
      </label>
      <label class="flex items-center gap-1.5 text-sm text-gray-600">
        <input type="checkbox" id="rag-local" checked class="accent-indigo-500"> 本地知识库
      </label>
      <button onclick="queryRAG()" id="btn-rag" class="ml-auto bg-indigo-500 text-white px-6 py-2 rounded text-sm hover:bg-indigo-600">提问</button>
    </div>
    <div id="rag-result" class="hidden border-t pt-4 mt-2">
      <h3 class="text-sm font-semibold text-gray-700 mb-2">回答</h3>
      <div id="rag-answer" class="text-sm text-gray-800 whitespace-pre-wrap bg-gray-50 rounded p-3 mb-3"></div>
      <h3 class="text-sm font-semibold text-gray-700 mb-2">参考来源</h3>
      <div id="rag-sources"></div>
    </div>
  </div>
</div>

<script>
const API = '';

// ─── Tab Switch ──────────────────────────────
function switchTab(name) {
  document.querySelectorAll('.tab-btn').forEach((b, i) => {
    const tabs = ['docs','rag'];
    b.classList.toggle('active', tabs[i] === name);
  });
  ['docs','rag'].forEach(t => {
    document.getElementById('panel-' + t).classList.toggle('hidden', t !== name);
  });
  if (name === 'docs') loadDocs();
}

// ─── Health ──────────────────────────────────
async function checkHealth() {
  const badge = document.getElementById('health-badge');
  try {
    const r = await fetch(API + '/api/health');
    if (r.ok) { badge.textContent = '后端在线'; badge.className = 'text-sm px-3 py-1 rounded-full bg-green-100 text-green-700'; }
    else throw 0;
  } catch { badge.textContent = '后端离线'; badge.className = 'text-sm px-3 py-1 rounded-full bg-red-100 text-red-700'; }
}

// ─── Docs: Knowledge Base ────────────────────
async function loadDocs() {
  const el = document.getElementById('doc-list');
  try {
    const r = await fetch(API + '/api/docs/list');
    const docs = await r.json();
    if (!docs.length) { el.innerHTML = '<p class="text-gray-400 text-sm py-2">暂无文档</p>'; return; }
    el.innerHTML = docs.map(d => `
      <div class="flex items-center justify-between border-b py-2">
        <div>
          <p class="text-sm font-medium text-gray-800">${esc(d.title)}</p>
          <p class="text-xs text-gray-400">${d.chunk_count} 个片段</p>
        </div>
        <button onclick="deleteDoc('${esc(d.doc_id)}')" class="text-red-500 hover:text-red-700 text-xs px-2 py-1 border border-red-200 rounded hover:bg-red-50">删除</button>
      </div>
    `).join('');
  } catch { el.innerHTML = '<p class="text-red-400 text-sm">加载失败</p>'; }
}

async function addDocText() {
  const title = document.getElementById('doc-title').value.trim();
  const content = document.getElementById('doc-content').value.trim();
  if (!content) return alert('内容不能为空');
  try {
    const r = await fetch(API + '/api/docs/text', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ title: title || '未命名', content })
    });
    const data = await r.json();
    alert('添加成功，切分为 ' + data.chunk_count + ' 个片段');
    document.getElementById('doc-title').value = '';
    document.getElementById('doc-content').value = '';
    loadDocs();
  } catch(e) { alert('添加失败: ' + e); }
}

async function uploadFile() {
  const input = document.getElementById('file-input');
  if (!input.files.length) return;
  const file = input.files[0];
  const fd = new FormData();
  fd.append('file', file);
  fd.append('title', file.name);
  try {
    const r = await fetch(API + '/api/docs/upload', { method: 'POST', body: fd });
    const data = await r.json();
    alert('上传成功，切分为 ' + data.chunk_count + ' 个片段');
    input.value = '';
    loadDocs();
  } catch(e) { alert('上传失败: ' + e); }
}

async function deleteDoc(docId) {
  if (!confirm('确定删除此文档？')) return;
  await fetch(API + '/api/docs/' + encodeURIComponent(docId), { method: 'DELETE' });
  loadDocs();
}

// Drop zone
document.addEventListener('DOMContentLoaded', () => {
  const dz = document.getElementById('drop-zone');
  const fi = document.getElementById('file-input');
  dz.addEventListener('click', () => fi.click());
  dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('border-indigo-400','bg-indigo-50'); });
  dz.addEventListener('dragleave', () => { dz.classList.remove('border-indigo-400','bg-indigo-50'); });
  dz.addEventListener('drop', e => {
    e.preventDefault();
    dz.classList.remove('border-indigo-400','bg-indigo-50');
    if (e.dataTransfer.files.length) { fi.files = e.dataTransfer.files; uploadFile(); }
  });
});

// ─── RAG ─────────────────────────────────────
async function queryRAG() {
  const question = document.getElementById('rag-question').value.trim();
  if (!question) return;
  const useWeb = document.getElementById('rag-web').checked;
  const useLocal = document.getElementById('rag-local').checked;
  const btn = document.getElementById('btn-rag');
  const resultDiv = document.getElementById('rag-result');
  btn.disabled = true; btn.innerHTML = '<span class="spinner"></span> 查询中…';
  resultDiv.classList.add('hidden');
  try {
    const r = await fetch(API + '/api/rag/query', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ question, use_web_search: useWeb, use_local_kb: useLocal, top_k: 5 })
    });
    const data = await r.json();
    document.getElementById('rag-answer').textContent = data.answer || '(无回答)';
    const srcEl = document.getElementById('rag-sources');
    if (data.sources && data.sources.length) {
      srcEl.innerHTML = data.sources.map(s => {
        const badge = s.source_type === 'local' ? 'badge-local' : 'badge-web';
        const label = s.source_type === 'local' ? '本地' : '网络';
        const link = s.url ? `<a href="${esc(s.url)}" target="_blank" class="text-indigo-600 hover:underline text-xs ml-2">打开</a>` : '';
        return `<div class="border rounded p-2 mb-2 text-sm"><span class="text-xs px-1.5 py-0.5 rounded ${badge}">${label}</span> <strong>${esc(s.title)}</strong>${link}<p class="text-gray-500 mt-1 text-xs">${esc(s.snippet)}</p></div>`;
      }).join('');
    } else { srcEl.innerHTML = '<p class="text-gray-400 text-sm">无参考来源</p>'; }
    resultDiv.classList.remove('hidden');
  } catch(e) { alert('查询失败: ' + e); }
  finally { btn.disabled = false; btn.textContent = '提问'; }
}

// ─── Utils ───────────────────────────────────
function esc(s) { const d = document.createElement('div'); d.textContent = s||''; return d.innerHTML; }

// ─── Init ────────────────────────────────────
checkHealth();
loadDocs();
</script>
</body>
</html>"""


@router.get("/admin", response_class=HTMLResponse)
async def admin_page():
    return ADMIN_HTML
