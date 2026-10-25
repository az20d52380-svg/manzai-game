import sys, collections
sys.path.insert(0, __import__('os').path.dirname(__file__))
import sim_career as C
C.NETA_ON = True; C.NETA_V2 = True; C.EVENTS_APP = True
N = int(sys.argv[1]) if len(sys.argv) > 1 else 300
for name, cls in [("Balanced", C.CareerBalanced), ("Smart", C.CareerSmart)]:
    dist = collections.Counter()
    for seed in range(N):
        a0, p0 = C.REVIVAL_STATS["attempts"], C.REVIVAL_STATS["passes"]
        C.run_career(cls(), seed)
        losses = (C.REVIVAL_STATS["attempts"] - a0) - (C.REVIVAL_STATS["passes"] - p0)
        dist[losses] += 1
    mean = sum(k * v for k, v in dist.items()) / N
    print(f"{name} n={N} 敗者復活で負ける回数/キャリア 平均{mean:.2f} 分布{dict(sorted(dist.items()))}")
