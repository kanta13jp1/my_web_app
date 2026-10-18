import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const $ = id => document.getElementById(id);
let renderer, scene, camera, wheel, count = 0, angle = 0, state = 'loading';
let generation = 0;
const buttons = ['turn','reset','left','right'];
function draw(){ if(renderer) renderer.render(scene,camera); }
function resize(){
  if(!renderer) return;
  const box=$('scene').getBoundingClientRect();
  camera.aspect=box.width/box.height; camera.updateProjectionMatrix();
  renderer.setSize(box.width,box.height,false); draw();
}
function update(){
  $('status').textContent=count===3?'水路が開きました。バルブ操作、完了です。':`水路は閉じています。あと${3-count}回、ハンドルを回してください。`;
  document.querySelectorAll('.meter span').forEach((e,i)=>e.classList.toggle('on',i<count));
  $('turn').disabled=count===3;
  if(wheel) wheel.rotation.y=-count*Math.PI/2;
  document.body.dataset.turns=String(count); draw();
}
function ready(mode){
  state=mode; document.body.dataset.mode=mode;
  buttons.forEach(id=>$(id).disabled=false);
  $('left').disabled=$('right').disabled=mode!=='3d';
  $('load').textContent=mode==='3d'?'Blenderで制作した3Dモデル · 左右のボタンで視点を変更':'3D表示を利用できないため、静止画で体験できます。';
  update();
}
function fallback(){
  renderer?.dispose(); renderer=undefined; wheel=undefined;
  $('scene').hidden=true; $('fallback').style.display='block'; $('retry').hidden=false;
  ready('fallback');
}
async function load(){
  const token=++generation; state='loading';
  buttons.forEach(id=>$(id).disabled=true); $('retry').hidden=true;
  $('scene').hidden=false; $('fallback').style.display='none';
  $('load').textContent='3Dモデルを読み込んでいます…';
  try{
    renderer?.dispose();
    renderer=new THREE.WebGLRenderer({canvas:$('scene'),antialias:true,alpha:true});
    renderer.setPixelRatio(Math.min(devicePixelRatio,2));
    scene=new THREE.Scene(); camera=new THREE.PerspectiveCamera(38,1,.1,40);
    scene.add(new THREE.HemisphereLight(0xd8f3e0,0x333128,3));
    const light=new THREE.DirectionalLight(0xffe9c4,4); light.position.set(3,5,4);scene.add(light);
    const model=await new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>reject(new Error('model timeout')),15000);
      new GLTFLoader().load('valve.glb',v=>{clearTimeout(timer);resolve(v);},undefined,e=>{clearTimeout(timer);reject(e);});
    });
    if(token!==generation) return;
    // Only model meshes are used; Blender's exported camera and lamps are excluded.
    const imported=model.scene;
    imported.traverse(o=>{if(o.isLight)o.visible=false;});
    scene.add(imported); wheel=imported.getObjectByName('Handwheel');
    if(!wheel) throw new Error('Handwheel missing');
    position(); resize(); ready('3d');
  }catch(error){ if(token===generation) fallback(); }
}
function position(){
  if(!camera)return;
  camera.position.set(3.9*Math.sin(angle+.72),2.9,3.9*Math.cos(angle+.72));
  camera.lookAt(0,.8,0);draw();
}
$('turn').onclick=()=>{if(count<3){count++;update();}};
$('reset').onclick=()=>{count=0;angle=0;position();update();};
$('left').onclick=()=>{angle-=Math.PI/6;position();};
$('right').onclick=()=>{angle+=Math.PI/6;position();};
$('retry').onclick=()=>{load();};
$('scene').addEventListener('webglcontextlost',e=>{e.preventDefault();generation++;fallback();});
window.addEventListener('resize',resize);
load();
