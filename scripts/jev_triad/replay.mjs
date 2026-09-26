// Re-execute recorded effective actions, without inference/search, as an audit.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {init} from '../jev_distillation/game.mjs';
import {edge} from './planner.mjs';
const lane=process.env.LANE??'planner';
const result=JSON.parse(fs.readFileSync(`out/triad/${lane}.json`));
for(const row of result.episodes){
 const trace=JSON.parse(fs.readFileSync(`out/triad/${lane}-${row.seed}-trace.json`)),g=init(32,row.seed,row.seed>0);let action='noop',i=0;
 while(g.frames<row.frames){if(trace[i]?.frame===g.frames)action=trace[i++].effective;g.buttons(edge(g,action));g.step();g.drainSounds();}
 assert.equal(g.phase,row.phase);assert.ok(Math.abs(g.p.x-row.x)<1e-9);assert.equal(i,trace.length);
}
fs.writeFileSync(`out/triad/${lane}-replay.json`,JSON.stringify({episodes:result.episodes.length,exact_final_state:true,description:'Action-trace replay parity, not another independent inference trial'},null,2));
