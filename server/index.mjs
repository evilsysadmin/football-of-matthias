// Private OCI listener. Never publish its port; terminate HTTPS and authenticate
// at Football Pages before forwarding over the trusted staging tunnel.
import {createServer} from 'node:http';
import {MongoClient} from 'mongodb';
import {handleCareerRequest} from './career-api.mjs';

const uri=process.env.FOOTBALL_MONGODB_URI;
const credential=process.env.FOOTBALL_CAREER_SERVICE_CREDENTIAL;
const port=Number(process.env.FOOTBALL_CAREER_PORT||9275);
if(!uri||!/^fsc1_[A-Za-z0-9_-]{43}$/.test(credential||'')
  ||!Number.isInteger(port)||port<1||port>65535){
 throw Error('Missing or invalid Football staging configuration');
}
const client=new MongoClient(uri,{maxPoolSize:4,serverSelectionTimeoutMS:5000,retryWrites:true,
 readConcern:{level:'majority'},writeConcern:{w:'majority'}});
await client.connect();
const db=client.db('shadowops_football_staging');
await db.command({ping:1});
const collection=db.collection('careers');
const server=createServer(async(req,res)=>{
 if(req.method==='GET'&&req.url==='/readyz'){
  try{await db.command({ping:1});res.writeHead(200,{'Cache-Control':'no-store'});res.end('ready');}
  catch{res.writeHead(503);res.end('not ready');}
  return;
 }
 let bytes=0;const chunks=[];
 try{
  for await (const chunk of req){
   bytes+=chunk.length;
   if(bytes>20000){res.writeHead(413);res.end();return;}
   chunks.push(chunk);
  }
  const response=await handleCareerRequest(new Request('http://football-internal'+(req.url||'/'),{
   method:req.method,headers:req.headers,
   ...(chunks.length?{body:Buffer.concat(chunks),duplex:'half'}:{})
  }),{collection,serviceCredential:credential});
  res.writeHead(response.status,Object.fromEntries(response.headers));
  res.end(Buffer.from(await response.arrayBuffer()));
 }catch{res.writeHead(503,{'Cache-Control':'no-store'});res.end();}
});
server.listen(port,'0.0.0.0');
for(const signal of ['SIGTERM','SIGINT']){
 process.once(signal,()=>server.close(()=>{void client.close().then(()=>process.exit(0));}));
}
