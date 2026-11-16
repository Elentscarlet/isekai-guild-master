r"""比较两张回归截图，输出差异像素数与范围。

用法（两种都可以）：
  cd GuildMaster-Godot-src\tools\regression\out
  python ..\compare.py before after

  python GuildMaster-Godot-src\tools\regression\compare.py before after

注意：Windows 下如果从含中文的绝对路径调用 Python，脚本路径里的中文可能被
控制台编码破坏，此时会自动改用当前工作目录找截图。
"""
import sys
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
except ImportError:
    sys.exit("need Pillow and numpy")

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
if not OUT.is_dir():
    OUT = Path.cwd()
SCREENS = ["home", "room", "table", "dialog", "lobby"]


def main():
    before, after = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ("before", "after")
    if not OUT.is_dir():
        print("output folder not found")
        return 1
    worst = 0
    for screen in SCREENS:
        path_a = OUT / ("%s_%s.png" % (screen, before))
        path_b = OUT / ("%s_%s.png" % (screen, after))
        if not (path_a.is_file() and path_b.is_file()):
            print("%-7s missing" % screen)
            worst = max(worst, 1)
            continue
        a = np.asarray(Image.open(path_a).convert("RGB"), dtype=int)
        b = np.asarray(Image.open(path_b).convert("RGB"), dtype=int)
        if a.shape != b.shape:
            print("%-7s size differs: %s vs %s" % (screen, a.shape, b.shape))
            worst = max(worst, 1)
            continue
        diff = np.abs(a - b).max(axis=2)
        count = int((diff > 8).sum())
        worst = max(worst, count)
        box = None
        if count:
            ys, xs = np.where(diff > 8)
            box = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
        print("%-7s diff=%-6d max=%-3d bbox=%s" % (screen, count, int(diff.max()), box))
    print("RESULT:", "identical" if worst == 0 else "differs")
    return 0 if worst == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
