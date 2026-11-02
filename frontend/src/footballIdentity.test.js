import {afterEach,describe,it,expect,vi} from 'vitest';
import {currentFootballSession,renewFootballSession,closeFootballSession} from './footballIdentity.js';
const subject='11111111-1111-4111-8111-111111111111';
const session=()=>({subject,expires_at:Math.floor(Date.now()/1000)+120});
afterEach(()=>vi.unstubAllGlobals());
describe('server-confirmed ShadowOps session',()=>{
 it('requires an actual successful current server session',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue(Response.json(session())));
  expect((await currentFootballSession()).subject).toBe(subject);
  fetch.mockResolvedValue(new Response('',{status:401}));await expect(currentFootballSession()).rejects.toThrow();
  fetch.mockResolvedValue(Response.json({...session(),expires_at:1}));await expect(currentFootballSession()).rejects.toThrow();
 });
 it('renews only through the pinned central cookie and same-origin verified exchange',async()=>{
  const requests=[];
  vi.stubGlobal('fetch',vi.fn(async(url,options)=>{requests.push({url,options});return Response.json(url.startsWith('https:')?{token:'ephemeral-token'}:session());}));
  await renewFootballSession();
  expect(requests.map(x=>x.url)).toEqual(['https://id-staging.shadowops.dpdns.org/api/identity/token','/api/football/session']);
  expect(requests[0].options.credentials).toBe('include');expect(requests[0].options.body).toBe('{}');
  expect(requests[1].options.body).toBe(JSON.stringify({token:'ephemeral-token'}));
 });
 it('does not claim global logout or clear the local session when Identity revocation fails',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response('',{status:503})));
  await expect(closeFootballSession()).rejects.toThrow();expect(fetch).toHaveBeenCalledTimes(1);
 });
});
