# experiment-only: 角セルの多シード頑健性。exp_corner.scan を流用し、
# C.BASE_SEED を一時上書き→finally完全復元。golden非干渉。
import sim_career as C
import exp_corner as X
from exp_human import PCasual2
from exp_human_fix import PSpread

ORIG = C.BASE_SEED
STACK = X.STACK
corner_cfg = STACK[-1][1]
base_cfg   = STACK[0][1]
seeds = [20260704, 111, 20250101, 42, 777]
n = 500
try:
    for cls, nm in [(PSpread, "分散(やり込み)"), (PCasual2, "のんびり改")]:
        print(f"[{nm}] n={n}/seed")
        for sd in seeds:
            C.BASE_SEED = sd
            bw, bf = X.scan(cls, n, **base_cfg)
            cw, cf = X.scan(cls, n, **corner_cfg)
            flag = ">=90 NECESSARY-WIN" if cw >= 90 else "<90 ok"
            print(f"  seed {sd:>9}: base 到達{bf:5.1f}/優勝{bw:5.2f}  |  角 到達{cf:5.1f}/優勝{cw:5.2f}  {flag}")
finally:
    C.BASE_SEED = ORIG
    print("restored BASE_SEED =", C.BASE_SEED)
