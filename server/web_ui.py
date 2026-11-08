r"""管理后台 Web UI"""
from flask import render_template_string

LOGIN_HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MookNote 管理后台</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter',system-ui,-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#F5F7FB;display:flex;justify-content:center;align-items:center;min-height:100vh;-webkit-font-smoothing:antialiased}
.login-card{background:#fff;border:1px solid #E9ECF2;border-radius:18px;padding:48px 40px;width:100%;max-width:380px;box-shadow:0 12px 40px rgba(23,26,33,.10)}
.logo{text-align:center;margin-bottom:36px}
.logo h1{font-size:21px;font-weight:700;color:#1F2430;letter-spacing:-0.3px;margin-bottom:4px}
.logo p{font-size:11px;color:#9AA3B2;font-weight:500;letter-spacing:1.2px;text-transform:uppercase}
.form-group{margin-bottom:14px}
.form-group input{width:100%;padding:11px 13px;border:1px solid #E9ECF2;font-size:14px;outline:none;transition:border-color .18s,box-shadow .18s;font-family:inherit;color:#1F2430;border-radius:11px;background:#F7F8FC}
.form-group input::placeholder{color:#9AA3B2}
.form-group input:focus{border-color:#4F6EF7;background:#fff;box-shadow:0 0 0 3px rgba(79,110,247,.12)}
.login-btn{width:100%;margin-top:22px;padding:12px;background:#4F6EF7;color:#fff;border:none;border-radius:11px;font-size:13px;font-weight:600;cursor:pointer;letter-spacing:0.5px;transition:background .18s,box-shadow .18s;font-family:inherit;box-shadow:0 4px 14px rgba(79,110,247,.32)}
.login-btn:hover{background:#3D5CE8}
.error{color:#E5484D;font-size:12px;margin-bottom:12px;display:none;background:rgba(229,72,77,.07);padding:8px 12px;border:1px solid rgba(229,72,77,.3);border-radius:10px}
</style>
</head>
<body>
<div class="login-card">
<div class="logo"><h1>MookNote</h1><p>Admin Console</p></div>
<div class="error" id="error"></div>
<div class="form-group"><input type="text" id="username" placeholder="用户名" autocomplete="username"></div>
<div class="form-group"><input type="password" id="password" placeholder="密码" autocomplete="current-password"></div>
<button class="login-btn" onclick="login()">登 录</button>
</div>
<script>
function login(){
  var u=document.getElementById('username').value.trim();
  var p=document.getElementById('password').value.trim();
  if(!u||!p)return;
  document.getElementById('error').style.display='none';
  fetch('/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,password:p})})
  .then(function(r){return r.json()}).then(function(d){
    if(d.token){localStorage.setItem('token',d.token);localStorage.setItem('username',d.username);location.href='/admin/dashboard'}
    else{var e=document.getElementById('error');e.textContent=d.error||'登录失败';e.style.display='block'}
  });
}
document.addEventListener('keydown',function(e){if(e.key==='Enter')login()});
</script>
</body>
</html>"""

DASHBOARD_HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>MookNote 管理后台</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--black:#1F2430;--dark:#3A4252;--gray:#5E6675;--light:#9AA3B2;--border:#E9ECF2;--bg:#F5F7FB;--white:#fff;--accent:#4F6EF7;--accent-soft:#EEF1FE;--error:#E5484D;--error-soft:#FDECEC;--success:#2FA968;--success-soft:#E8F7F0;--warning:#E68619;--warning-soft:#FDF2E3;--radius:16px;--radius-sm:12px;--radius-xs:9px;--sidebar:#171A21;--sidebar-hover:#22262F;--shadow:0 1px 2px rgba(23,26,33,.04),0 6px 20px rgba(23,26,33,.06);--shadow-hover:0 10px 30px rgba(23,26,33,.10)}
body{font-family:'Inter',system-ui,-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:var(--bg);min-height:100vh;color:var(--black);-webkit-font-smoothing:antialiased}

/* Sidebar */
.sidebar{position:fixed;top:0;left:0;bottom:0;width:224px;background:linear-gradient(180deg,#181C24 0%,#14171D 100%);display:flex;flex-direction:column;padding:22px 14px;z-index:200}
.sidebar .brand{padding:2px 10px 18px;border-bottom:1px solid rgba(255,255,255,.08);margin-bottom:14px}
.sidebar .brand h1{font-size:17px;font-weight:600;color:#fff;letter-spacing:-0.3px}
.sidebar .brand p{font-size:10px;color:#6B7280;letter-spacing:1.2px;text-transform:uppercase;margin-top:3px}
.sidebar .nav{display:flex;flex-direction:column;gap:4px;flex:1;overflow-y:auto}
.sidebar .nav a{position:relative;display:flex;align-items:center;gap:11px;padding:10px 12px;font-size:13px;color:#A8B0BE;text-decoration:none;cursor:pointer;transition:all .18s;font-weight:500;border-radius:var(--radius-xs)}
.sidebar .nav a svg{width:16px;height:16px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;flex-shrink:0;opacity:.7;transition:opacity .18s}
.sidebar .nav a:hover{color:#fff;background:var(--sidebar-hover)}
.sidebar .nav a:hover svg{opacity:1}
.sidebar .nav a.active{color:#fff;background:rgba(79,110,247,.16);font-weight:600}
.sidebar .nav a.active svg{opacity:1;color:var(--accent)}
.sidebar .nav a.active::before{content:'';position:absolute;left:-14px;top:9px;bottom:9px;width:3px;border-radius:0 3px 3px 0;background:var(--accent)}
.sidebar .actions{border-top:1px solid rgba(255,255,255,.08);padding:14px 6px 0;display:flex;flex-direction:column;gap:10px}
.sidebar .actions .user-name{font-size:12px;color:#8A93A3;padding:0 6px}
.sidebar .actions .btns{display:flex;gap:8px}
.sidebar .actions .btns .btn{flex:1;background:transparent;color:#A8B0BE;border-color:rgba(255,255,255,.14)}
.sidebar .actions .btns .btn:hover{background:var(--sidebar-hover);color:#fff;border-color:rgba(255,255,255,.3)}
.sidebar .actions .btns .btn-danger{color:#FF9CA0;border-color:rgba(229,72,77,.4)}
.sidebar .actions .btns .btn-danger:hover{background:var(--error);color:#fff;border-color:var(--error)}
/* Mobile topbar + mask */
.topbar{display:none;position:sticky;top:0;z-index:150;background:var(--white);border-bottom:1px solid var(--border);height:54px;padding:0 14px;align-items:center;gap:10px}
.topbar h1{font-size:15px;font-weight:600;color:var(--black)}
.topbar .menu-btn{border:1px solid var(--border);background:var(--white);width:36px;height:36px;border-radius:var(--radius-xs);font-size:16px;cursor:pointer;color:var(--dark);display:flex;align-items:center;justify-content:center;font-family:inherit}
.side-mask{display:none;position:fixed;inset:0;background:rgba(17,20,26,.45);backdrop-filter:blur(2px);z-index:190}
.side-mask.show{display:block}
.btn{padding:8px 18px;border:1px solid var(--border);background:var(--white);color:var(--dark);font-size:11px;font-weight:500;cursor:pointer;transition:all .18s;font-family:inherit;border-radius:var(--radius-xs);white-space:nowrap}
.btn:hover{border-color:var(--accent);color:var(--accent)}
.btn-black{background:var(--accent);color:var(--white);border-color:var(--accent);border-radius:var(--radius-xs);box-shadow:0 3px 10px rgba(79,110,247,.28)}.btn-black:hover{background:#3D5CE8;border-color:#3D5CE8;color:#fff}
.btn-danger{background:var(--white);color:var(--error);border-color:rgba(229,72,77,.45);border-radius:var(--radius-xs)}.btn-danger:hover{background:var(--error);color:var(--white);border-color:var(--error)}
.btn-xs{padding:5px 13px;font-size:10px}

/* Layout */
.main-wrap{margin-left:224px;min-height:100vh}
.content{max-width:1240px;margin:0 auto;padding:30px 32px 44px}

/* Stat Row */
.stat-row{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:8px}
.stat-item{display:flex;align-items:center;gap:14px;background:var(--white);border-radius:var(--radius);padding:18px 20px;border:1px solid var(--border);box-shadow:var(--shadow);transition:transform .18s,box-shadow .18s}
.stat-item:hover{transform:translateY(-2px);box-shadow:var(--shadow-hover)}
.stat-icon{width:44px;height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.stat-icon svg{width:21px;height:21px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.stat-icon.ic-blue{background:var(--accent-soft);color:var(--accent)}
.stat-icon.ic-green{background:var(--success-soft);color:var(--success)}
.stat-icon.ic-amber{background:var(--warning-soft);color:var(--warning)}
.stat-icon.ic-violet{background:#F1EEFE;color:#7A5AF8}
.stat-item .stat-value{font-size:25px;font-weight:700;color:var(--black);line-height:1;letter-spacing:-0.5px}
.stat-item .stat-label{font-size:11px;color:var(--light);margin-top:7px;font-weight:400}
.stat-trend{font-size:11px;font-weight:500;white-space:nowrap}
.stat-trend.up{color:var(--success)}.stat-trend.down{color:var(--error)}.stat-trend.same{color:var(--light)}

/* Analytics Row */
.analytics-row{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:24px}
.analytics-item{background:var(--white);border-radius:var(--radius);padding:18px 20px;border:1px solid var(--border);box-shadow:var(--shadow)}
.analytics-item .a-value{font-size:20px;font-weight:600;color:var(--black);line-height:1}
.analytics-item .a-label{font-size:11px;color:var(--light);margin-top:6px}
.analytics-item .a-sub{font-size:10px;color:var(--light);margin-top:2px;opacity:.6}

/* Cards */
.card{background:var(--white);border-radius:var(--radius);border:1px solid var(--border);padding:24px;margin-bottom:18px;box-shadow:var(--shadow)}
.card-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:18px}
.card-title{font-size:15px;font-weight:600;color:var(--black);letter-spacing:-0.2px}
.card-sub{font-size:11px;color:var(--light);margin-top:4px}

/* Chart */
.chart-row{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:12px}
.chart-cell{background:var(--white);border-radius:var(--radius);border:1px solid var(--border);padding:18px;box-shadow:var(--shadow);min-width:0}
.chart-cell .chart-title{font-size:11px;font-weight:600;color:var(--black);margin-bottom:10px}
.chart-cell .chart-sub{font-size:10px;color:var(--light);margin-bottom:10px}
.chart-cell canvas{width:100%!important;max-height:180px}
/* ECharts 地图的 canvas 不受上方 Chart.js 高度限制 */
#chinaMap canvas{max-height:none}
.chart-full{grid-column:1/-1}

/* Date Filter */
.date-filter{display:flex;align-items:center;gap:8px;margin-bottom:16px}
.date-filter label{font-size:11px;color:var(--light);font-weight:500}
.date-filter input[type="date"]{padding:6px 10px;border:1px solid var(--border);font-size:12px;font-family:inherit;color:var(--black);background:var(--white);outline:none;border-radius:var(--radius-xs);transition:border-color .15s}
.date-filter input[type="date"]:focus{border-color:var(--accent)}
.date-filter .btn{font-size:10px;padding:6px 14px}
.date-preset{display:flex;gap:4px;margin-left:8px}
.date-preset button{padding:6px 13px;border:1px solid var(--border);background:var(--white);font-size:10px;color:var(--gray);cursor:pointer;font-family:inherit;transition:all .15s;border-radius:var(--radius-xs)}
.date-preset button:hover{border-color:var(--accent);color:var(--accent)}
.date-preset button.active{border-color:var(--accent);color:var(--accent);background:var(--accent-soft)}

/* Tables */
.table-wrap{overflow-x:auto;border:1px solid var(--border);border-radius:var(--radius-sm);box-shadow:var(--shadow)}

/* Changelog */
.cl-item{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-sm);padding:18px 20px;margin-bottom:10px;box-shadow:var(--shadow);transition:border-color .18s,box-shadow .18s}
.cl-item:hover{border-color:var(--accent);box-shadow:var(--shadow-hover)}
.cl-head{display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px}
.cl-meta{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.cl-version{display:inline-flex;align-items:center;padding:4px 12px;background:var(--accent-soft);color:var(--accent);font-size:12px;font-weight:600;border-radius:var(--radius-xs);letter-spacing:0.3px}
.cl-date{font-size:12px;color:var(--light)}
.cl-order{font-size:10px;color:var(--light);background:var(--bg);padding:2px 8px;border-radius:var(--radius-xs)}
.cl-actions{display:flex;gap:6px;flex-shrink:0}
.cl-features{padding-left:4px}
.cl-feat{display:flex;align-items:baseline;gap:8px;padding:3px 0;font-size:13px;color:var(--gray);line-height:1.6}
.cl-feat-idx{font-size:11px;color:var(--light);min-width:20px;text-align:right;font-weight:500}
table{width:100%;border-collapse:collapse}
table th,table td{text-align:left;padding:11px 14px;font-size:12px}
table th{color:var(--light);font-weight:600;font-size:10px;letter-spacing:0.5px;text-transform:uppercase;background:#F8FAFD;border-bottom:1px solid var(--border)}
table td{color:var(--gray);border-bottom:1px solid var(--border)}
table tr:last-child td{border-bottom:none}
table tr:hover td{background:var(--accent-soft)}
table code{display:inline-block;padding:3px 8px;background:#F1F3F8;border-radius:7px;font-size:11px;color:#4A5261;font-family:'SF Mono',Menlo,Consolas,monospace}
.tag{display:inline-block;padding:3px 11px;font-size:10px;font-weight:600;border-radius:20px;background:#F1F3F8;color:var(--gray)}
.tag-success{color:var(--success);background:var(--success-soft)}.tag-danger{color:var(--error);background:var(--error-soft)}.tag-info{color:var(--accent);background:var(--accent-soft)}
.empty{text-align:center;color:var(--light);padding:52px;font-size:12px;background:#FAFBFE;border:1px dashed var(--border);border-radius:var(--radius-sm)}

/* Form */
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:flex-end;margin-bottom:14px}
.el-select{padding:9px 12px;border:1px solid var(--border);font-size:12px;outline:none;background:var(--white);font-family:inherit;color:var(--black);min-width:100px;border-radius:var(--radius-xs);transition:border-color .15s,box-shadow .15s}
.el-select:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(79,110,247,.12)}
.el-input{padding:9px 12px;border:1px solid var(--border);font-size:12px;outline:none;flex:1;min-width:120px;font-family:inherit;color:var(--black);border-radius:var(--radius-xs);transition:border-color .15s,box-shadow .15s}
.el-input:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(79,110,247,.12)}
.el-form-item{margin-bottom:12px}
.el-form-item label{display:block;font-size:11px;color:var(--gray);margin-bottom:5px;font-weight:500}
.el-form-item .el-input{display:block;width:100%}

/* Search */
.search-bar{display:flex;gap:8px;margin-bottom:14px}
.search-bar .el-input{max-width:260px}

/* Link */
.link{color:var(--accent);cursor:pointer;font-size:12px;text-decoration:none;border-bottom:1px solid transparent;transition:border-color .15s}
.link:hover{border-bottom-color:var(--accent)}

/* Pagination */
.pagination{display:flex;justify-content:center;gap:5px;margin-top:14px}
.pagination button{min-width:32px;height:32px;border:1px solid var(--border);background:var(--white);font-size:11px;cursor:pointer;color:var(--gray);font-family:inherit;transition:all .15s;border-radius:var(--radius-xs)}
.pagination button.active{background:var(--accent);color:var(--white);border-color:var(--accent)}
.pagination button:hover{color:var(--accent);border-color:var(--accent)}

/* Modal */
.modal-mask{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(17,20,26,.4);backdrop-filter:blur(6px);display:flex;justify-content:center;align-items:center;z-index:999}
.modal-box{background:var(--white);border-radius:var(--radius);border:1px solid var(--border);padding:28px;min-width:420px;max-width:90vw;max-height:85vh;overflow-y:auto;box-shadow:0 24px 64px rgba(17,20,26,.18)}
.modal-box h3{font-size:15px;font-weight:600;color:var(--black);margin-bottom:4px}
.modal-box .modal-sub{font-size:11px;color:var(--light);margin-bottom:18px}
.modal-footer{display:flex;justify-content:flex-end;gap:8px;margin-top:18px}

/* Toast */
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(10px);padding:10px 24px;color:var(--white);font-size:12px;font-weight:500;z-index:9999;opacity:0;transition:all .25s;border-radius:var(--radius-sm);box-shadow:0 8px 24px rgba(17,20,26,.2)}
.toast.show{opacity:1;transform:translateX(-50%) translateY(0)}
.toast-ok{background:var(--success)}.toast-err{background:var(--error)}

/* Loading */
.loading{display:flex;align-items:center;justify-content:center;padding:32px;color:var(--light);font-size:12px}
.spinner{width:14px;height:14px;border:1.5px solid var(--border);border-top-color:var(--accent);border-radius:50%;animation:spin .6s linear infinite;margin-right:8px}
@keyframes spin{to{transform:rotate(360deg)}}

/* Responsive */
@media(max-width:900px){
  .stat-row,.analytics-row{grid-template-columns:repeat(2,1fr)}
  .chart-row{grid-template-columns:1fr}
  #chinaMap{height:320px!important}
  .topbar{display:flex}
  .sidebar{transform:translateX(-100%);transition:transform .25s ease}
  .sidebar.open{transform:none;box-shadow:0 0 40px rgba(0,0,0,.15)}
  .main-wrap{margin-left:0}
  .content{padding:18px 16px 32px}
  .modal-box{min-width:auto;width:92vw;padding:20px}
  .date-filter{flex-wrap:wrap}
  .date-preset{margin-left:0;width:100%}
  .date-preset button{flex:1;padding:7px 0;font-size:11px}
  .cl-item{padding:14px}
  .cl-head{flex-direction:column;align-items:stretch;gap:10px;margin-bottom:8px}
  .cl-meta{gap:6px}
  .cl-actions{width:100%}
  .cl-actions .btn{flex:1;padding:8px 0;font-size:11px}
}
@media(max-width:480px){
  .stat-item,.analytics-item{padding:14px}
  .stat-item .stat-value{font-size:22px}
  .analytics-item .a-value{font-size:17px}
}
</style>
</head>
<body>
<div class="topbar"><button class="menu-btn" onclick="toggleSidebar()">☰</button><h1>MookNote</h1></div>
<div class="side-mask" id="sideMask" onclick="closeSidebar()"></div>
<div class="sidebar" id="sidebar">
<div class="brand"><h1>MookNote</h1><p>Admin Console</p></div>
<div class="nav">
<a href="#" data-nav="exports" onclick="showExports()"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M8 13h8M8 17h5"/></svg>Excel导出日志</a>
<a href="#" data-nav="changelog" onclick="showChangelog()"><svg viewBox="0 0 24 24"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/></svg>软件更新日志</a>
<a href="#" data-nav="enhance" onclick="showEnhance()"><svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>增强视校验值设置</a>
<a href="#" data-nav="crashes" onclick="showCrashes()"><svg viewBox="0 0 24 24"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg>运行日志上报</a>
<a href="#" data-nav="feedback" onclick="showFeedback()"><svg viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9 9 0 0 1-3.9-.9L3 21l1.9-5.1A8.4 8.4 0 1 1 21 11.5z"/><path d="M8.5 11h.01M12 11h.01M15.5 11h.01"/></svg>用户意见反馈</a>
</div>
<div class="actions">
<span class="user-name" id="userInfo"></span>
<div class="btns">
<button class="btn btn-xs" onclick="changePassword()">密码</button>
<button class="btn btn-xs btn-danger" onclick="logout()">退出</button>
</div>
</div>
</div>
<div class="main-wrap">
<div class="content">

<div id="enhanceView" style="display:none">
<div class="card">
<div class="card-header"><div><div class="card-title">增强视频校验值</div><div class="card-sub">App 端通过 /api/enhance-video 读取此值用于校验</div></div></div>
<div style="display:flex;flex-direction:column;gap:14px">
<div>
<label style="display:block;font-size:12px;color:var(--gray);margin-bottom:6px">校验值（可填任意内容：数字、文字等）</label>
<textarea id="enhanceVideoInput" rows="4" style="width:100%;padding:10px 12px;border:1px solid var(--border);border-radius:var(--radius-sm);font-size:14px;font-family:inherit;color:var(--black);background:var(--white);outline:none;resize:vertical" placeholder="在此输入校验值..."></textarea>
</div>
<div style="display:flex;align-items:center;gap:10px">
<button class="btn btn-black" onclick="saveEnhanceVideo()">保存</button>
<span id="enhanceVideoStatus" style="font-size:11px;color:var(--light)"></span>
</div>
</div>
</div>
</div>

<div id="crashView" style="display:none">
<div class="card" style="display:flex;flex-direction:column;height:calc(100vh - 112px)">
<div class="card-header"><div><div class="card-title">运行日志上报</div><div class="card-sub">App 端崩溃自动上报 + 用户手动提交运行日志，按签名聚合</div></div></div>
<div id="crashList" style="flex:1;overflow-y:auto"></div>
</div>
</div>

<div id="feedbackView" style="display:none">
<div class="card" style="display:flex;flex-direction:column;height:calc(100vh - 112px)">
<div class="card-header"><div><div class="card-title">意见反馈</div><div class="card-sub">App 端用户提交，可回复（用户在 App 内查看回复）</div></div>
<div class="date-preset" id="fbTabs">
<button onclick="filterFeedback('')" data-status="" class="active">全部</button>
<button onclick="filterFeedback('pending')" data-status="pending">待处理</button>
<button onclick="filterFeedback('done')" data-status="done">已处理</button>
</div>
</div>
<div id="feedbackList" style="flex:1;overflow-y:auto"></div>
</div>
</div>

<div id="changelogView" style="display:none">
<div class="card" style="display:flex;flex-direction:column;height:calc(100vh - 112px)">
<div class="card-header"><div><div class="card-title">更新日志</div><div class="card-sub">App 端版本更新记录</div></div><button class="btn btn-black btn-xs" onclick="addChangelog()">+ 添加版本</button></div>
<div id="changelogList" style="flex:1;overflow-y:auto"></div>
</div>
</div>

<div id="exportView" style="display:none">
<div class="card" style="margin-bottom:14px">
<div class="card-header"><div><div class="card-title">导出功能分析</div><div class="card-sub">全部历史任务统计</div></div></div>
<div class="stat-row">
<div class="stat-item"><div class="stat-icon ic-blue"><svg viewBox="0 0 24 24"><path d="M3 7h18M3 12h18M3 17h18"/></svg></div><div><div class="stat-value" id="esTotal">-</div><div class="stat-label">累计任务</div></div></div>
<div class="stat-item"><div class="stat-icon ic-violet"><svg viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg></div><div><div class="stat-value" id="esDevices">-</div><div class="stat-label">使用设备</div></div></div>
<div class="stat-item"><div class="stat-icon ic-green"><svg viewBox="0 0 24 24"><path d="M22 11.1V12a10 10 0 1 1-5.9-9.1"/><path d="M22 4 12 14l-3-3"/></svg></div><div><div class="stat-value" id="esRate">-</div><div class="stat-label">成功率</div></div></div>
<div class="stat-item"><div class="stat-icon ic-amber"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></div><div><div class="stat-value" id="esDuration">-</div><div class="stat-label">平均耗时</div></div></div>
</div>
<div style="font-size:11px;color:var(--light);margin-top:10px">类型偏好：<span id="esTypes">-</span></div>
</div>
<div class="card">
<div class="card-header"><div><div class="card-title">带图导出任务</div><div class="card-sub">App 端在线 Excel 导出队列（停留本页时每 5 秒自动刷新）</div></div>
<div style="display:flex;align-items:center;gap:8px">
<select id="exportStatusFilter" class="el-input" style="width:auto;padding:5px 10px;font-size:12px" onchange="loadExports(1)">
<option value="">全部状态</option><option value="queued">排队</option><option value="processing">处理中</option><option value="done">完成</option><option value="failed">失败</option>
</select>
<button class="btn btn-black" onclick="loadExports()">刷新</button></div></div>
<div id="exportList"></div></div></div>

</div>
</div>
<div class="toast" id="toast"></div>
<script>
(function(){
'use strict';
var token=localStorage.getItem('token'),username=localStorage.getItem('username');
if(!token){location.href='/admin';return}
document.getElementById('userInfo').textContent=username||'';

// ---- 工具函数 ----
function authHeaders(){return{'Authorization':'Bearer '+token,'Content-Type':'application/json'}}
function escHtml(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
function fmtDate(s){
  if(!s)return '-';
  try{var d=new Date(s);if(isNaN(d.getTime()))d=new Date(s+'Z');if(isNaN(d.getTime()))return s.substring(0,16).replace('T',' ');
    return d.toLocaleString('zh-CN',{timeZone:'Asia/Shanghai',hour12:false,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'});
  }catch(e){return s.substring(0,16).replace('T',' ')}
}
function showToast(msg,ok){
  var t=document.getElementById('toast');t.textContent=msg;t.className='toast '+(ok?'toast-ok':'toast-err');
  t.classList.add('show');setTimeout(function(){t.classList.remove('show')},2200);
}
function apiFetch(url,options){
  var opts=options||{};if(!opts.headers)opts.headers=authHeaders();
  return fetch(url,opts).then(function(r){
    if(r.status===401){localStorage.clear();location.href='/admin';return Promise.reject('unauthorized')}
    if(!r.ok)return r.json().then(function(d){return Promise.reject(d.error||'请求失败')}).catch(function(e){return Promise.reject(e==='unauthorized'?e:'请求失败')});
    return r.json();
  }).catch(function(e){if(e!=='unauthorized')showToast(String(e)||'网络错误',false);return Promise.reject(e)});
}

// ---- Modal ----
function _btn(text,cls,style,onClick){
  var b=document.createElement('button');b.className='btn '+(cls||'');
  if(style)b.style.cssText=style;b.textContent=text;
  if(onClick)b.addEventListener('click',onClick);return b;
}
function showModal(title,sub,contentHtml,footerBtns){
  closeModal();var m=document.createElement('div');m.className='modal-mask';
  var box=document.createElement('div');box.className='modal-box';
  var h3=document.createElement('h3');h3.textContent=title;box.appendChild(h3);
  var subEl=document.createElement('div');subEl.className='modal-sub';subEl.innerHTML=sub;box.appendChild(subEl);
  var ctn=document.createElement('div');ctn.innerHTML=contentHtml;box.appendChild(ctn);
  var footer=document.createElement('div');footer.className='modal-footer';
  (footerBtns||[]).forEach(function(b){footer.appendChild(b)});box.appendChild(footer);
  box.addEventListener('click',function(e){e.stopPropagation()});
  m.appendChild(box);document.body.appendChild(m);return{mask:m,box:box,ctn:ctn};
}
function closeModal(){var m=document.querySelector('.modal-mask');if(m)m.remove()}
function showConfirm(title,msg,onOk){
  showModal(title,'<p style="font-size:13px;color:var(--gray);line-height:1.6">'+msg+'</p>','',[
    _btn('取消','btn','',closeModal),_btn('确定','btn-danger','',function(){closeModal();onOk()})
  ]);
}

// ---- 导航 ----
var _views={changelog:'changelogView',enhance:'enhanceView',crashes:'crashView',feedback:'feedbackView',exports:'exportView'};
function setNavActive(n){document.querySelectorAll('.sidebar .nav a[data-nav]').forEach(function(a){a.classList.toggle('active',a.getAttribute('data-nav')===n)})}
function toggleSidebar(){var s=document.getElementById('sidebar');s.classList.toggle('open');document.getElementById('sideMask').classList.toggle('show',s.classList.contains('open'))}
function closeSidebar(){document.getElementById('sidebar').classList.remove('open');document.getElementById('sideMask').classList.remove('show')}
function showView(id){closeSidebar();Object.values(_views).forEach(function(v){document.getElementById(v).style.display=v===id?'block':'none'})}
function showChangelog(){showView('changelogView');setNavActive('changelog');loadChangelog()}
function showEnhance(){showView('enhanceView');setNavActive('enhance');loadEnhanceVideo()}
function showCrashes(){showView('crashView');setNavActive('crashes');loadCrashes()}
function showFeedback(){showView('feedbackView');setNavActive('feedback');loadFeedback()}
function showExports(){showView('exportView');setNavActive('exports');loadExportStats();loadExports(1);startExportTimer()}

// ---- 带图导出任务 ----
var _exportPage=1,_exportTimer=null,_exportErrors={};
var _exportTypeMap={movies:'影视',books:'阅读',games:'游戏',notes:'笔记'};
function startExportTimer(){
  if(_exportTimer)clearInterval(_exportTimer);
  _exportTimer=setInterval(function(){
    if(document.getElementById('exportView').style.display==='none'){clearInterval(_exportTimer);_exportTimer=null;return}
    loadExports(_exportPage);
  },5000);
}
function fmtDur(sec){
  if(!sec)return '-';
  if(sec>=60)return Math.floor(sec/60)+'分'+Math.round(sec%60)+'秒';
  return Math.round(sec)+'秒';
}
function loadExportStats(){
  apiFetch('/api/admin/export/stats').then(function(d){
    document.getElementById('esTotal').textContent=d.total_tasks;
    document.getElementById('esDevices').textContent=d.unique_devices;
    document.getElementById('esRate').textContent=d.success_rate+'%';
    document.getElementById('esDuration').textContent=fmtDur(d.avg_duration_seconds);
    var tp=(d.type_dist||[]).map(function(t){return (_exportTypeMap[t.types]||t.types)+' '+t.count}).join(' · ');
    document.getElementById('esTypes').textContent=tp||'-';
  }).catch(function(){});
}
function loadExports(page){
  page=page||1;_exportPage=page;
  var st=document.getElementById('exportStatusFilter').value;
  apiFetch('/api/admin/export-tasks?page='+page+(st?'&status='+st:'')).then(function(d){
    var l=document.getElementById('exportList');
    var c=d.counts||{};
    var h='<div style="font-size:11px;color:var(--light);margin-bottom:8px">排队 '+(c.queued||0)+' · 处理中 '+(c.processing||0)+' · 完成 '+(c.done||0)+' · 失败 '+(c.failed||0)+'</div>';
    if(!d.tasks||d.tasks.length===0){l.innerHTML=h+'<div class="empty">暂无导出任务</div>';return}
    _exportErrors={};
    h+='<div class="table-wrap"><table><tr><th>设备</th><th>类型</th><th>状态</th><th>语言</th><th>创建时间</th><th>完成时间</th><th>已下载</th></tr>';
    d.tasks.forEach(function(t){
      var tag;
      if(t.status==='queued')tag='<span class="tag">排队</span>';
      else if(t.status==='processing')tag='<span class="tag tag-info">处理中</span>';
      else if(t.status==='done')tag='<span class="tag tag-success">完成</span>';
      else tag='<span class="tag tag-danger">失败</span>';
      if(t.status==='failed'&&t.error){
        _exportErrors[t.id]=t.error;
        tag='<a class="link" href="#" onclick="showExportError(\''+t.id+'\')">'+tag+'</a>';
      }
      h+='<tr><td><code>'+t.device_hash.substring(0,16)+'…</code></td><td>'+(_exportTypeMap[t.types]||t.types)+'</td><td>'+tag+'</td><td>'+(t.lang||'zh')+'</td><td>'+fmtDate(t.created_at)+'</td><td>'+fmtDate(t.finished_at)+'</td><td>'+(t.downloaded?'✓':'-')+'</td></tr>';
    });
    h+='</table></div>'+buildPagination(d.total,d.per_page,page,'loadExports(PAGE)');l.innerHTML=h;
  }).catch(function(){});
}
function showExportError(id){
  if(typeof event!=='undefined'&&event)event.preventDefault();
  showModal('失败原因','','<p style="font-size:12px;color:var(--gray);line-height:1.6;word-break:break-all">'+escHtml(_exportErrors[id]||'')+'</p>',[_btn('关闭','btn','',closeModal)]);
}

// ---- 分页 ----
function buildPagination(total,perPage,cur,fnName){
  var tp=Math.ceil(total/perPage);
  if(tp<=1)return '<div style="text-align:center;margin-top:8px;font-size:11px;color:var(--light)">共 '+total+' 条</div>';
  var h='<div class="pagination">';
  if(cur>1)h+='<button onclick="'+fnName.replace('PAGE','1')+'">&#171;</button>';
  if(cur>1)h+='<button onclick="'+fnName.replace('PAGE',String(cur-1))+'">&#8249;</button>';
  var pages=[];
  if(tp<=7){for(var i=1;i<=tp;i++)pages.push(i)}
  else{pages.push(1);if(cur>3)pages.push('...');for(var i=Math.max(2,cur-1);i<=Math.min(tp-1,cur+1);i++)pages.push(i);if(cur<tp-2)pages.push('...');pages.push(tp)}
  pages.forEach(function(p){
    if(p==='...')h+='<span style="padding:0 4px;color:var(--light);font-size:11px">…</span>';
    else h+='<button class="'+(p===cur?'active':'')+'" onclick="'+fnName.replace('PAGE',String(p))+'">'+p+'</button>';
  });
  if(cur<tp)h+='<button onclick="'+fnName.replace('PAGE',String(cur+1))+'">&#8250;</button>';
  if(cur<tp)h+='<button onclick="'+fnName.replace('PAGE',String(tp))+'">&#187;</button>';
  h+='</div><div style="text-align:center;margin-top:4px;font-size:10px;color:var(--light)">共 '+total+' 条</div>';return h;
}

// ---- 修改密码 ----
function changePassword(){
  var html='<div class="el-form-item"><label>旧密码</label><input class="el-input" type="password" id="cpOld" placeholder="当前密码"></div><div class="el-form-item"><label>新密码</label><input class="el-input" type="password" id="cpNew" placeholder="至少6个字符"></div>';
  showModal('修改密码','',html,[
    _btn('取消','btn','',closeModal),
    _btn('确认','btn-black','',function(){
      var o=document.querySelector('#cpOld').value.trim(),n=document.querySelector('#cpNew').value.trim();
      if(!o||!n){showToast('请填写完整',false);return}
      if(n.length<6){showToast('新密码至少6个字符',false);return}
      apiFetch('/api/auth/change-password',{method:'POST',body:JSON.stringify({old_password:o,new_password:n})}).then(function(d){
        if(d.status==='ok'){closeModal();showToast('密码已修改',true)}else{showToast(d.error||'修改失败',false)}
      }).catch(function(){});
    })
  ]);
}
function logout(){localStorage.clear();location.href='/admin'}

// ---- 更新日志 ----
function loadChangelog(){
  apiFetch('/api/admin/changelog').then(function(d){
    var l=document.getElementById('changelogList');
    if(!d.items||d.items.length===0){l.innerHTML='<div class="empty">暂无更新日志</div>';return}
    var h='';
    d.items.forEach(function(c){
      h+='<div class="cl-item">';
      h+='<div class="cl-head"><div class="cl-meta">';
      h+='<span class="cl-version">'+escHtml(c.version)+'</span>';
      h+='<span class="cl-date">'+escHtml(c.date)+'</span>';
      h+='<span class="cl-order">#'+c.sort_order+'</span>';
      h+='</div><div class="cl-actions">';
      h+='<button class="btn btn-xs" onclick="editChangelog('+c.id+',\''+escHtml(c.version)+'\',\''+escHtml(c.date)+'\','+c.sort_order+',\''+encodeURIComponent(JSON.stringify(c.features))+'\')">编辑</button>';
      h+='<button class="btn btn-xs btn-danger" onclick="delChangelog('+c.id+')">删除</button>';
      h+='</div></div>';
      h+='<div class="cl-features">';
      (c.features||[]).forEach(function(f,i){h+='<div class="cl-feat"><span class="cl-feat-idx">'+(i+1)+'.</span><span>'+escHtml(f)+'</span></div>'});
      h+='</div></div>';
    });
    l.innerHTML=h;
  }).catch(function(){});
}
function addChangelog(){editChangelog(0,'','',0,[])}
function editChangelog(id,ver,date,order,feats){
  if(typeof feats==='string')feats=JSON.parse(decodeURIComponent(feats));
  var monthVal='';var mt=date.match(/(\d{4})年(\d{1,2})月/);if(mt)monthVal=mt[1]+'-'+mt[2].padStart(2,'0');
  var html='<div class="el-form-item"><label>版本号</label><input class="el-input" id="clVersion" value="'+escHtml(ver)+'" placeholder="v0.1.8"></div>';
  html+='<div style="display:flex;gap:8px"><div class="el-form-item" style="flex:1"><label>日期（年月）</label><input type="month" class="el-input" id="clDate" value="'+monthVal+'"></div><div class="el-form-item"><label>排序</label><input class="el-input" type="number" id="clOrder" value="'+order+'" placeholder="0" style="width:70px"></div></div>';
  html+='<div class="el-form-item"><label>功能列表（回车或粘贴添加）</label><div id="clTagsWrap" style="margin-bottom:8px;min-height:28px">';
  (feats.length?feats:['']).forEach(function(f,i){if(f)html+='<div class="feature-tag" data-val="'+escHtml(f)+'" style="display:flex;align-items:center;gap:6px;padding:4px 0;border-bottom:1px solid var(--border)"><span class="feat-grip" style="cursor:grab;color:var(--border);font-size:12px;user-select:none">⠿</span><span class="feat-idx" style="color:var(--light);font-size:11px;min-width:24px;text-align:right">'+(i+1)+'.</span><span style="flex:1;font-size:12px;color:var(--gray)">'+escHtml(f)+'</span><span class="rm" style="cursor:pointer;color:var(--light);font-size:14px">&times;</span></div>'});
  html+='</div><input class="el-input" id="clFeatInput" placeholder="输入后回车添加，或粘贴多行内容自动解析" style="width:100%"></div>';
  showModal(id?'编辑版本':'添加版本','',html,[
    _btn('取消','btn','',closeModal),
    _btn('保存','btn-black','',function(){
      var box=document.querySelector('.modal-box');
      var v=box.querySelector('#clVersion').value.trim(),mv=box.querySelector('#clDate').value;
      var d='';if(mv){var p=mv.split('-');d=p[0]+'年'+parseInt(p[1])+'月'}
      var o=parseInt(box.querySelector('#clOrder').value)||0;
      var lines=[];box.querySelectorAll('.feature-tag').forEach(function(t){lines.push(t.getAttribute('data-val'))});
      if(!v||!d){showToast('请填写版本号和日期',false);return}
      var body={version:v,date:d,sort_order:o,features:lines};if(id)body.id=id;
      apiFetch('/api/admin/changelog',{method:'POST',body:JSON.stringify(body)}).then(function(){closeModal();loadChangelog();showToast('已保存',true)}).catch(function(){});
    })
  ]);
  // 绑定已有标签的删除 + 拖拽
  var wrap=document.querySelector('#clTagsWrap');
  var _dragEl=null;
  function renumber(){
    wrap.querySelectorAll('.feature-tag').forEach(function(el,i){
      el.querySelector('.feat-idx').textContent=(i+1)+'.';
    });
  }
  function initDrag(el){
    el.setAttribute('draggable','true');
    el.querySelector('.feat-grip').addEventListener('mousedown',function(){el.setAttribute('draggable','true')});
    el.addEventListener('dragstart',function(e){
      _dragEl=el;el.style.opacity='.4';
      e.dataTransfer.effectAllowed='move';
    });
    el.addEventListener('dragend',function(){el.style.opacity='';_dragEl=null;
      wrap.querySelectorAll('.feature-tag').forEach(function(t){t.style.borderTop=''});
    });
    el.addEventListener('dragover',function(e){
      e.preventDefault();e.dataTransfer.dropEffect='move';
      if(el===_dragEl)return;
      wrap.querySelectorAll('.feature-tag').forEach(function(t){t.style.borderTop=''});
      el.style.borderTop='2px solid var(--black)';
    });
    el.addEventListener('dragleave',function(){el.style.borderTop=''});
    el.addEventListener('drop',function(e){
      e.preventDefault();el.style.borderTop='';
      if(!_dragEl||_dragEl===el)return;
      var rect=el.getBoundingClientRect();
      var mid=rect.top+rect.height/2;
      if(e.clientY<mid)wrap.insertBefore(_dragEl,el);
      else wrap.insertBefore(_dragEl,el.nextSibling);
      renumber();
    });
  }
  wrap.querySelectorAll('.feature-tag').forEach(function(el){
    el.querySelector('.rm').addEventListener('click',function(){el.remove();renumber()});
    initDrag(el);
  });
  // 绑定回车添加 + 粘贴解析
  var inp=document.querySelector('#clFeatInput');
  function addFeatureTag(val){
    val=val.replace(/^\d+[\.\、\)\s]+/,'').trim();if(!val)return;
    var idx=wrap.querySelectorAll('.feature-tag').length+1;
    var tag=document.createElement('div');tag.className='feature-tag';tag.setAttribute('data-val',val);
    tag.style.cssText='display:flex;align-items:center;gap:6px;padding:4px 0;border-bottom:1px solid var(--border)';
    tag.innerHTML='<span class="feat-grip" style="cursor:grab;color:var(--border);font-size:12px;user-select:none">⠿</span><span class="feat-idx" style="color:var(--light);font-size:11px;min-width:24px;text-align:right">'+idx+'.</span><span style="flex:1;font-size:12px;color:var(--gray)">'+escHtml(val)+'</span><span class="rm" style="cursor:pointer;color:var(--light);font-size:14px">&times;</span>';
    tag.querySelector('.rm').addEventListener('click',function(){tag.remove();renumber()});
    initDrag(tag);
    wrap.appendChild(tag);
  }
  function parseLines(text){
    text.split(/\r?\n/).forEach(function(line){addFeatureTag(line)});
  }
  if(inp&&wrap){
    inp.addEventListener('keydown',function(e){
      if(e.key==='Enter'){e.preventDefault();parseLines(this.value);this.value='';}
    });
    inp.addEventListener('paste',function(e){
      e.preventDefault();var text=(e.clipboardData||window.clipboardData).getData('text');
      parseLines(text);this.value='';
    });
    setTimeout(function(){inp.focus()},100);
  }
}
function delChangelog(id){
  showConfirm('删除版本','确定要删除该版本更新记录吗？',function(){
    apiFetch('/api/admin/changelog/'+id,{method:'DELETE'}).then(function(){loadChangelog();showToast('已删除',true)}).catch(function(){});
  });
}

// ---- 运行日志上报 ----
function loadCrashes(){
  apiFetch('/api/admin/crashes').then(function(d){
    var l=document.getElementById('crashList');
    if(!d.items||d.items.length===0){l.innerHTML='<div class="empty">暂无日志上报</div>';return}
    var h='';
    d.items.forEach(function(c){
      h+='<div class="cl-item">';
      h+='<div class="cl-head"><div class="cl-meta" style="flex-direction:column;align-items:flex-start;gap:4px;min-width:0">';
      h+='<span style="font-size:13px;font-weight:600;color:var(--black);word-break:break-all;line-height:1.4">'+escHtml(c.title||'(无标题)')+'</span>';
      h+='<span style="font-size:11px;color:var(--light);font-family:monospace">'+escHtml(c.signature)+'</span>';
      h+='</div><div class="cl-actions">';
      h+='<button class="btn btn-xs" onclick="viewCrash(\''+c.signature+'\')">详情</button>';
      h+='<button class="btn btn-xs btn-danger" onclick="delCrash(\''+c.signature+'\')">删除</button>';
      h+='</div></div>';
      h+='<div style="display:flex;flex-wrap:wrap;gap:6px 14px;font-size:11px;color:var(--gray)">';
      h+='<span>次数 <b style="color:var(--black)">'+c.count+'</b></span>';
      h+='<span>设备 <b style="color:var(--black)">'+c.devices+'</b></span>';
      if(c.versions&&c.versions.length)h+='<span>版本 '+c.versions.map(function(v){return escHtml(v.version)+'×'+v.count}).join('、')+'</span>';
      h+='<span>最近 '+fmtDate(c.last_seen)+'</span>';
      h+='</div></div>';
    });
    l.innerHTML=h;
  }).catch(function(){});
}
function viewCrash(sig){
  apiFetch('/api/admin/crashes/'+sig).then(function(d){
    var h='';
    (d.items||[]).forEach(function(r){
      h+='<div data-crash-id="'+r.id+'" style="border:1px solid var(--border);border-radius:var(--radius-sm);padding:10px 12px;margin-bottom:8px">';
      h+='<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:6px">';
      h+='<div style="font-size:11px;color:var(--light)">'+fmtDate(r.created_at)+' · '+escHtml(r.app_version||'?')+' · '+escHtml(r.device_type||'?')+'</div>';
      h+='<button class="btn btn-xs btn-danger" style="flex-shrink:0" onclick="delCrashOne(this,'+r.id+')">删除</button>';
      h+='</div>';
      h+='<pre style="font-size:11px;font-family:monospace;white-space:pre-wrap;word-break:break-all;margin:0;max-height:240px;overflow-y:auto;color:var(--gray)">'+escHtml(r.error)+'</pre>';
      h+='</div>';
    });
    if(!h)h='<div class="empty">无记录</div>';
    showModal('日志详情','<span style="font-family:monospace;font-size:11px">'+escHtml(sig)+'</span> · 最近 100 条',h,[_btn('关闭','btn','',function(){closeModal();loadCrashes()})]);
  }).catch(function(){});
}
// 单条删除：二次点击确认（showConfirm 会顶掉详情弹窗，故用行内确认）
function delCrashOne(btn,id){
  if(btn.dataset.armed){
    btn.disabled=true;
    apiFetch('/api/admin/crashes/id/'+id,{method:'DELETE'}).then(function(){
      var item=document.querySelector('[data-crash-id="'+id+'"]');
      if(item)item.remove();
      loadCrashes();
      if(!document.querySelector('[data-crash-id]'))closeModal();
      showToast('已删除',true);
    }).catch(function(){btn.disabled=false});
    return;
  }
  btn.dataset.armed='1';btn.textContent='确认删除';
  setTimeout(function(){if(btn.isConnected){delete btn.dataset.armed;btn.textContent='删除'}},2500);
}
function delCrash(sig){
  showConfirm('删除日志记录','确定删除该签名的全部日志记录吗？',function(){
    apiFetch('/api/admin/crashes/'+sig,{method:'DELETE'}).then(function(){loadCrashes();showToast('已删除',true)}).catch(function(){});
  });
}

// ---- 意见反馈 ----
var _fbStatus='';
function filterFeedback(s){
  _fbStatus=s;
  document.querySelectorAll('#fbTabs button').forEach(function(b){b.classList.toggle('active',b.getAttribute('data-status')===s)});
  loadFeedback();
}
function loadFeedback(){
  apiFetch('/api/admin/feedback'+(_fbStatus?('?status='+_fbStatus):'')).then(function(d){
    if(d.counts){
      var all=(d.counts.pending||0)+(d.counts.done||0);
      document.querySelectorAll('#fbTabs button').forEach(function(b){
        var st=b.getAttribute('data-status');
        var n=st===''?all:(d.counts[st]||0);
        b.textContent=(st===''?'全部':(st==='pending'?'待处理':'已处理'))+(n?' '+n:'');
      });
    }
    var l=document.getElementById('feedbackList');
    if(!d.items||d.items.length===0){l.innerHTML='<div class="empty">暂无反馈</div>';return}
    var h='';
    d.items.forEach(function(f){
      var pend=f.status==='pending';
      h+='<div class="cl-item">';
      h+='<div class="cl-head"><div class="cl-meta">';
      h+='<span style="font-size:10px;padding:2px 8px;border-radius:99px;flex-shrink:0;'+(pend?'background:#FFF3E0;color:#E65100':'background:#E8F5E9;color:#2E7D32')+'">'+(pend?'待处理':'已处理')+'</span>';
      h+='<span style="font-size:11px;color:var(--light)">'+escHtml(f.app_version||'')+(f.device_type?' · '+escHtml(f.device_type):'')+' · '+fmtDate(f.created_at)+'</span>';
      h+='</div><div class="cl-actions">';
      h+='<button class="btn btn-xs" onclick="replyFeedback('+f.id+')">回复</button>';
      h+='<button class="btn btn-xs btn-danger" onclick="delFeedback('+f.id+')">删除</button>';
      h+='</div></div>';
      h+='<div style="font-size:13px;color:var(--black);line-height:1.6;white-space:pre-wrap;word-break:break-word">'+escHtml(f.content)+'</div>';
      if(f.contact)h+='<div style="font-size:11px;color:var(--light);margin-top:6px">联系方式：'+escHtml(f.contact)+'</div>';
      if(f.reply)h+='<div style="margin-top:8px;padding:8px 12px;background:var(--accent-soft);border-left:2px solid var(--accent);border-radius:0 8px 8px 0;font-size:12px;color:var(--gray);white-space:pre-wrap">'+escHtml(f.reply)+'</div>';
      h+='</div>';
    });
    l.innerHTML=h;
  }).catch(function(){});
}
function replyFeedback(id){
  apiFetch('/api/admin/feedback').then(function(d){
    var f=null;(d.items||[]).forEach(function(x){if(x.id===id)f=x});
    if(!f){showToast('未找到该反馈',false);return}
    var html='<div style="font-size:12px;color:var(--gray);padding:10px 12px;background:var(--bg);border-radius:var(--radius-sm);margin-bottom:12px;white-space:pre-wrap">'+escHtml(f.content)+'</div>';
    html+='<div class="el-form-item"><label>回复内容（用户在 App 内可见）</label><textarea class="el-input" id="fbReply" rows="4" style="resize:vertical">'+escHtml(f.reply||'')+'</textarea></div>';
    html+='<div class="el-form-item"><label>状态</label><select class="el-input" id="fbStatus">'
      +'<option value="pending"'+(f.status==='pending'?' selected':'')+'>待处理</option>'
      +'<option value="done"'+(f.status==='done'?' selected':'')+'>已处理</option></select></div>';
    showModal('回复反馈','',html,[
      _btn('取消','btn','',closeModal),
      _btn('保存','btn-black','',function(){
        var box=document.querySelector('.modal-box');
        apiFetch('/api/admin/feedback/'+id,{method:'PUT',body:JSON.stringify({status:box.querySelector('#fbStatus').value,reply:box.querySelector('#fbReply').value.trim()})})
          .then(function(){closeModal();loadFeedback();showToast('已保存',true)}).catch(function(){});
      })
    ]);
  }).catch(function(){});
}
function delFeedback(id){
  showConfirm('删除反馈','确定删除这条反馈吗？',function(){
    apiFetch('/api/admin/feedback/'+id,{method:'DELETE'}).then(function(){loadFeedback();showToast('已删除',true)}).catch(function(){});
  });
}

// ---- 初始化 ----
showExports();

function loadEnhanceVideo(){
  apiFetch('/api/admin/enhance-video').then(function(d){
    document.getElementById('enhanceVideoInput').value=d.value||'';
    var s=document.getElementById('enhanceVideoStatus');
    if(d.updated_at){
      try{var dt=new Date(d.updated_at);if(isNaN(dt.getTime()))dt=new Date(d.updated_at+'Z');s.textContent='上次更新: '+fmtDate(d.updated_at)}catch(e){s.textContent=''}
    }else{s.textContent='未设置'}
  }).catch(function(e){showToast('加载失败: '+e,'error')});
}
function saveEnhanceVideo(){
  var value=document.getElementById('enhanceVideoInput').value;
  apiFetch('/api/admin/enhance-video',{method:'PUT',body:JSON.stringify({value:value})}).then(function(){
    showToast('保存成功','success');
    loadEnhanceVideo();
  }).catch(function(e){showToast('保存失败: '+e,'error')});
}

window.showChangelog=showChangelog;window.saveEnhanceVideo=saveEnhanceVideo;window.showEnhance=showEnhance;
window.showExports=showExports;window.loadExports=loadExports;window.showExportError=showExportError;
window.changePassword=changePassword;window.logout=logout;window.closeModal=closeModal;
window.editChangelog=editChangelog;window.addChangelog=addChangelog;window.delChangelog=delChangelog;
window.loadCrashes=loadCrashes;window.viewCrash=viewCrash;window.delCrash=delCrash;window.delCrashOne=delCrashOne;window.showCrashes=showCrashes;
window.loadFeedback=loadFeedback;window.filterFeedback=filterFeedback;window.replyFeedback=replyFeedback;window.delFeedback=delFeedback;window.showFeedback=showFeedback;
window.toggleSidebar=toggleSidebar;window.closeSidebar=closeSidebar;
})();
</script>
</body>
</html>"""

INDEX_HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>MookNote</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:'Inter',system-ui,-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#F5F7FB;display:flex;justify-content:center;align-items:center;min-height:100vh;-webkit-font-smoothing:antialiased}.card{background:#fff;border:1px solid #E9ECF2;padding:52px 56px;text-align:center;border-radius:18px;box-shadow:0 12px 40px rgba(23,26,33,.10)}h1{font-size:22px;color:#1F2430;margin-bottom:6px;font-weight:700;letter-spacing:-0.3px}p{font-size:12px;color:#9AA3B2;margin-bottom:28px;letter-spacing:0.5px}a{display:inline-block;padding:11px 34px;background:#4F6EF7;color:#fff;font-size:13px;font-weight:600;text-decoration:none;letter-spacing:0.3px;border-radius:11px;transition:background .18s,box-shadow .18s;box-shadow:0 4px 14px rgba(79,110,247,.32)}a:hover{background:#3D5CE8}</style>
</head><body><div class="card"><h1>MookNote Server</h1><p>服务端运行中</p><a href="/admin">管理后台</a></div></body></html>"""


def register_web_routes(app):
    @app.route("/", methods=["GET"])
    def index():
        return render_template_string(INDEX_HTML)

    @app.route("/admin", methods=["GET"])
    def admin_login_page():
        return render_template_string(LOGIN_HTML)

    @app.route("/admin/dashboard", methods=["GET"])
    def admin_dashboard():
        return render_template_string(DASHBOARD_HTML)
