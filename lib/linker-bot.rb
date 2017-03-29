#!/usr/bin/env ruby

require 'httparty'
require 'redd'

DIR = File.expand_path(File.dirname(__FILE__))  # Absolute path to file folder.
KEY = File.open("#{DIR}/key").read.chomp  # osu! API key.
PASSWORD = File.open("#{DIR}/pass").read.chomp  # Reddit password.
SECRET = File.open("#{DIR}/secret").read.chomp  # Reddit app secret.
LOG_PATH = "#{DIR}/../logs"  # Path to log files.
URL = 'https://osu.ppy.sh'  # Base for API requests.

# Use a Reddit post title to search for a beatmap.
# Arguments:
#   title: Reddit post title.
# Returns:
#   Dictionary with beatmap data, or nil in case of an error.
def search(title)
  begin
    tokens = title.split('|')
    player = tokens[0].strip
    map = tokens[1]
    song = map[0...map.index('[')].strip  # Artist - Title
    diff = map[map.index('[')..map.index(']')]  # [Diff Name]

    url = "#{URL}/api/get_user?k=#{KEY}&u=#{player}&type=string"
    response = HTTParty.get(url)

    full_name = "#{song} #{diff}".gsub('&', '&amp;').downcase  # Artist - Title [Diff Name]

    map_id = -1
    # Use the player's recent events. Score posts are likely to be at least top
    # 50 on the map, and this method takes less time than looking through recents.
    events = response.parsed_response[0]['events']
    for event in events
      if event['display_html'].downcase.include?(full_name)
        map_id = event['beatmap_id']
      end
    end

    if map_id == -1  # Use player's recent plays as a backup.
      url = "#{URL}/api/get_user_recent?k=#{KEY}&u=#{player}&type=string&limit=50"
      response = HTTParty.get(url)
      recents = response.parsed_response
      for play in recents
        id = play['beatmap_id']
        url = "#{URL}/api/get_beatmaps?k=#{KEY}&b=#{id}"
        response = HTTParty.get(url)
        btmp = response.parsed_response[0]
        if "#{btmp['artist']} - #{btmp['title']} [#{btmp['version']}]".downcase == full_name
          map_id = id
          break
        end
      end
    end

    url = "#{URL}/api/get_beatmaps?k=#{KEY}&b=#{map_id}"
    response = HTTParty.get(url)
    beatmap = response.parsed_response[0]
    beatmap.empty? && raise

    return beatmap
  rescue
    msg = "Map retrieval failed for \'#{title}\'.\n"
    File.open("#{LOG_PATH}/#{now}", 'a') {|f| f.write(msg)}
    return nil
  end
end

# Get diff SR, AR, OD, CS, and HP for nomod and with a given set of mods.
# Arguments:
#   map: Dictionary with beatmap data.
#   mods: Mod string, i.e. "+HDDT" or "+HRFL".
# Returns:
#   Dictionary with [nomod, mod-adjusted] arrays as values, or just [nomod]
#   arrays if the mods (or lack thereof) do not affect the values.
def get_diff_info(map, mods)
  sr = map['difficultyrating'].to_f.round(2)
  ar = map['diff_approach']
  cs = map['diff_size']
  od = map['diff_overall']
  hp = map['diff_drain']

  return_nomod = Proc.new do
    return {'SR' => [sr], 'AR' => [ar], 'CS' => [cs], 'OD' => [od], 'HP' => [hp]}
  end

  all_mods = [
    'EZ', 'NF', 'HT', 'HR', 'SD', 'PF', 'DT',
    'NC', 'HD', 'FL', 'RL', 'AP', 'SO'
  ]
  ignore = ['HD', 'NF', 'SD', 'PF', 'SO', 'AP', 'RL']
  if !mods.empty?
    mod_list = mods[1..-1].scan(/../)
  end
  if mods.empty? || mod_list.all? {|m| ignore.include?(m)} ||
     !mod_list.all? {|m| all_mods.include?(m)}
    return_nomod.call
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10  # Todo: verify this.

  begin
    url = "#{URL}/osu/#{map['beatmap_id']}"
    `curl #{url} > map.osu`
    oppai = `#{File.join(DIR, 'oppai/oppai')} map.osu #{mods}`
    File.delete('map.osu')
  rescue
    msg = "\`Downloading or analyzing the file at #{url}\` failed.\n"
    File.open("#{LOG_PATH}/#{now}", 'a') {|f| f.write(msg)}
    return_nomod.call
  end

  parse_oppai = Proc.new do |target, text|
    /#{target}[0-9][0-9]?(\.[0-9][0-9]?)?/.match(text).to_s[2..-1].to_f
  end

  m_sr = /[0-9]*\.[0-9]*\sstars/.match(oppai).to_s.split(' ')[0].to_f.round(2)
  m_ar = parse_oppai.call('ar', oppai)
  m_ar = m_ar.to_i == m_ar ? m_ar.to_i : m_ar
  m_cs = parse_oppai.call('cs', oppai)
  m_cs = m_cs.to_i == m_cs ? m_cs.to_i : m_cs
  m_od = parse_oppai.call('od', oppai)
  m_od = m_od.to_i == m_od ? m_od.to_i : m_od

  # Oppai does not handle HP drain.
  if mods.include?("EZ")
    m_hp = (hp.to_f * ez_hp_scalar).round(2)
    m_hp = m_hp.to_i == m_hp ? m_hp.to_i : m_hp
  elsif mods.include?("HR")
    m_hp = (hp.to_f * hr_hp_scalar).round(2)
    m_hp = m_hp > hp_max ? hp_max : m_hp.to_i == m_hp ? m_hp.to_i : m_hp
  else
    m_hp = hp
  end

  {
    'SR' => [sr, m_sr], 'AR' => [ar, m_ar], 'CS' => [cs, m_cs],
    'OD' => [od, m_od], 'HP' => [hp, m_hp],
  }
end

# Generate the text to be commented.
# Arguments:
#   title: Reddit post title.
#   map: Beatmap data.
# Returns:
#   Comment text.
def gen_comment(title, map)
  text = ""
  link_url = "#{URL}/b/#{map['beatmap_id']})"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  creator_url = "#{URL}/u/#{map['creator']}"
  gh_url = 'https://github.com/christopher-dG/osu-map-linker-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

  m_start = title.index('+', title.index(']'))  # First '+' after the diff name.
  mods = m_start != nil ? /\+([A-Z]|,)*/.match(title[m_start..-1]).to_s.gsub(',', '') : ''

  diff = get_diff_info(map, mods)
  len = convert_s(map['total_length'].to_i)

  text += "Beatmap: [#{link_label}](#{link_url} by [#{map['creator']}](#{creator_url})\n\n"
  text += "Length: #{len} - BPM: #{map['bpm']} - Plays: #{map['playcount']}\n\n"
  text += "CS: #{diff['CS'][0]} - AR: #{diff['AR'][0]} - OD: #{diff['OD'][0]} "
  text += "- HP: #{diff['HP'][0]} - SR: #{diff['SR'][0]}\n\n"

  if diff['SR'].length == 2
    text += "#{mods}:\n\n"
    text += "CS: #{diff['CS'][1]} - AR: #{diff['AR'][1]} - OD: #{diff['OD'][1]} "
    text += "- HP: #{diff['HP'][1]} - SR: #{diff['SR'][1]}\n\n"
  end

  text += "***\n\n"
  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  text
end

# Convert seconds to mm:ss.
# Arguments:
#   s: Number of seconds (Integer).
# Returns:
#   "m:ss" timestamp from s.
def convert_s(s)
  h = s / 60
  m = s % 60
  if m < 10
    m = "0#{m}"
  end
  "#{h}:#{m}"
end

# Format the current date and time.
# Returns:
#   "MM-DD-YYYY hh:mm"
def now
  `date +"%m-%d-%Y_%H:%M"`.chomp
end

# Compares a post against some criteria for being classified as a score post.
# Arguments:
#   post: Reddit post.
# Returns:
#  Whether or not the post is considerd a score post.
def is_score_post(post)
  /\|.*-.*\[.*\]/ =~ post.title && !post.is_self
end

# Get the /r/osugame subreddit.
# Returns:
#   /r/osugame subreddit.
def get_sub
  Redd.it(
    user_agent: 'Redd:osu!-map-linker-bot:v0.0.0',
    client_id: 'OxznkS-LjaEH3A',
    secret: SECRET,
    username: 'map-linker-bot',
    password: PASSWORD,
  ).subreddit('osugame')
end