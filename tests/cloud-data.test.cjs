const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const source=fs.readFileSync('src/cloud.js','utf8');
const valid=source.slice(source.indexOf('  function valid('),source.indexOf('  function apply('));
const merge=source.slice(source.indexOf('  function mergeLegacy('),source.indexOf('  async function sync('));
const ctx=vm.createContext({uid:()=>crypto.randomUUID(),structuredClone,types:['Carousel','Post','Reel']});
vm.runInContext(valid+merge,ctx);
function data(){return {version:1,clients:[{id:'client',name:'Restaurant',counts:[4,4,4]}],items:[{id:'post',clientId:'client',type:'Reel',month:'2026-10',title:'My actual October plan',shots:[{id:'shot',description:'October details',done:true}]}],ideas:[{id:'inspo',clientId:'client',title:'Saved reference',image:'data:image/jpeg;base64,YQ=='}],shoots:{'client|2026-10':{notes:'Original shoot notes'}},selectedClient:'client',selectedMonth:'2026-10'}}
const cloud=data(),local=data();cloud.items[0].title='Existing cloud plan';const cloudBefore=JSON.stringify(cloud),localBefore=JSON.stringify(local),result=ctx.mergeLegacy(cloud,local);
assert.equal(JSON.stringify(cloud),cloudBefore);assert.equal(JSON.stringify(local),localBefore);
assert.equal(result.items.length,2);assert.equal(result.items[0].title,'Existing cloud plan');assert.equal(result.items[1].title,'My actual October plan');assert.equal(result.selectedMonth,'2026-10');assert.notEqual(result.items[1].id,'post');assert.notEqual(result.items[1].clientId,'client');assert.equal(result.items[1].clientId,result.selectedClient);assert.equal(result.shoots[result.selectedClient+'|2026-10'].notes,'Original shoot notes');assert.equal(result.items[1].shots[0].done,true);assert.equal(result.ideas[1].image,local.ideas[0].image);assert.ok(ctx.valid(result));assert.ok(!ctx.valid({version:1,clients:[],items:[],ideas:[],shoots:{}}));assert.ok(!ctx.valid({...data(),items:[{id:'invalid',type:'Other',shots:[]}]}));
const app=fs.readFileSync('src/app.js','utf8');let writes=[],queues=0,activeKey='account:a:workspace:b';
const save=app.slice(app.indexOf('function save()'),app.indexOf('function toast('));
const cacheCtx=vm.createContext({state:data(),clientId:'client',month:'2026-10',window:{PlannerCloud:{storageKey:()=>activeKey,queue:()=>queues++}},localStorage:{setItem:(...args)=>writes.push(args)},$:()=>({textContent:''}),toast:()=>{}});vm.runInContext(save,cacheCtx);cacheCtx.save();assert.equal(writes.length,0,'Cloud edits must never overwrite the legacy browser plan');assert.equal(queues,1);activeKey=null;cacheCtx.save();assert.equal(writes[0][0],'content-playground-v1');
console.log('PASS: October import preserves records, remaps collisions, keeps original data and images; cloud saves do not overwrite legacy plans.');
// Exercise revision checks and account-switch safety against a mocked database.
const syncSource=source.slice(source.indexOf('  async function sync('),source.indexOf('  async function reloadCloud('));
async function syncChecks(){let saves=0,caches=0,notices=[];
const c=vm.createContext({user:{id:'a'},workspace:{id:'personal-a'},loading:false,saving:false,conflict:false,dirty:true,timer:null,editCounter:1,revision:3,state:data(),structuredClone,clearTimeout:()=>{},setTimeout:()=>1,syncLabel:()=>{},cache:()=>caches++,showNotice:(...n)=>notices.push(n),backup:()=>{},reloadCloud:()=>{},notice:{hidden:true},sdk:{rpc:async(name,args)=>{saves++;assert.equal(args.p_expected_revision,3);assert.equal(args.p_workspace,'personal-a');return {data:4,error:null}}}});
vm.runInContext(syncSource,c);await c.sync();assert.equal(c.revision,4);assert.equal(c.dirty,false);assert.equal(saves,1);
c.dirty=true;c.sdk.rpc=async()=>({error:{code:'40001',message:'PLANNER_CONFLICT'}});await c.sync();assert.equal(c.conflict,true);assert.equal(c.dirty,true);assert.equal(notices.length,1);await c.sync();assert.equal(saves,1,'Conflicts must not automatically overwrite another device');
c.conflict=false;c.dirty=true;c.sdk.rpc=async()=>({error:{message:'Network unavailable'}});await c.sync();assert.equal(c.dirty,true);assert.ok(caches>0);
let resolve;c.sdk.rpc=()=>new Promise(r=>resolve=r);const pending=c.sync();c.user={id:'different-user'};const cacheCount=caches;resolve({data:99});await pending;assert.equal(caches,cacheCount,'An old account request must not cache data into the new account');assert.equal(c.revision,4);
console.log('PASS: revision conflicts, failed saves, and in-flight account switches retain data without overwriting another account.');
}
syncChecks().catch(e=>{console.error(e);process.exitCode=1});
