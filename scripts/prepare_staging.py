"""Build a fixed immutable runtime manifest without contacting cloud services."""
import hashlib,json,os,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'games/chess-football-godot/build/web'
PREFIX='football-of-matthias/staging'
ORIGIN='https://assets.chess-studio.shadowops.dpdns.org'
files=sorted(p for p in GAME.rglob('*') if p.is_file())
assert {'index.html','index.js','index.wasm','index.pck'} <= {p.name for p in files}
assert not any(p.is_symlink() for p in files)
digest=hashlib.sha256()
entries={}
for path in files:
 name=path.relative_to(GAME).as_posix();raw=path.read_bytes()
 digest.update(name.encode()+b'\0'+raw)
 entries[name]={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
release=digest.hexdigest()[:16]
sha=os.environ.get('FOOTBALL_SOURCE_SHA',os.environ.get('GITHUB_SHA','0'*40))
assert re.fullmatch('[a-f0-9]{40}',sha)
pointer={'version':1,'release':release,'sourceSha':sha,'index':f'{ORIGIN}/{PREFIX}/releases/{release}/index.html'}
public=ROOT/'frontend/public';public.mkdir(exist_ok=True)
(public/'runtime.json').write_text(json.dumps(pointer)+'\n')
(public/'release.json').write_text(json.dumps({'application':'football-of-matthias','environment':'staging','source_sha':sha,'authentication':{'provider':'shadowops-id','audience':'football','required':True},'runtime':pointer,'files':entries})+'\n')
print('FOOTBALL_STAGING_BUILD_READY source_sha='+sha+' runtime='+release)

(public/'_headers').write_text("""/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://id-staging.shadowops.dpdns.org; frame-src https://assets.chess-studio.shadowops.dpdns.org; frame-ancestors 'none'; object-src 'none'; base-uri 'none'
/
  Cache-Control: no-store
/index.html
  Cache-Control: no-store
/release.json
  Cache-Control: no-store
/runtime.json
  Cache-Control: no-store
/assets/*
  Cache-Control: public, max-age=31536000, immutable
""")

(public/'_worker.js').write_text((ROOT/'edge/identity-gate.mjs').read_text())
