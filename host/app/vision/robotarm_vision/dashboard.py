"""Local observation and task-selection UI. No execution before commissioning."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import time
import signal
import shutil
import mimetypes
from urllib.parse import urlparse, parse_qs

import numpy as np
from .geometry import depth_point, Calibration
from .quality import sample_depth
from .target_lock import lock_target, review_lock, current_point
from .planning_client import start_job, load_job
from .collection import CollectionService
from .pickup import PickupService

ROOT=Path(__file__).resolve().parents[2]
TOKEN=secrets.token_urlsafe(24)
COLLECTION=CollectionService(ROOT)
PICKUP=PickupService(ROOT)
HTML='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>桌面工具拾取工作台</title>
<style>body{background:#101820;color:#e8f0f5;font:17px sans-serif;max-width:1100px;margin:30px auto}button,select{padding:12px;margin:8px 4px;background:#203846;color:white;border:1px solid #567;border-radius:6px}img{width:640px;max-width:100%;border-radius:10px}pre{white-space:pre-wrap;background:#192833;padding:16px}small{color:#aab}</style>
<p><a href="/" style="color:#9df">← 返回实地数据采集</a></p><h1>桌面工具拾取工作台</h1><p>实时素材采集请使用首页。本页显示检测与规划结果；检测推理暂停时，历史观测不可用于规划。</p><p>Gemini 2 · YOLO11n · 手部关键点 · AX7010</p>
<div style="display:flex;gap:12px"><figure style="margin:0;flex:1;min-width:0"><figcaption>彩色识别</figcaption><img id="camera" src="/stream/color" alt="等待视觉进程"></figure><figure style="margin:0;flex:1;min-width:0"><figcaption>对齐深度：蓝色近、红色远、黑色无效</figcaption><img id="depth" src="/stream/depth" alt="等待深度数据" onclick="measure(event)"></figure></div><p id="state">等待视觉数据</p><p id="measurement">点击深度图查看最近采样帧的距离和相机坐标；<a href="/depth.npz" style="color:#9df">下载原始米制深度及对应帧信息</a></p>
<label>目标类别 <select id="category"><option value="screwdriver">螺丝刀</option><option value="pliers">钳子</option><option value="scissors">剪刀 / 剪切工具</option><option value="tweezers">镊子</option><option value="pcb">PCB（待训练）</option></select></label>
<label>目标 ID <select id="target"><option value="">等待稳定目标</option></select></label>
<label hidden>交接区域 <select id="zone"><option value="">待标定</option></select></label>
<label hidden>接收手 ID <select id="hand"><option value="">等待稳定手部</option></select></label>
<p>当前任务：接近桌面工具 → 抓取 → 验证夹持 → 抬升并保持。手进入作业区时需要复核。</p>
<button onclick="prepare()">生成任务草案</button><button disabled title="完成外参、夹爪与真实控制器验收后开放">确认并执行（尚未开放）</button>
<p id="lockstate"></p><p id="linkstate">视觉传输尚未连接</p><p>三维表面采样点（米）：相机 X 向右、Y 向下、Z 向前。暂存点不可用于更新执行目标。</p>
<table style="width:100%;font-size:14px;border-collapse:collapse" border="1"><thead><tr><th>来源 / ID / 类别</th><th>状态 / 点龄</th><th>相机 XYZ（m）</th><th>基座 XYZ（m）</th></tr></thead><tbody id="coords"></tbody></table>
<label>抓取配置 <select id="profile"><option value="">待测量与审核</option></select></label>
<button onclick="planTask()">在 AI PC 生成轨迹（不执行）</button><button onclick="showDemo()">查看离线仿真规划</button>
<p id="planstate">等待规划；实测标定、夹爪和工作区配置尚未完成。</p>
<div>视角 <input id="yaw" type="range" min="-180" max="180" value="35" oninput="drawPlan()"> 俯仰 <input id="pitch" type="range" min="5" max="85" value="35" oninput="drawPlan()"></div>
<canvas id="planview" width="1000" height="400" style="width:100%;background:#192833;border-radius:8px"></canvas>
<pre id="planinfo">轨迹以机械臂基座为参照；缺少实测参数时只能查看明确标记的仿真结果。</pre>
<pre id="proposal">先按 ID 选择桌面工具和已审核的抓取配置。当前不会向电机发送命令。</pre><details><summary>检测数据</summary><pre id="data"></pre></details>
<small>检测框中心是表面采样点，不是抓取位姿。手部检测仅为辅助提示。</small>
<script>
const token='TOKEN_VALUE';let taskId=null;let planId=null;let activePlan=null;
const xyz=p=>Array.isArray(p)?p.map(v=>Number(v).toFixed(4)).join(', '):'无有效三维点';
function table(d){const body=document.getElementById('coords');body.replaceChildren();const handFresh=d.fresh&&Date.now()/1000-d.observation.captured_at_unix_s<=.15;
function row(label,state,pc,pb){const tr=document.createElement('tr');for(const v of [label,state,xyz(pc),xyz(pb)]){const td=document.createElement('td');td.textContent=v;td.style.padding='7px';tr.append(td)}body.append(tr)}
const age=(o,stamp)=>o.coordinate_age_ms==null?null:o.coordinate_age_ms+Math.max(0,Date.now()/1000-(stamp||0))*1000;
const ageText=a=>a==null?'—':(a>=1000?(a/1000).toFixed(1)+' s':a.toFixed(0)+' ms');
const labels={tentative:'确认中',tracked:'跟踪',held:'暂存 / 禁用',jump_rejected:'拒绝跳变',missing_depth:'深度缺失',reacquiring:'重新确认',expired:'已过期'};
for(const o of d.observation.detections||[])row('当前 #'+o.track_id+' '+o.class_name,(d.fresh?(labels[o.tracking_status]||'未稳定'):'历史 / 禁用')+' · '+ageText(age(o,d.observation.captured_at_unix_s))+(d.fresh&&o.coordinate_usable&&age(o,d.observation.captured_at_unix_s)<=150?'':' · 不可更新目标'),o.surface_point_camera_m,o.surface_point_base_m);
for(const h of d.observation.hands||[]){row('接收手 #'+h.track_id+' 掌部',handFresh&&h.palm_stable?'已停稳 / 仍需区域检查':'未稳定或过期',h.palm_camera_m,h.palm_base_m);for(const k of (h.keypoints||[]).filter(p=>[0,8].includes(p.id)))row('手 #'+h.track_id+' 点 '+k.id,(d.fresh&&k.coordinate_fresh&&age(k,d.observation.captured_at_unix_s)<=200?'本帧测量':'暂存 / 禁用')+' · '+ageText(age(k,d.observation.captured_at_unix_s)),k.camera_m,k.base_m)}
const link=d.link||{};document.getElementById('linkstate').textContent=link.fresh?'PS 已确认接收，帧 '+link.payload.frame_id+'（仅观测，不执行）':'传输：'+link.state+'；无新鲜接收确认';
for(const o of link.payload?.detections||[])row('PS 最后确认 #'+o.track_id+' '+o.class_name,(link.fresh?'已确认':'历史 / 过期')+' · '+ageText(age(o,link.sent_at_unix_s)),o.surface_point_camera_m,o.surface_point_base_m);
for(const h of link.payload?.hands||[]){for(const k of h.keypoints.filter(p=>[0,8].includes(p.id)))row('PS 手 #'+h.track_id+' 点 '+k.id,link.fresh?'已确认':'历史 / 过期',k.camera_m,k.base_m)}
const select=document.getElementById('target'),old=select.value;select.replaceChildren();let empty=document.createElement('option');empty.value='';empty.textContent='请选择具体目标';select.append(empty);
for(const o of d.observation.detections||[]){if(o.class_name!==document.getElementById('category').value)continue;let opt=document.createElement('option');opt.value=o.track_id;opt.textContent='#'+o.track_id+' '+o.class_name+(o.coordinate_usable?'':'（未稳定）');select.append(opt)}select.value=old;
const hs=document.getElementById('hand'),hid=hs.value;hs.replaceChildren();const he=document.createElement('option');he.value='';he.textContent='请选择接收手';hs.append(he);for(const h of d.observation.hands||[]){const o=document.createElement('option');o.value=h.track_id;o.textContent='#'+h.track_id+' '+h.handedness+(handFresh&&h.palm_stable?'（已停稳）':'（未稳定）');hs.append(o)}hs.value=hid;
} 
async function update(){try{const r=await fetch('/api/status');const d=await r.json();table(d);const profile=document.getElementById('profile'),chosen=profile.value;profile.replaceChildren();for(const name of d.grasp_profiles||[]){let o=document.createElement('option');o.value=name;o.textContent=name;profile.append(o)}if(!profile.options.length){let o=document.createElement('option');o.value='';o.textContent='待测量与审核';profile.append(o)}else profile.value=chosen||profile.options[0].value;if(taskId){const lock=await(await fetch('/api/task/'+taskId)).json();document.getElementById('lockstate').textContent='锁定 #'+lock.track_id+'：'+lock.reason}document.getElementById('data').textContent=JSON.stringify(d.observation,null,2);document.getElementById('state').textContent=d.fresh?'视觉在线（'+(d.observation.source_kind||'旧格式')+'） | '+Number(d.observation.processed_fps||0).toFixed(1)+' FPS | 深度有效 '+(100*(d.observation.depth_valid_ratio||0)).toFixed(0)+'% | 检测到手：'+Boolean(d.observation.hand_present):'视觉数据缺失或已过期';const z=document.getElementById('zone'),old=z.value;z.replaceChildren();for(const name of d.zones){let o=document.createElement('option');o.value=name;o.textContent=name;z.append(o)}if(!d.zones.length){let o=document.createElement('option');o.value='';o.textContent='待标定';z.append(o)}else z.value=old||d.zones[0];}catch(e){document.getElementById('state').textContent='视觉服务离线'}}
async function prepare(){const r=await fetch('/api/propose',{method:'POST',headers:{'Content-Type':'application/json','X-Task-Token':token},body:JSON.stringify({hand_track_id:document.getElementById('hand').value?Number(document.getElementById('hand').value):null,category:document.getElementById('category').value,zone:document.getElementById('zone').value,track_id:document.getElementById('target').value?Number(document.getElementById('target').value):null})});const task=await r.json();taskId=task.task_id;document.getElementById('proposal').textContent=JSON.stringify(task,null,2)}
async function measure(e){const img=e.target,r=img.getBoundingClientRect();const u=Math.floor((e.clientX-r.left)*img.naturalWidth/r.width),v=Math.floor((e.clientY-r.top)*img.naturalHeight/r.height);const d=await (await fetch('/api/point?u='+u+'&v='+v)).json();document.getElementById('measurement').textContent=JSON.stringify(d)}
async function planTask(){try{const r=await fetch('/api/plan',{method:'POST',headers:{'Content-Type':'application/json','X-Task-Token':token},body:JSON.stringify({task_id:taskId,profile:document.getElementById('profile').value})});const d=await r.json();if(!r.ok)throw Error(d.error);planId=d.job_id;pollPlan()}catch(e){document.getElementById('planstate').textContent='无法规划：'+e.message}}
async function pollPlan(){if(!planId)return;try{const p=await(await fetch('/api/planning/jobs/'+planId)).json();showPlan(p);if(['queued','planning'].includes(p.status)||(p.mode==='measured'&&p.task_kind==='tool_handover'&&['planned_for_review','requires_review'].includes(p.status)))setTimeout(pollPlan,500)}catch(e){document.getElementById('planstate').textContent=e.message}}
async function showDemo(){const r=await fetch('/api/planning/demo');const p=await r.json();if(!r.ok){document.getElementById('planstate').textContent=p.error;return}showPlan(p)}
const stageNames={approach:'接近',grasp:'下探抓取',lift:'抬升',transfer:'递送接近',present:'手边停稳等待',place:'放置',retreat:'撤离'};
function showPlan(p){activePlan=p;const names={queued:'排队',planning:'正在规划',planned_for_review:'规划完成，等待检查',requires_review:'需要重新确认目标',failed:'规划失败'};document.getElementById('planstate').textContent=(p.mode==='synthetic_test'?'离线仿真 / 测试几何，不是实物标定。 ':'')+(names[p.status]||p.status||'')+' '+(stageNames[p.stage]||p.error||'')+'；未发送电机命令';const lines=['基座目标 XYZ（m）：'+xyz(p.point_base_m),'各阶段轨迹时长合计：'+Number(p.duration_s||0).toFixed(2)+' s（不含夹爪动作与等待）'];for(const segment of p.segments||[])lines.push((stageNames[segment.name]||segment.name)+'：TCP XYZ '+xyz(segment.tcp_pose_base.position_m)+' m；'+segment.trajectory.points.at(-1).time_s.toFixed(2)+' s');if(p.handover){lines.push('阶段① 拾取工具：接近 → 抓取 → 抬升；闭爪反馈后重新检查接收手并确认递送');lines.push('阶段② 递送：接近手边 → 停稳等待；无自动松爪/撤离');lines.push('冻结接收手 #'+p.handover.hand_lock.track_id+'；掌部基座 XYZ '+xyz(p.handover.palm_base_m)+' m');lines.push('递送 TCP 基座 XYZ '+xyz(p.handover.tcp_pose_base.position_m)+' m（已加手边偏移）');lines.push('手部三维包络参与碰撞检查；接稳确认后另行松爪并规划撤离');}else if(p.task_kind==='tabletop_pickup'){lines.push('桌面拾取：接近 → 下探 → 闭爪并验证夹持 → 抬升后保持；无放置、递送或自动松爪');}else if(p.events)lines.push('夹爪事件：接近前打开 → 抓取后闭合 → 放置后打开（仅规划）');if(p.target_review)lines.push('目标复核：'+p.target_review.reason);document.getElementById('planinfo').textContent=lines.join('\\n');drawPlan()}

function drawPlan(){const c=document.getElementById('planview'),g=c.getContext('2d');g.clearRect(0,0,c.width,c.height);if(!activePlan?.segments)return;const paths=activePlan.segments.map(s=>s.tcp_path_base_m||[s.tcp_pose_base.position_m]),points=paths.flat(),region=activePlan.handover_region,corners=region?Array.from({length:8},(_,i)=>[0,1,2].map(a=>(i&(1<<a))?region.max_m[a]:region.min_m[a])):[];points.push(...corners);if(activePlan.handover)points.push(activePlan.handover.palm_base_m);if(!points.length)return;const yaw=Number(document.getElementById('yaw').value)*Math.PI/180,pitch=Number(document.getElementById('pitch').value)*Math.PI/180;
const rot=p=>{const x=Math.cos(yaw)*p[0]-Math.sin(yaw)*p[1],y=Math.sin(yaw)*p[0]+Math.cos(yaw)*p[1];return [x,Math.cos(pitch)*p[2]-Math.sin(pitch)*y]};const projected=points.map(rot),lo=[0,1].map(i=>Math.min(...projected.map(p=>p[i]))),hi=[0,1].map(i=>Math.max(...projected.map(p=>p[i]))),scale=Math.min(850/Math.max(.03,hi[0]-lo[0]),280/Math.max(.03,hi[1]-lo[1]));const xy=p=>{const v=rot(p);return [500+(v[0]-(lo[0]+hi[0])/2)*scale,210-(v[1]-(lo[1]+hi[1])/2)*scale]};const colors=['#70c4ff','#ffd166','#8bd450','#b69cff','#ff8e8e','#70e1c3'];g.font='15px sans-serif';g.fillStyle='#ddd';g.fillText('基座坐标下的 TCP 轨迹（投影视图，单位 m）',18,24);paths.forEach((path,i)=>{g.strokeStyle=colors[i];g.lineWidth=2;g.beginPath();path.forEach((p,j)=>{const [x,y]=xy(p);j?g.lineTo(x,y):g.moveTo(x,y)});g.stroke();const [x,y]=xy(path.at(-1));g.fillStyle=colors[i];g.beginPath();g.arc(x,y,4,0,2*Math.PI);g.fill();g.fillText((i+1)+' '+(stageNames[activePlan.segments[i].name]||activePlan.segments[i].name),18+i*160,385)});if(region){g.strokeStyle='#738da1';g.setLineDash([4,4]);corners.forEach((p,i)=>[0,1,2].forEach(a=>{const j=i^(1<<a);if(i<j){g.beginPath();g.moveTo(...xy(p));g.lineTo(...xy(corners[j]));g.stroke()}}));g.setLineDash([]);g.fillStyle='#aab';g.fillText('虚线：固定交接区域',18,48)}if(activePlan.handover){const [x,y]=xy(activePlan.handover.palm_base_m);g.fillStyle='#ffb4dc';g.beginPath();g.arc(x,y,6,0,2*Math.PI);g.fill();g.fillText('接收手（冻结）',x+10,y-8)}}
setInterval(update,250);update();</script></html>'''


def observation():
    try:return json.loads((ROOT/'runtime/vision/latest.json').read_text())
    except (OSError,ValueError):return {}


def proposal(category,zone,obs,workspace,track_id=None,planning=None,hand_track_id=None):
    blockers=[]
    handover=None;is_handover=(planning or {}).get('task_kind')=='tool_handover'
    is_pickup=(planning or {}).get('task_kind')=='tabletop_pickup'
    if category not in {'screwdriver','pliers','scissors','tweezers','pcb'}:raise ValueError('Unknown category')
    age=time.time()-obs.get('captured_at_unix_s',0)
    if not 0<=age<.5:blockers.append('视觉帧缺失或超过0.5秒')
    if category not in obs.get('supported_tool_classes',[]):blockers.append('当前权重未训练此类别')
    targets=[d for d in obs.get('detections',[]) if d['class_name']==category]
    if track_id is not None:targets=[d for d in targets if d.get('track_id')==track_id]
    target=targets[0] if len(targets)==1 else None
    if len(targets)>1:blockers.append('同类物体有多个，请按目标 ID 选择')
    if target is None:blockers.append('画面中没有检测到所选类别')
    if target and not current_point(obs,target):blockers.append('目标三维坐标未稳定或正在暂存，不能作为新执行坐标')
    if target and target.get('stable') is not True:blockers.append('目标尚未连续稳定检出')
    if target and not target.get('depth_quality',{}).get('valid'):blockers.append('目标采样深度缺失或位于深度边缘')
    if not obs.get('base_calibration_valid'):blockers.append('相机到机械臂基座外参尚未验证')
    if is_handover:
        try:
            from robotarm_planning.handover import freeze_hand
            if not planning.get('validated'):raise ValueError('工作空间与固定交接区尚未标定')
            if type(hand_track_id) is not int:raise ValueError('请选择具体的接收手 ID')
            station=json.loads((ROOT/'config/vision_station.json').read_text())
            cal=Calibration(ROOT/'config/calibration/camera_to_base.json')
            context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
                     'setup_id':station.get('setup_id'),'camera_fixed':station.get('camera_fixed')}
            if not cal.compatible(obs.get('camera_serial'),context):raise ValueError('手部基座标定无效')
            handover=freeze_hand(obs,planning,zone,cal.matrix,hand_track_id)
        except (ValueError,KeyError,TypeError) as exc:blockers.append(str(exc))
    else:
        if is_pickup:
            if not (planning or {}).get('validated'):blockers.append('桌面拾取工作空间与抓取配置尚未验证')
        elif not workspace.get('validated') or zone not in workspace.get('place_zones',{}):blockers.append('工作空间与放置区尚未标定')
        if obs.get('hand_present'):blockers.append('画面中检测到手，请人工检查作业区')
    if not workspace.get('gripper',{}).get('tcp_calibrated'):blockers.append('夹爪模型与工具中心点尚未标定')
    planning_blockers=list(blockers)
    blockers.append('真实夹爪/控制器与执行反馈未验收；规划结果仅供检查')
    return {'task_id':secrets.token_hex(8),'created_at':time.time(),'category':category,'place_zone':zone,
            'task_kind':'tool_handover' if is_handover else 'tabletop_pickup' if is_pickup else 'pick_place','hand_track_id':hand_track_id,'handover':handover,
            'candidate':target,'target_lock':lock_target(obs,target) if target else None,'status':'blocked' if planning_blockers else 'ready_for_planning','execution_enabled':False,'blockers':blockers}


class Handler(BaseHTTPRequestHandler):
    def collection_stream(self,kind):
        if kind not in ['color','depth']:self.respond(404,{'error':'Unknown stream'});return
        self.send_response(200);self.send_header('Content-Type','multipart/x-mixed-replace; boundary=frame')
        self.send_header('Cache-Control','no-store');self.end_headers();last=None
        try:
            while True:
                preview=COLLECTION.preview(kind)
                if preview and preview[1] and preview[0]!=last:
                    last,content=preview
                    self.wfile.write(b'--frame\r\nContent-Type: image/jpeg\r\nContent-Length: '+str(len(content)).encode()+b'\r\n\r\n'+content+b'\r\n')
                    self.wfile.flush()
                if COLLECTION.camera_state not in ['starting','running']:break
                time.sleep(.01)
        except (BrokenPipeError,ConnectionResetError):pass

    def stream(self,kind):
        path=ROOT/'runtime/vision'/('depth.jpg' if kind=='depth' else 'latest.jpg')
        self.send_response(200)
        self.send_header('Content-Type','multipart/x-mixed-replace; boundary=frame')
        self.send_header('Cache-Control','no-store');self.end_headers()
        last=None
        try:
            while True:
                if path.exists():
                    stamp=path.stat().st_mtime_ns
                    if stamp!=last:
                        content=path.read_bytes();last=stamp
                        self.wfile.write(b'--frame\r\nContent-Type: image/jpeg\r\nContent-Length: '+str(len(content)).encode()+b'\r\n\r\n'+content+b'\r\n')
                        self.wfile.flush()
                time.sleep(0.010)
        except (BrokenPipeError,ConnectionResetError):pass

    def respond(self,status,data,content_type='application/json'):
        if not isinstance(data,bytes):data=json.dumps(data,ensure_ascii=False,allow_nan=False).encode()
        self.send_response(status);self.send_header('Content-Type',content_type)
        self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(data)))
        self.end_headers();self.wfile.write(data)

    def do_GET(self):
        path=self.path.split('?')[0]
        if path in ['/','/collect']:
            page=Path(__file__).with_name('collection.html').read_text()
            self.respond(200,page.replace('TOKEN_VALUE',TOKEN).encode(),'text/html; charset=utf-8')
        elif path in ['/pickup','/workbench']:
            page=Path(__file__).with_name('pickup.html').read_text()
            self.respond(200,page.replace('TOKEN_VALUE',TOKEN).encode(),'text/html; charset=utf-8')
        elif path=='/planning':self.respond(200,HTML.replace('TOKEN_VALUE',TOKEN).encode(),'text/html; charset=utf-8')
        elif path=='/api/pickup/status':self.respond(200,PICKUP.status())
        elif path=='/api/pickup/image':
            try:self.respond(200,PICKUP.image(parse_qs(urlparse(self.path).query).get('id',[''])[0]),'image/jpeg')
            except ValueError as exc:self.respond(404,{'error':str(exc)})
        elif path=='/api/collection/status':self.respond(200,COLLECTION.status())
        elif path=='/api/collection/sessions':self.respond(200,{'sessions':COLLECTION.sessions()})
        elif path.startswith('/collection/stream/'):self.collection_stream(path.rsplit('/',1)[-1])
        elif path=='/api/collection/file':
            try:
                query=parse_qs(urlparse(self.path).query)
                file=COLLECTION.file_path(query.get('session',[''])[0],query.get('path',[''])[0])
                content_type=mimetypes.guess_type(file.name)[0] or 'application/octet-stream'
                self.send_response(200);self.send_header('Content-Type',content_type)
                self.send_header('Content-Length',str(file.stat().st_size))
                self.send_header('X-Content-Type-Options','nosniff')
                if file.suffix in ['.avi','.npz']:self.send_header('Content-Disposition',f'attachment; filename="{file.name}"')
                self.end_headers()
                with file.open('rb') as source:shutil.copyfileobj(source,self.wfile)
            except ValueError as exc:self.respond(400,{'error':str(exc)})
            except (BrokenPipeError,ConnectionResetError):pass
        elif path=='/api/status':
            obs=observation();workspace=json.loads((ROOT/'config/workspace.json').read_text())
            age=time.time()-obs.get('captured_at_unix_s',0)
            try:link=json.loads((ROOT/'runtime/vision/link_status.json').read_text())
            except (OSError,ValueError):link={'state':'not_connected'}
            link['fresh']=link.get('state')=='acknowledged' and time.time()<link.get('expires_at_unix_s',0)
            planning=json.loads((ROOT/'config/planning.json').read_text())
            zones=[] if planning.get('task_kind')=='tabletop_pickup' else list(planning.get('handover_regions',{})) if planning.get('task_kind')=='tool_handover' else list(planning.get('place_zones',{})) if planning.get('validated') else list(workspace['place_zones'])
            self.respond(200,{'observation':obs,'fresh':0<=age<.5,'zones':zones,'link':link,
                             'planning_configured':planning.get('validated') is True,'grasp_profiles':list(planning.get('grasp_profiles',{}))})
        elif path.startswith('/api/task/'):
            task_id=path.rsplit('/',1)[-1]
            if len(task_id)!=16 or any(c not in '0123456789abcdef' for c in task_id):self.respond(400,{'error':'Invalid task ID'});return
            try:
                task=json.loads((ROOT/'runtime/tasks'/(task_id+'.json')).read_text())
                from .planning_client import review_task
                self.respond(200,review_task(task,observation()))
            except (OSError,ValueError):self.respond(404,{'error':'Task missing'})
        elif path=='/api/planning/demo':
            try:self.respond(200,json.loads((ROOT/'runtime/planning/pickup_result.json').read_text()))
            except (OSError,ValueError):self.respond(404,{'error':'离线规划验证结果尚未生成'})
        elif path.startswith('/api/planning/jobs/'):
            try:self.respond(200,load_job(path.rsplit('/',1)[-1]))
            except (OSError,ValueError):self.respond(404,{'error':'规划任务不存在'})
        elif path=='/image':
            p=ROOT/'runtime/vision/latest.jpg'
            self.respond(200,p.read_bytes(),'image/jpeg') if p.is_file() else self.respond(404,{'error':'No image'})
        elif path in ['/stream/color','/stream/depth']:
            self.stream(path.rsplit('/',1)[1])
        elif path=='/depth.npz':
            p=ROOT/'runtime/vision/depth.npz'
            self.respond(200,p.read_bytes(),'application/octet-stream') if p.exists() else self.respond(404,{'error':'No depth'})
        elif path=='/api/point':
            try:
                query=parse_qs(urlparse(self.path).query)
                u,v=int(query['u'][0]),int(query['v'][0])
                with np.load(ROOT/'runtime/vision/depth.npz',allow_pickle=False) as data:
                    meta=json.loads(str(data['metadata']));depth=data['depth_m']
                    if not 0<=u<depth.shape[1] or not 0<=v<depth.shape[0]:raise ValueError('Pixel outside image')
                    age=time.time()-meta['captured_at_unix_s']
                    if not 0<=age<2:raise ValueError('Depth snapshot is stale')
                    quality=sample_depth(depth,[u,v],meta['camera_intrinsics'],meta['camera_distortion'])
                    self.respond(200,{'pixel':[u,v],'camera_m':quality['point_camera_m'],'depth_quality':quality,'frame_id':meta['frame_id'],
                        'age_ms':age*1000,'note':'最近深度采样帧；不是点击瞬间的屏幕冻结帧，也不是抓取位姿'})
            except (OSError,ValueError,KeyError,IndexError) as exc:self.respond(400,{'error':str(exc)})
        else:self.respond(404,{'error':'Not found'})

    def do_POST(self):
        collection_actions=['preview_start','preview_stop','new_session','snapshot','record_start','record_stop']
        pickup_actions=['freeze','choose','send']
        if self.path not in ['/api/propose','/api/plan']+['/api/collection/'+a for a in collection_actions]+['/api/pickup/'+a for a in pickup_actions]:self.respond(404,{'error':'Not found'});return
        if not secrets.compare_digest(self.headers.get('X-Task-Token',''),TOKEN):self.respond(403,{'error':'Invalid task token'});return
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=4096:raise ValueError('Invalid request size')
            data=json.loads(self.rfile.read(length))
            if not isinstance(data,dict):raise ValueError('JSON object required')
            if self.path.startswith('/api/pickup/'):
                action=self.path.rsplit('/',1)[-1]
                result=PICKUP.freeze(data.get('track_id')) if action=='freeze' else PICKUP.choose(data.get('snapshot_id'),data.get('pixel')) if action=='choose' else PICKUP.send(data.get('target_id'),data.get('confirmed'))
                self.respond(200,result);return
            if self.path.startswith('/api/collection/'):
                action=self.path.rsplit('/',1)[-1]
                result=COLLECTION.start_preview() if action=='preview_start' else COLLECTION.stop_preview() if action=='preview_stop' else COLLECTION.submit(action,data)
                self.respond(200,result);return
            if self.path=='/api/plan':
                self.respond(202,start_job(data.get('task_id'),data.get('profile')));return
            workspace=json.loads((ROOT/'config/workspace.json').read_text());cfg=json.loads((ROOT/'config/planning.json').read_text())
            if cfg.get('validated'):workspace.update(validated=True,place_zones=cfg['place_zones'],gripper=cfg['gripper'])
            task=proposal(data['category'],data.get('zone',''),observation(),workspace,data.get('track_id'),cfg,data.get('hand_track_id'))
            folder=ROOT/'runtime/tasks';folder.mkdir(exist_ok=True,parents=True)
            (folder/(task['task_id']+'.json')).write_text(json.dumps(task,ensure_ascii=False,indent=2))
            self.respond(200,task)
        except (OSError,ValueError,KeyError,TypeError,ConnectionError) as exc:self.respond(400,{'error':str(exc)})


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8080);args=parser.parse_args()
    print(f'Local task dashboard: http://127.0.0.1:{args.port}',flush=True)
    def shutdown(signum,frame):raise KeyboardInterrupt
    signal.signal(signal.SIGTERM,shutdown)
    try:
        with ThreadingHTTPServer(('127.0.0.1',args.port),Handler) as server:
            try:server.serve_forever()
            except KeyboardInterrupt:pass
    finally:COLLECTION.close()


if __name__=='__main__':main()
