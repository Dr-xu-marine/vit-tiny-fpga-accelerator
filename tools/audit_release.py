"""Audit this publication snapshot. Never execute Vivado, XSim, inference or hardware."""
from pathlib import Path
import argparse,ast,collections,hashlib,json,re,zipfile
R=Path(__file__).resolve().parents[1]
DYNAMIC={'publication/audit_results.json','publication/release_manifest.json','publication/FILE_LIST.md'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files():
    return sorted(p for p in R.rglob('*') if p.is_file() and '.git' not in p.relative_to(R).parts and '.publication' not in p.relative_to(R).parts and '__pycache__' not in p.relative_to(R).parts)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--refresh-inventory',action='store_true');ap.add_argument('--source-root',type=Path);args=ap.parse_args()
    issues=[];notes=[];source=json.loads((R/'publication/source_manifest.json').read_text())
    def issue(kind,path):issues.append(dict(kind=kind,path=str(path)))
    for row in source['files']:
        p=R/row['path'];expected=row.get('published_sha256',row['sha256'])
        if not p.is_file() or sha(p)!=expected:issue('SOURCE_COPY_HASH_MISMATCH',row['path'])
        if args.source_root:
            src=args.source_root/row['source']
            if not src.is_file() or sha(src)!=row['sha256']:issue('READ_ONLY_ORIGINAL_CHANGED',row['source'])
    active=source['active_sources']
    assert len(active)==27
    source_rows={x['path']:x for x in source['files']}
    for n in active:
        if not source_rows[n]['exact_copy']:issue('ACTIVE_RTL_MODIFIED',n)
    # High confidence patterns; values are never included in findings.
    patterns=[('private_key',re.compile(rb'-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----')),
              ('github_token',re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{70,255})')),
              ('aws_access_key',re.compile(rb'AKIA[A-Z0-9]{16}')),
              ('credential_url',re.compile(rb'https?://[^\s/:]{1,64}:[^\s/@]{6,128}@'))]
    forbidden={'.dcp','.bit','.ltx','.pem','.key','.npz','.npy','.pth','.pt','.safetensors','.bin','.zip','.rar','.7z','.dmp','.wdb'}
    data=files();largest=[];syntax=0;secret_scanned=0
    for p in data:
        rel=p.relative_to(R).as_posix();raw=p.read_bytes();largest.append((len(raw),rel))
        if p.suffix.lower() in forbidden:issue('EXCLUDED_FILE_TYPE',rel)
        if p.stat().st_size>=50*1024*1024:issue('LARGE_GIT_FILE',rel)
        if p.is_symlink():issue('SYMLINK_REVIEW',rel)
        if p.name in ['.env','id_rsa','id_ed25519'] or p.name.lower().endswith(('.pfx','.p12')):issue('CREDENTIAL_FILENAME',rel)
        chunks=[raw]
        if p.suffix=='.docx':
            with zipfile.ZipFile(p) as z:
                if z.testzip() is not None:issue('DOCX_ARCHIVE_CORRUPT',rel)
                chunks.extend(z.read(n) for n in z.namelist() if n.endswith('.xml'))
        if p.suffix=='.py':
            try:ast.parse(raw.decode('utf-8-sig'),filename=rel);syntax+=1
            except SyntaxError:issue('PYTHON_SYNTAX',rel)
        for kind,pattern in patterns:
            if any(pattern.search(chunk) for chunk in chunks):issue('POSSIBLE_SECRET_'+kind,rel)
        secret_scanned+=1
        if p.suffix in ['.py','.tcl','.sv','.v','.vh'] and not rel.startswith('competition_2026_advanced/'):
            text=raw.decode('utf-8-sig',errors='replace')
            if re.search(r'(?i)\b[A-Z]:[/\\](?:fpga|Users|vit-tiny)',text):issue('EXECUTABLE_ABSOLUTE_HOST_PATH',rel)
        if p.suffix=='.pdf':notes.append('PDF binary scanned for high-confidence credentials; corresponding source Markdown scanned; no report re-render performed')
    # Internal relative Markdown links outside original historical report are checked.
    link_checks=0
    for p in data:
        rel=p.relative_to(R).as_posix()
        if p.suffix!='.md' or rel.startswith(('competition_2026_advanced/','historical/')):continue
        for target in re.findall(r'\]\(([^)]+)\)',p.read_text('utf-8')):
            target=target.split('#')[0]
            if not target or '://' in target:continue
            link_checks+=1
            if not (p.parent/target).exists():issue('BROKEN_RELEASE_DOC_LINK',rel+' -> '+target)
    inv=R/'publication/release_manifest.json'
    if args.refresh_inventory:
        payload=[dict(path=p.relative_to(R).as_posix(),bytes=p.stat().st_size,sha256=sha(p)) for p in data if p.relative_to(R).as_posix() not in DYNAMIC]
        inv.write_text(json.dumps(dict(schema=1,files=payload,excluded_self_or_dynamic=sorted(DYNAMIC)),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if inv.exists():
        frozen=json.loads(inv.read_text())['files'];frozen_paths={x['path'] for x in frozen}
        for row in frozen:
            p=R/row['path']
            if not p.is_file() or sha(p)!=row['sha256']:issue('RELEASE_MANIFEST_MISMATCH',row['path'])
        for p in data:
            rel=p.relative_to(R).as_posix()
            if rel not in frozen_paths and rel not in DYNAMIC:issue('UNMANIFESTED_FILE',rel)
    else:issue('MISSING_RELEASE_MANIFEST','publication/release_manifest.json')
    data=files();groups=collections.defaultdict(lambda:dict(files=0,bytes=0))
    for p in data:
        group=p.relative_to(R).parts[0];groups[group]['files']+=1;groups[group]['bytes']+=p.stat().st_size
    # File listing is generated only here, from the actual current files.
    lines=['# 发布文件清单 / File list','','Generated from the independent publication directory. SHA-256 is recorded in release_manifest.json.','','| Group | Files | Bytes |','|---|---:|---:|']
    lines.extend('| '+k+' | '+str(v['files'])+' | '+str(v['bytes'])+' |' for k,v in sorted(groups.items()))
    lines+=['','## Full paths','','```text']+[p.relative_to(R).as_posix() for p in data]+['```','']
    (R/'publication/FILE_LIST.md').write_text('\n'.join(lines),encoding='utf-8')
    result=dict(status='PASS_PUBLICATION_FILE_CHECKS_ONLY' if not issues else 'FAIL_PUBLICATION_FILE_CHECKS',
        active_synthesis_sources_exact=len(active),copied_sources_checked=len(source['files']),
        read_only_original_rechecked=bool(args.source_root),python_files_parsed=syntax,relative_doc_links_checked=link_checks,
        high_confidence_secret_files_scanned=secret_scanned,file_count=len(files()),total_bytes=sum(p.stat().st_size for p in files()),
        largest_files=[dict(path=n,bytes=s) for s,n in sorted(largest,reverse=True)[:8]],issues=issues,notes=sorted(set(notes)),
        limits=['Pattern scanning is not a guarantee that every possible credential is absent','No Vivado/RTL/network/board validation run','No complete independent model/data reproduction','GitHub account and target repository pending'],
        new_simulations=0,new_vivado_runs=0,new_hardware_operations=0)
    (R/'publication/audit_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2));return 0 if not issues else 1
if __name__=='__main__':raise SystemExit(main())
