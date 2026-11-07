"""11/02 の帯（平均 2.53%）と同じ測り方で、EVENTS_APP だけ False/True を比べる（測るだけ・本体不変）。
使い方: python3 exp_calib_app_1108_v0.py <n>"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_calib_all_1101_v0 as E

VAR = "yrs=15;M=0;D=1;k=0;band=1;ex=0;mo=0;onsen=0"
CHUNK = 25

def job(a):
    app, rest = a
    C.EVENTS_APP = app
    key, out = E.job(rest)
    return (app, key[2]), out

def main():
    n = int(sys.argv[1])
    jobs = [(app, (VAR, 0, bi, True, False, list(range(i, min(i + CHUNK, n)))))
            for app in (False, True) for bi in range(4) for i in range(0, n, CHUNK)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    for app in (False, True):
        rows = [E.summ(res[(app, bi)]) for bi in range(4)]
        wins = "/".join(f"{r['win']:.1f}" for r in rows)
        fins = "/".join(f"{r['fin']:.1f}" for r in rows)
        dss = "/".join(f"{r['ds']:.1f}" for r in rows)
        avg = sum(r["win"] for r in rows) / 4
        print(f"APP={int(app)} n={n} 優勝 {wins} 平均{avg:.2f} 決勝 {fins} 解散 {dss}")

if __name__ == "__main__":
    main()
