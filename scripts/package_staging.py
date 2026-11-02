import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'.artifacts/football-staging';out.mkdir(parents=True,exist_ok=True)
for name,source in [('web',ROOT/'frontend/dist'),('runtime',ROOT/'games/chess-football-godot/build/web')]:
 shutil.copytree(source,out/name,dirs_exist_ok=True)
release=json.loads((out/'web/release.json').read_text())
entries={}
for p in sorted(out.rglob('*')):
 if p.is_file():entries[p.relative_to(out).as_posix()]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(out/'delivery.json').write_text(json.dumps({'application':'football-of-matthias','environment':'staging','source_sha':release['source_sha'],'files':entries},sort_keys=True)+'\n')
