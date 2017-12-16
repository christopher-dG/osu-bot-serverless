from . import consts


def map_str(beatmap):
    if not beatmap:
        return None
    return "%s - %s [%s]" % (beatmap.artist, beatmap.title, beatmap.version)


def combine_mods(mods):
    mods_a = []
    for k, v in consts.mods2int.items():
        if v & mods == v:
            mods_a.append(k)

    ordered_mods = list(filter(lambda m: m in mods_a, consts.mod_order))
    "NC" in ordered_mods and ordered_mods.remove("DT")
    "PF" in ordered_mods and ordered_mods.remove("SD")

    return "+%s" % "".join(ordered_mods) if ordered_mods else "NoMod"


def accuracy(s, mode):
    """Calculate accuracy for a score s as a float from 0-100."""
    if mode == consts.std:
        return 100 * (s.count300 + s.count100/3 + s.count50/6) / \
            (s.count300 + s.count100 + s.count50 + s.countmiss)
    if mode == consts.taiko:
        return 100 * (s.count300 + s.count100/2) / \
            (s.count300 + s.count100 + s.countmiss)
    if mode == consts.ctb:
        return 100 * (s.count300 + s.count100 + s.count50) / \
            (s.count300 + s.count100 + s.count50 + s.countkatu + s.countmiss)
    if mode == consts.mania:
        x = s.countgeki + s.count300 + 2*s.countkatu/3 + s.count100/3 + s.count50/6  # noqa
        y = s.countgeki + s.count300 + s.countkatu + s.count100 + s.count50 + s.countmiss  # noqa
        return 100 * x / y
