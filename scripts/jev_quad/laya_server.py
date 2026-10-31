"""Loopback-only official Laya CPU runtime; no private input or credential storage."""
import json,time,hashlib,platform,os
from pathlib import Path
from http.server import BaseHTTPRequestHandler,HTTPServer
import torch
from huggingface_hub import snapshot_download
from laya import Agent
from laya.common import build_sequence,render_options,serialize_state
REV='1c5edc17a7acd8701df6fc341c0d179f1c62c982'
torch.set_num_threads(2)
model_dir=snapshot_download('convaiinnovations/laya',revision=REV,allow_patterns=['rl_agent_config.json','model.safetensors','tokenizer/*','encoder/*'])
agent=Agent(model_dir,device='cpu')
out=Path('out/quad');out.mkdir(parents=True,exist_ok=True)
weight=Path(model_dir)/'model.safetensors'
h=hashlib.sha256()
with weight.open('rb') as f:
 for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
(out/'laya-provenance.json').write_text(json.dumps({'model':'convaiinnovations/laya','revision':REV,'source':'573e5b62696ba441230cd6be71d593331b5d23af','weights_sha256':h.hexdigest(),'torch':torch.__version__,'device':'cpu','threads':2,'python':platform.python_version(),'warmup':'one empty-state control query; loading excluded'},indent=2))
teacher=json.loads(Path('scripts/jev_distillation/teacher.json').read_text())
question={'controller':{'type':'choice','instructions':teacher['teacher_instructions'].replace('6 simulation frames (100 ms','30 simulation frames (500 ms'),'criteria':teacher['teacher_criteria']}}
agent.system_one({},question)
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  self.send_response(200);self.end_headers();self.wfile.write(b'ready')
 def do_POST(self):
  try:
   body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
   state=body['state'];q=agent._to_internal(body['questions']['controller'])
   max_len=agent.cfg.get('max_len',512);head=agent.cfg.get('head_max_len',192)
   empty,_=build_sequence(agent.tok,'',q,max_len,head)
   ids,markers=build_sequence(agent.tok,state,q,max_len,head)
   state_tokens=len(agent.tok(serialize_state(state),add_special_tokens=False)['input_ids'])
   budget=max_len-len(empty)
   before=time.perf_counter();result=agent.system_one(state,body['questions']);elapsed=(time.perf_counter()-before)*1000
   result['laya_compute_ms']=elapsed
   result['laya_input']={'state_tokens':state_tokens,'state_budget':budget,'truncated':state_tokens>budget,'encoded_tokens':len(ids),'options':len(markers),'question_and_options_tokens':len(empty),'max_tokens':max_len}
   encoded=json.dumps(result).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(encoded)
  except BrokenPipeError:pass
  except Exception as exc:
   self.send_response(500);self.end_headers();self.wfile.write(json.dumps({'error':type(exc).__name__}).encode())
HTTPServer(('127.0.0.1',8081),Handler).serve_forever()
