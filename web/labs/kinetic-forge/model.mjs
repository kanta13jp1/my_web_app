// Educational 2D toy. Dimensionless coordinates, not engineering physics.
export const W=900,H=540,R=10,DT=1/120,MAX_LINES=40,MAX_TICKS=2400;
export const LEVELS=[
  {name:'一筆の坂',brief:'左の球を、右のリングへ。坂を描いて運ぼう。',spawn:[120,70],goal:[730,440,46],fixed:[],sample:[[80,180,760,440]]},
  {name:'折り返す道',brief:'球は右から。左向きの坂でリングへ導こう。',spawn:[780,60],goal:[155,440,46],fixed:[],sample:[[805,170,130,440]]},
  {name:'二段のリレー',brief:'2本の坂をつなぎ、落差を越えて運ぼう。',spawn:[120,50],goal:[690,440,48],fixed:[],sample:[[70,140,430,265],[430,320,740,440]]},
];
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
export function validateLines(input){
  if(!Array.isArray(input)||input.length>MAX_LINES)throw new Error('最大40本までです。');
  return input.map(line=>{
    if(!Array.isArray(line)||line.length!==4||line.some(v=>!Number.isFinite(v)))throw new Error('線の座標が不正です。');
    const a=line.map((v,i)=>clamp(v,0,i%2?H:W));
    if(Math.hypot(a[2]-a[0],a[3]-a[1])<4)throw new Error('線が短すぎます。');
    return a;
  });
}
export function create(level,lines=[]){
  if(!Number.isInteger(level)||level<0||level>=LEVELS.length)throw new Error('課題が不正です。');
  const l=LEVELS[level];
  return {level,lines:validateLines(lines),x:l.spawn[0],y:l.spawn[1],vx:0,vy:0,tick:0,status:'running',path:[]};
}
function contact(s,line){
  const [ax,ay,bx,by]=line,dx=bx-ax,dy=by-ay,len2=dx*dx+dy*dy;
  const t=clamp(((s.x-ax)*dx+(s.y-ay)*dy)/len2,0,1),px=ax+t*dx,py=ay+t*dy;
  let nx=s.x-px,ny=s.y-py,dist=Math.hypot(nx,ny);
  if(dist>=R+2)return;
  if(dist<1e-9){const len=Math.sqrt(len2);nx=-dy/len;ny=dx/len;if(nx*s.vx+ny*s.vy>0){nx=-nx;ny=-ny;}dist=0;}else{nx/=dist;ny/=dist;}
  s.x=px+nx*(R+2);s.y=py+ny*(R+2);
  const vn=s.vx*nx+s.vy*ny;
  if(vn<0){s.vx-=vn*nx;s.vy-=vn*ny;}
  s.vx*=0.999;s.vy*=0.999;
}
export function step(input){
  if(input.status!=='running')return input;
  const s={...input,path:[...input.path]};
  s.vy+=700*DT;
  const speed=Math.hypot(s.vx,s.vy);if(speed>500){s.vx*=500/speed;s.vy*=500/speed;}
  // 4 substeps keep displacement below the ball radius at the speed cap.
  for(let i=0;i<4;i++){
    s.x+=s.vx*DT/4;s.y+=s.vy*DT/4;
    for(let iteration=0;iteration<2;iteration++)for(const line of [...LEVELS[s.level].fixed,...s.lines])contact(s,line);
    const [gx,gy,gr]=LEVELS[s.level].goal;
    if(Math.hypot(s.x-gx,s.y-gy)<=gr-R){s.status='won';break;}
  }
  s.tick++;
  if(s.tick%4===0){s.path.push([s.x,s.y]);if(s.path.length>600)s.path.shift();}
  if(s.status!=='won'&&(s.x<-R||s.x>W+R||s.y>H+R||s.y<-H||s.tick>=MAX_TICKS))s.status='lost';
  if(![s.x,s.y,s.vx,s.vy].every(Number.isFinite))throw new Error('有限値でない状態を検出しました。');
  return s;
}
export function run(level,lines){let s=create(level,lines);while(s.status==='running')s=step(s);return s;}
