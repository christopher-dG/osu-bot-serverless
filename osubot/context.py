from . import consts
from .beatmap_search import search, search_events
from .utils import combine_mods, map_str, matched_bracket_contents, safe_call


class Context:
    """A container for all relevant data."""

    def __init__(self, player, beatmap, mode, mods, acc, guest_mapper, logs):
        self.player = player  # osuapi.models.User, None if missing
        self.beatmap = beatmap  # osuapi.models.Beatmap, None if missing
        self.mode = mode  # Int (0-4), None if missing
        self.mods = mods  # Int, 0 if missing
        self.acc = acc  # Float (0-100), None if missing
        self.guest_mapper = guest_mapper  # osuapi.models.User, None if missing
        self.logs = logs  # List of strings

    def __repr__(self):
        mode = "Unknown" if self.mode is None else consts.mode2str[self.mode]
        mods = "NoMod" if self.mods == consts.nomod else combine_mods(self.mods)  # noqa
        acc = "None" if self.acc is None else "%.2f%%" % self.acc
        gm = "None" if self.guest_mapper is None else self.guest_mapper.username  # noqa
        s = "Context:\n"
        s += "> Player:        %s\n" % self.player
        s += "> Beatmap:       %s\n" % map_str(self.beatmap)
        s += "> Mode:          %s\n" % mode
        s += "> Mods:          %s\n" % mods
        s += "> Accuracy:      %s\n" % acc
        s += "> Guest mapper:  %s" % gm
        return s

    def to_dict(self):
        """
        Convert the context to a dict.
        This isn't meant for passing information, only displaying in JSON.
        """
        return {
            "acc": "None" if self.acc is None else "%.2f%%" % self.acc,
            "beatmap": map_str(self.beatmap) if self.beatmap else "None",
            "mode": "Unknown"
            if self.mode is None
            else consts.mode2str[self.mode],  # noqa
            "mods": combine_mods(self.mods),
            "player": self.player.username if self.player else "None",
            "guest mapper": self.guest_mapper.username
            if self.guest_mapper
            else "None",  # noqa
        }


def from_score_post(title):
    """Construct a Context from the title of score post."""
    logs = []
    player = getplayer(title, logs=logs)
    beatmap = getmap(title, player=player, logs=logs)
    mode = getmode(title, player=player, beatmap=beatmap)
    mods = getmods(title)
    acc = getacc(title)
    guest_mapper = getguestmapper(title)

    # Once we know the game mode, we can ensure that the player and map
    # are of the right mode (this really helps with autoconverts).
    if mode is not None and mode != consts.std:
        match = consts.player_re.search(title)
        if match:
            name = strip_annots(match.group(1))
            updated_players = safe_call(
                consts.osu_api.get_user,
                player.user_id if player else name,
                mode=consts.int2osuapimode[mode],
            )
            if updated_players:
                player = updated_players[0]

        if beatmap is not None and beatmap.mode.value == consts.std:
            updated_beatmaps = safe_call(
                consts.osu_api.get_beatmaps,
                beatmap_id=beatmap.beatmap_id,
                mode=consts.int2osuapimode[mode],
                include_converted=True,
            )
            if updated_beatmaps:
                beatmap = updated_beatmaps[0]

    return Context(player, beatmap, mode, mods, acc, guest_mapper, logs)


def getplayer(title, logs=[]):
    """Get the player from the post title."""
    match = consts.player_re.search(title)
    if not match:
        logs.append("Player: No regex match")
        return None
    name = strip_annots(match.group(1))

    players = safe_call(consts.osu_api.get_user, name)
    if players:
        return players[0]
    logs.append("Player: '%s' not found" % name)
    return None


def strip_annots(s):
    """Remove annotations in brackets and parentheses from a username."""
    name = consts.paren_re.sub("", s.upper()).strip()

    ignores = consts.title_ignores + list(consts.mode_annots.keys())
    for cap in consts.bracket_re.findall(name):
        if cap in ignores:
            name = name.replace("[%s]" % cap, "")

    return name.strip()


def getmap(title, player=None, logs=[]):
    """Search for the beatmap."""
    match = consts.map_re.search(title)
    if not match:
        logs.append("Beatmap: No regex match")
        return None
    map_s = match.group(1).strip()

    match = consts.map_double_brackets_re.search(map_s)
    if not match:
        match = consts.map_pieces_re.search(map_s)

    if match:
        diff = match.group(3)
        contents = matched_bracket_contents("[%s]" % diff)
        if contents:
            map_s = "%s - %s [%s]" % (match.group(1), match.group(2), contents)

    return search(player, map_s, logs=logs)


def getmode(title, player=None, beatmap=None):
    """
    Search for the game mode.
    If title doesn't contain any relevant information, try player's events.
    Otherwise, use beatmap's mode.
    If beatmap is None, then return None for unknown.
    """
    match = consts.player_re.search(title.upper())
    if not match:
        return None
    playername = match.group(1)

    for match in consts.paren_re.findall(playername):
        if match in consts.mode_annots:
            return consts.mode_annots[match]
    for match in consts.bracket_re.findall(playername):
        if match in consts.mode_annots:
            return consts.mode_annots[match]

    if beatmap:
        if player:
            m = search_events(player, "", b_id=beatmap.beatmap_id, mode=True)
            if m is not None:
                return m
        return beatmap.mode.value

    return None


def getmods(title):
    """Search for mods in title."""
    match = consts.tail_re.search(title)
    if not match:
        return consts.nomod
    tail = match.group(1)

    if "+" in tail and tail.index("+") < (len(tail) - 1):
        tokens = tail[(tail.index("+") + 1) :].split()
        if tokens:
            mods = getmods_token(tokens[0])
            if mods is not None:
                return mods

    for token in tail.split():
        mods = getmods_token(token)
        if mods is not None and mods != consts.nomod:
            return mods

    return consts.nomod


def getmods_token(token):
    """
    Get mods from a single token.
    Returns None if the token doesn't look like mods.
    """
    token = consts.scorev2_re.sub("V2", token.upper().replace(",", ""))
    if len(token) % 2:
        return None

    mods = set()
    for i in range(0, len(token), 2):
        mod = consts.mods2int.get(token[i : i + 2])
        if mod is None:
            return None
        mods.add(mod)

    return sum(mods)


def getacc(title):
    """Search for accuracy in title."""
    match = consts.tail_re.search(title)
    if not match:
        return None
    match = consts.acc_re.search(match.group(1))
    return float(match.group(1).replace(",", ".")) if match else None


def getguestmapper(title):
    """Search for a guest mapper in title."""
    match = consts.map_pieces_re.search(title)
    if not match:
        return None
    diff = match.group(3)

    guest = diff.split()[0]
    if guest.endswith("'s"):
        guest = guest[:-2]
    elif guest.endswith("s'"):  # jakads', etc.
        guest = guest[:-1]
    else:
        return None

    players = safe_call(consts.osu_api.get_user, guest)
    if players:
        player = players[0]
    else:
        return None

    # Only return the guest mapper if they have at least one map of their own.
    maps = safe_call(consts.osu_api.get_beatmaps, username=player.username)
    return player if maps else None
