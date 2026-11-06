import {afterEach,describe,it,expect,vi} from 'vitest';
import {createFootballCareer,playFootballCareerRound} from './footballManagerCareer.js';
import {readFootballCloudCareer,writeFootballCloudCareer} from './footballCareerCloud.js';
afterEach(()=>vi.unstubAllGlobals());
describe('Mongo career client contract',()=>{
 it('reads only the server journal, not a browser fallback',async()=>{
  const journal=playFootballCareerRound(createFootballCareer('fc-matthias')).journal;
  const spy=vi.fn().mockResolvedValue(Response.json({status:'available',revision:8,journal}));
  vi.stubGlobal('fetch',spy);
  const remote=await readFootballCloudCareer();
  expect(remote.status).toBe('available');
  expect(remote.revision).toBe(8);
  expect(remote.season.currentRound).toBe(1);
  expect(spy.mock.calls[0][0]).toBe('/api/football/career');
  expect(spy.mock.calls[0][1].credentials).toBe('same-origin');
 });
 it('does not acknowledge a save until Mongo responds with next revision',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue(Response.json({status:'saved',revision:3})));
  const journal=createFootballCareer('fc-matthias');
  expect(await writeFootballCloudCareer(journal,2)).toEqual({status:'cloud',revision:3});
  expect(JSON.parse(fetch.mock.calls[0][1].body)).toMatchObject({revision:2,journal});
  fetch.mockResolvedValue(Response.json({status:'saved',revision:3}));
  await expect(writeFootballCloudCareer(journal,3)).rejects.toThrow();
 });
 it('does not overwrite on conflict, failure or unknown server state',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue(Response.json({error:'revision_conflict'},{status:409})));
  await expect(writeFootballCloudCareer(createFootballCareer('fc-matthias'),2)).rejects.toMatchObject({code:'conflict'});
  fetch.mockResolvedValue(new Response('',{status:503}));
  await expect(readFootballCloudCareer()).rejects.toThrow();
  fetch.mockResolvedValue(Response.json({status:'future',revision:4}));
  expect((await readFootballCloudCareer()).status).toBe('future');
  fetch.mockResolvedValue(Response.json({status:'empty',revision:0}));
  expect((await readFootballCloudCareer()).status).toBe('empty');
 });
});
