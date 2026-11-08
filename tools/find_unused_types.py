#!/usr/bin/env python3
# アプリ（ManzaiGame/Sources）で宣言のほかに名前が出てこない型（テストも含めて参照0）を出す。消すかはキュー118（オーナー判断）。使い方: python3 tools/find_unused_types.py（リポジトリの直下で）
import re,glob,collections
files=glob.glob('ManzaiGame/Sources/**/*.swift',recursive=True)
tests=glob.glob('ManzaiGame/Tests/**/*.swift',recursive=True)
src={f:open(f).read() for f in files+tests}
alltext='\n'.join(src.values())
decl=re.compile(r'^\s*(?:@\w+\s+)*(?:(?:private|fileprivate|public|internal|final)\s+)*(?:struct|enum|class|extension\s+\w+\s*:\s*\w+\s*\{\s*$)?\s*(?:struct|enum|class)\s+(\w+)',re.M)
out=[]
for f in files:
    for m in decl.finditer(src[f]):
        n=m.group(1)
        cnt=len(re.findall(r'\b'+n+r'\b',alltext))
        if cnt<=1: out.append((f.split('Sources/')[1],n))
for o in out: print(*o)
