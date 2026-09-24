// Original bitmap lettering and scenery, drawn at native integer pixels.
const glyphs={
 A:['01110','10001','10001','11111','10001','10001','10001'],B:['11110','10001','10001','11110','10001','10001','11110'],C:['01111','10000','10000','10000','10000','10000','01111'],D:['11110','10001','10001','10001','10001','10001','11110'],E:['11111','10000','10000','11110','10000','10000','11111'],F:['11111','10000','10000','11110','10000','10000','10000'],G:['01111','10000','10000','10111','10001','10001','01111'],H:['10001','10001','10001','11111','10001','10001','10001'],I:['11111','00100','00100','00100','00100','00100','11111'],J:['00111','00010','00010','00010','10010','10010','01100'],K:['10001','10010','10100','11000','10100','10010','10001'],L:['10000','10000','10000','10000','10000','10000','11111'],M:['10001','11011','10101','10101','10001','10001','10001'],N:['10001','11001','10101','10011','10001','10001','10001'],O:['01110','10001','10001','10001','10001','10001','01110'],P:['11110','10001','10001','11110','10000','10000','10000'],Q:['01110','10001','10001','10001','10101','10010','01101'],R:['11110','10001','10001','11110','10100','10010','10001'],S:['01111','10000','10000','01110','00001','00001','11110'],T:['11111','00100','00100','00100','00100','00100','00100'],U:['10001','10001','10001','10001','10001','10001','01110'],V:['10001','10001','10001','10001','10001','01010','00100'],W:['10001','10001','10001','10101','10101','11011','10001'],X:['10001','10001','01010','00100','01010','10001','10001'],Y:['10001','10001','01010','00100','00100','00100','00100'],Z:['11111','00001','00010','00100','01000','10000','11111'],
 '0':['01110','10001','10011','10101','11001','10001','01110'],'1':['00100','01100','00100','00100','00100','00100','01110'],'2':['01110','10001','00001','00010','00100','01000','11111'],'3':['11110','00001','00001','01110','00001','00001','11110'],'4':['00010','00110','01010','10010','11111','00010','00010'],'5':['11111','10000','10000','11110','00001','00001','11110'],'6':['01110','10000','10000','11110','10001','10001','01110'],'7':['11111','00001','00010','00100','01000','01000','01000'],'8':['01110','10001','10001','01110','10001','10001','01110'],'9':['01110','10001','10001','01111','00001','00001','01110'],
 '-':['00000','00000','00000','11111','00000','00000','00000'],'!':['00100','00100','00100','00100','00100','00000','00100'],'?':['01110','10001','00001','00110','00100','00000','00100'],' ':[]};
export function pixelText(ctx,value,x,y,color='#fff'){
 ctx.fillStyle=color;x=Math.round(x);y=Math.round(y);
 const columns=[0,0,1,2,3,4,4];
 for(const char of String(value).toUpperCase()){const rows=glyphs[char]||glyphs['?'];for(let r=0;r<rows.length;r++)for(let c=0;c<7;c++)if(rows[r][columns[c]]==='1')ctx.fillRect(x+c,y+r,1,1);x+=8;}
}
const cloudMask=Array.from({length:24},(_,y)=>Array.from({length:32},(_,x)=>[[7,14,7],[14,9,8],[23,13,7],[16,16,10]].some(([a,b,r])=>(x-a)**2+(y-b)**2<=r*r)));
export function pixelCloud(ctx,x,y,count=1,bush=false){
 x=Math.round(x);y=Math.round(y);if(x>256||x+32+(count-1)*20<0)return;
 for(let n=0;n<count;n++)for(let r=0;r<24;r++)for(let c=0;c<32;c++)if(cloudMask[r][c]){
  const edge=!cloudMask[r-1]?.[c]||!cloudMask[r+1]?.[c]||!cloudMask[r]?.[c-1]||!cloudMask[r]?.[c+1];
  ctx.fillStyle=edge?'#182830':bush?(r>18?'#00a800':'#b8f818'):(r>18?'#9ce8fc':'#fcfcfc');
  ctx.fillRect(x+c+n*20,y+(bush?Math.floor(r*.6):r),1,1);
 }
}
export function pixelHill(ctx,x,y,height){
 x=Math.round(x);y=Math.round(y);if(x>256||x+height*2<0)return;
 for(let row=0;row<height;row++){const half=Math.min(height-1,Math.floor(Math.sqrt(row/height)*height));ctx.fillStyle='#182830';ctx.fillRect(x+height-half,y-height+row,half*2+1,1);ctx.fillStyle='#00a800';if(half>1)ctx.fillRect(x+height-half+1,y-height+row,half*2-1,1);}
 ctx.fillStyle='#005800';for(const [a,b]of[[.8,.5],[1.2,.75],[.6,.82]]){ctx.fillRect(x+Math.floor(height*a),y-height+Math.floor(height*b),2,3);}
}
export function pixelTile(ctx,type,x,y,underground=false,frame=0){
 x=Math.round(x);y=Math.round(y);const dark='#181818',light=underground?'#9ce8fc':'#fcbcb0',base=underground?'#0088a8':'#c84c0c';
 ctx.fillStyle=dark;ctx.fillRect(x,y,16,16);ctx.fillStyle=base;ctx.fillRect(x+1,y+1,14,14);
 if(type==='ground'){
  ctx.fillStyle=light;ctx.fillRect(x+1,y+1,9,1);ctx.fillRect(x+1,y+2,1,9);ctx.fillRect(x+12,y+1,3,1);ctx.fillRect(x+1,y+13,4,1);ctx.fillRect(x+8,y+11,7,1);
  ctx.fillStyle=dark;for(const [a,b,w,h]of[[10,0,1,7],[9,7,1,3],[5,10,4,1],[4,11,1,5],[0,11,4,1],[10,9,6,1]])ctx.fillRect(x+a,y+b,w,h);
 }else if(type==='brick'){
  for(let row=0;row<4;row++){const yy=y+row*4;ctx.fillStyle=dark;ctx.fillRect(x,yy+3,16,1);for(let a=(row%2)*4;a<16;a+=8){ctx.fillRect(x+a,yy,1,4);ctx.fillStyle=light;ctx.fillRect(x+a+1,yy,Math.min(6,15-a),1);ctx.fillStyle=dark;}}
 }else if(type==='question'){
  ctx.fillStyle=['#f8b850','#e89028','#c87018'][Math.floor(frame/12)%3];ctx.fillRect(x+1,y+1,14,14);ctx.fillStyle=light;ctx.fillRect(x+1,y+1,14,1);ctx.fillRect(x+1,y+1,1,14);ctx.fillStyle=dark;for(const a of [2,13])for(const b of[2,13])ctx.fillRect(x+a,y+b,1,1);pixelText(ctx,'?',x+4,y+4,'#703000');
 }else if(type==='stone'){
  ctx.fillStyle=light;for(let i=1;i<7;i++)ctx.fillRect(x+i,y+i,15-i*2,1);ctx.fillStyle=base;ctx.fillRect(x+6,y+6,4,4);ctx.fillStyle='#703000';for(let i=1;i<7;i++)ctx.fillRect(x+i,y+15-i,15-i*2,1);
 }
}
