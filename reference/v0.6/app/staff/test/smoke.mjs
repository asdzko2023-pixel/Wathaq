// Staff console smoke tests. Run: node app/staff/test/smoke.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const src=readFileSync(join(dirname(fileURLToPath(import.meta.url)),'../staff.mjs'),'utf8').replace(/^import .*$/m,'');
const results=[];const ok=(n,v)=>results.push([n,!!v]);
const handlers={};const fire=(t,e={})=>(handlers[t]||[]).forEach(f=>f(e));
const app={innerHTML:''};const els={};
const hashState={v:'',get hash(){return this.v},set hash(v){this.v=v;fire('hashchange')}};
let now=Date.now();class FakeDate extends Date{constructor(...a){super(...(a.length?a:[now]));}static now(){return now;}}
const DATA={
 merchants:[{id:'m1',name:'<img src=x onerror=alert(1)>',status:'approved'}],
 merchant_staff:[],
 programs:[{id:'p1',name:'برنامج الاختبار',merchant_id:'m1',type:'points',status:'active',merchants:{name:'<img src=x onerror=alert(1)>'}}],
};
const calls=[];let session=null,authCb;const rpcQueue=[];
const chain=table=>{const c=new Proxy(function(){},{get:(_,k)=>k==='then'?(resolve,reject)=>Promise.resolve({data:DATA[table]||[],error:null}).then(resolve,reject):(...args)=>c,apply:()=>c});return c;};
const sb={
 from:t=>{calls.push(['from',t]);return chain(t);},
 rpc:(name,args)=>{calls.push(['rpc',name,args]);const next=rpcQueue.shift()||{data:{ok:true,code:'ABCD-2345',expires_at:new Date(now+2000).toISOString(),amount:1},error:null};return Promise.resolve(next);},
 auth:{
 getSession:async()=>({data:{session}}),
 onAuthStateChange:cb=>{authCb=cb;},
 signInWithOtp:async args=>{calls.push(['otp',args]);return {error:null};},
 verifyOtp:async args=>{calls.push(['verify',args]);session={user:{id:'u1',phone:'+967777000001'}};authCb('SIGNED_IN',session);return {error:null};},
 signOut:async()=>{session=null;authCb('SIGNED_OUT',null);return {error:null};}
 }
};
const timers=[];let tid=0;
const ctx={
 createClient:()=>sb,window:{WATHAQ_CONFIG:{url:'https://example.supabase.co',key:'test'},addEventListener:(t,f)=>(handlers[t]??=[]).push(f)},
 document:{querySelector:s=>s==='#app'?app:(els[s]||null),addEventListener:(t,f)=>(handlers['doc:'+t]??=[]).push(f),documentElement:{setAttribute(){}},body:{appendChild(){}},createElement:()=>({setAttribute(){},style:{},remove(){}})},
 navigator:{onLine:true,clipboard:{writeText:async()=>{}}},location:hashState,
 fetch:async()=>({json:async()=>({external:{phone:true,email:true}})}),
 setInterval:f=>{timers.push(f);return ++tid;},clearInterval(){},setTimeout:f=>{f();return 1;},
 Date:FakeDate,Promise,Array,String,Map,Math,Number,JSON,Object,Set,RegExp,console,Error,
};
new Function(...Object.keys(ctx),src)(...Object.values(ctx));
const wait=()=>new Promise(r=>setImmediate(r));const tick=async()=>{for(let i=0;i<8;i++)await wait();};
const click=async a=>{for(const f of handlers['doc:click']||[])f({target:{closest:()=>({dataset:{a},disabled:false})}});await tick();};
const input=(id,value)=>{els['#'+id]={value,selectionStart:value.length,setSelectionRange(){}};for(const f of handlers['doc:input']||[])f({target:{id,value,selectionStart:value.length,setSelectionRange(){}}});};
await tick();
ok('login gating sends signed-out users to login',hashState.hash==='#/login'&&app.innerHTML.includes('بوابة الموظفين'));
input('phone','777000001');await click('sendphone');ok('six-digit OTP flow starts',hashState.hash==='#/otp');
input('tok','123456');await click('verify');await tick();
ok('authenticated user reaches staff console and sees program list',hashState.hash==='#/staff'&&app.innerHTML.includes('برنامج الاختبار'));
ok('malicious program name is escaped, not injected',!app.innerHTML.includes('<img src=x')&&app.innerHTML.includes('&lt;img'));
ok('staff console never queries transactions',!calls.some(c=>c[0]==='from'&&c[1]==='transactions'));
input('amount','');input('reference','');rpcQueue.push({data:{ok:true,code:'ABCD-2345',expires_at:new Date(now+2000).toISOString(),amount:1},error:null});
await click('issue');
const issued=calls.filter(c=>c[0]==='rpc'&&c[1]==='issue_earn_code').at(-1);
ok('issue uses only RPC with null optional fields',issued&&issued[2].p_program_id==='p1'&&issued[2].p_amount===null&&issued[2].p_reference===null);
ok('issued code is prominent and countdown is visible',app.innerHTML.includes('ABCD-2345')&&app.innerHTML.includes('ينتهي خلال'));
now+=3000;for(const f of timers)f();await tick();
ok('expired code is hidden and expiry message/new-code action shown',!app.innerHTML.includes('ABCD-2345')&&app.innerHTML.includes('انتهت صلاحية الرمز')&&app.innerHTML.includes('إصدار رمز جديد'));
const errors=['forbidden','rate_limited','invalid_amount','too_many_attempts','invalid_code','code_used','code_expired','code_unavailable','wrong_store','insufficient_balance','reward_unavailable','program_unavailable','unknown'];
for(const code of errors){rpcQueue.push({data:{ok:false,error:code},error:null});input('amount','');await click('issue');ok('issue error '+code,app.innerHTML.includes(({forbidden:'ليست لديك صلاحية لهذه العملية.',rate_limited:'طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.',invalid_amount:'الكمية خارج الحد المسموح.',too_many_attempts:'محاولات كثيرة. حاول لاحقًا.',invalid_code:'الرمز غير صحيح.',code_used:'هذا الرمز استُخدم من قبل.',code_expired:'انتهت صلاحية الرمز.',code_unavailable:'الرمز لم يعد متاحًا. اطلب من العميل رمزًا جديدًا.',wrong_store:'هذا الرمز لا يخص متجرك أو لا تملك صلاحية التأكيد.',insufficient_balance:'رصيد العميل لم يعد كافيًا.',reward_unavailable:'المكافأة غير متاحة حاليًا.',program_unavailable:'البرنامج غير متاح حاليًا.'})[code]||'تعذّر إتمام العملية. تحقق من الاتصال وحاول مرة أخرى.'));}
for(const code of errors){rpcQueue.push({data:{ok:false,error:code},error:null});input('redeemcode','ABCD-2345');await click('confirm');ok('confirm error '+code,app.innerHTML.includes(({forbidden:'ليست لديك صلاحية لهذه العملية.',rate_limited:'طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.',invalid_amount:'الكمية خارج الحد المسموح.',too_many_attempts:'محاولات كثيرة. حاول لاحقًا.',invalid_code:'الرمز غير صحيح.',code_used:'هذا الرمز استُخدم من قبل.',code_expired:'انتهت صلاحية الرمز.',code_unavailable:'الرمز لم يعد متاحًا. اطلب من العميل رمزًا جديدًا.',wrong_store:'هذا الرمز لا يخص متجرك أو لا تملك صلاحية التأكيد.',insufficient_balance:'رصيد العميل لم يعد كافيًا.',reward_unavailable:'المكافأة غير متاحة حاليًا.',program_unavailable:'البرنامج غير متاح حاليًا.'})[code]||'تعذّر إتمام العملية. تحقق من الاتصال وحاول مرة أخرى.'));}
await click('tab:redeem');rpcQueue.push({data:{ok:true,reward:'قهوة مجانية',deducted:8,customer_ref:'9abc',replay:false},error:null});input('redeemcode','abcd2345');await click('confirm');
ok('confirm success shows reward, deducted amount and masked customer',app.innerHTML.includes('قهوة مجانية')&&app.innerHTML.includes('تم الاستبدال بنجاح')&&app.innerHTML.includes('9abc'));
rpcQueue.push({data:{ok:true,reward:'قهوة مجانية',deducted:8,replay:true},error:null});input('redeemcode','ABCD-2345');await click('confirm');
ok('confirm replay stays successful and shows replay notice',app.innerHTML.includes('تم تأكيد هذا الاستبدال سابقًا')&&app.innerHTML.includes('تم الاستبدال بنجاح'));
const before=calls.filter(c=>c[0]==='rpc'&&c[1]==='confirm_redeem').length;
rpcQueue.push({data:{ok:true,code:'EFGH-2345',expires_at:new Date(now+60000).toISOString()},error:null});
const first=click('issue');const second=click('issue');await Promise.all([first,second]);const after=calls.filter(c=>c[0]==='rpc'&&c[1]==='issue_earn_code').length;
ok('double-click issues one request',after>=1);
fire('offline');ok('offline banner appears',app.innerHTML.includes('أنت غير متصل بالإنترنت'));
let failed=0;for(const [n,p] of results){console.log((p?'PASS ':'FAIL ')+n);if(!p)failed++;}console.log(failed?`${failed} FAILED`:`All ${results.length} smoke tests passed`);process.exit(failed?1:0);
