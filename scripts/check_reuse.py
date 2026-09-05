#!/usr/bin/env python3
"""Audit every imported file against its exact upstream Git blob, allowing CRLF."""
import hashlib
import json
import pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]

def main():
    manifest=json.loads((ROOT/'verification'/'cpu-provenance.json').read_text(encoding='utf-8-sig'))
    for name,expected in manifest['git_blobs'].items():
        data=(ROOT/name).read_bytes().replace(b'\r\n',b'\n')
        actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if actual!=expected: raise RuntimeError('Imported file differs from recorded source: '+name)
    print(f"PASS: {len(manifest['git_blobs'])} imported files match source commit {manifest['source_commit']}")

if __name__=='__main__': main()
