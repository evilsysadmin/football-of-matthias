"""The migrated match/art retain the exact approved source bytes."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/'migration/source.json').read_text())
count=0
addition=json.loads((ROOT/'migration/additions.json').read_text()) if (ROOT/'migration/additions.json').exists() else {'files':[]}
for item in source['files']+addition['files']:
 if not item['path'].startswith(('games/','scripts/art/')):continue
 raw=(ROOT/item['path']).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==item['sha'],item['path']
 count+=1
print('FOOTBALL_ORIGINAL_MATCH_AND_ART_OK files='+str(count))
