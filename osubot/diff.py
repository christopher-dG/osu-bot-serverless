import catch_the_pp
import json
import os
import subprocess

from . import consts, scrape
from .utils import changes_diff, is_ignored, combine_mods


def diff_vals(ctx, modded=True):
    """Get the difficulty values of a map."""
    if not ctx.beatmap:
        return None

    if not modded:
        return diff_nomod(ctx)

    if modded and is_ignored(ctx.mods):
        return None

    if ctx.mode in [consts.std, consts.taiko]:
        return diff_modded_oppai(ctx)
    if ctx.mode == consts.ctb:
        return diff_modded_ctb(ctx)
    return None


def diff_nomod(ctx):
    """Get the unmodded difficulty values of a map."""
    return {
        "cs": ctx.beatmap.diff_size,
        "ar": ctx.beatmap.diff_approach,
        "od": ctx.beatmap.diff_overall,
        "hp": ctx.beatmap.diff_drain,
        "sr": ctx.beatmap.difficultyrating,
        "bpm": ctx.beatmap.bpm,
        "length": ctx.beatmap.total_length,
    }


def diff_modded_oppai(ctx):
    """Get the modded difficulty values of a standard/taiko map with oppai."""
    if ctx.mode not in [consts.std, consts.taiko] or ctx.mods == consts.nomod:
        return None
    if is_ignored(ctx.mods):
        return None

    path = scrape.download_beatmap(ctx)
    if path is None:
        return None

    cmd = [consts.oppai_bin, path, "-ojson"]
    if ctx.mods != consts.nomod:
        cmd.append(combine_mods(ctx.mods))
    if ctx.mode == consts.taiko:
        cmd.append("-taiko")
    try:
        out = subprocess.check_output(cmd)
    except Exception as e:
        print("oppai command '%s' failed: %s" % (" ".join(cmd), e))
        os.remove(path)
        return None

    try:
        d = json.loads(out)
    except Exception as e:
        print("Converting oppai output to JSON failed: %s" % e)
        return None

    if ctx.mods & consts.mods2int["DT"]:  # This catches NC too.
        scalar = 1.5
    elif ctx.mods & consts.mods2int["HT"]:
        scalar = 0.75
    else:
        scalar = 1

    length = round(ctx.beatmap.total_length / scalar)
    bpm = ctx.beatmap.bpm * scalar
    if changes_diff(ctx.mods):
        stars = d["stars"]
    else:
        stars = ctx.beatmap.difficultyrating

    return {
        "cs": d["cs"],
        "ar": d["ar"],
        "od": d["od"],
        "hp": d["hp"],
        "sr": stars,
        "bpm": bpm,
        "length": length,
    }


def diff_modded_ctb(ctx):
    """Get the modded difficulty values of a ctb map."""
    if not ctx.beatmap:
        return None

    path = scrape.download_beatmap(ctx)
    if path is None:
        return None

    # I don't know how stable catch_the_pp is so check for errors everywhere.
    try:
        beatmap = catch_the_pp.osu_parser.beatmap.Beatmap(path)
    except Exception as e:
        print("CTB beatmap parsing error: %s" % e)
        return None

    try:
        diff = catch_the_pp.osu.ctb.difficulty.Difficulty(beatmap, ctx.mods)
    except Exception as e:
        print("CTB difficulty calculation error: %s" % e)
        return None

    # Calculating difficulty modifies the beatmap that was used.
    d = beatmap.difficulty

    if ctx.mods & consts.mods2int["DT"]:  # This catches NC too.
        scalar = 1.5
    elif ctx.mods & consts.mods2int["HT"]:
        scalar = 0.75
    else:
        scalar = 1

    length = round(ctx.beatmap.total_length / scalar)
    bpm = ctx.beatmap.bpm * scalar
    if changes_diff(ctx.mods):
        stars = diff.star_rating
    else:
        stars = ctx.beatmap.difficultyrating

    return {
        "cs": d["CircleSize"],
        "ar": d["ApproachRate"],
        "od": d["OverallDifficulty"],
        "hp": d["HPDrainRate"],
        "sr": stars,
        "bpm": bpm,
        "length": length,
    }
