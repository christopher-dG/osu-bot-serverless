# coding: utf-8

# Path to oppai binary.
OPPAI = File.expand_path("#{File.dirname(__FILE__)}/../oppai/oppai")

# Vertical line delimiter that won't break Markdown tables.
BAR = '&#124;'

# Star icon.
STAR = '&#9733;'

# Download icon.
DOWNLOAD = '&#8659;'

# Base for API requests.
OSU_URL = 'https://osu.ppy.sh'

# Repo URL.
GH_URL = 'https://github.com/christopher-dg/osu-bot'

# Reddit profile URL.
DEV_URL = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

# Log file.
LOG = File.expand_path(
  "#{File.dirname(__FILE__)}/../logs/#{`date +"%m-%d-%Y_%H:%M:%S"`.chomp}.log"
)

# Modes to run in.
# 'DEBUG' -> Enable extra logging (todo), 'DRY' -> dry run, 'TEST' -> testing.
RUN_MODES = %w(DEBUG DRY TEST)
DEBUG = ARGV.include?("DEBUG")
DRY = ARGV.include?("DRY")
TEST = ARGV.include?("TEST")

# Secret files.
SECRETS = File.expand_path("#{File.dirname(__FILE__)}/../secrets")
OSU_KEY = File.open("#{SECRETS}/osu_key").read.chomp
REDDIT_PASSWORD = File.open("#{SECRETS}/reddit_pass").read.chomp
REDDIT_SECRET = File.open("#{SECRETS}/reddit_secret").read.chomp
REDDIT_CLIENT_ID = File.open("#{SECRETS}/reddit_client").read.chomp
OSUSEARCH_KEY = File.open("#{SECRETS}/search_key").read.chomp
GITHUB_PASSWORD = File.open("#{SECRETS}/github_pass").read.chomp

# Users to ignore.
TROLLS = %w(gomina chemistryosu)

# All mods.
MODS = %w(EZ HD HT DT NC HR FL NF SD PF RL SO AP AT)

# Mods that don't affect difficulty values but do affect pp.
SAME_DIFF_MODS = %w(HD)

# Mods that don't affect difficulty or pp values.
SAME_PP_MODS = %w(SD PF)

# Mods that aren't ranked, don't give pp, don't change ratings, etc.
IGNORE_MODS = %w(RL AP AT)

# Integer mods according to: https://github.com/ppy/osu-api/wiki#mods
# Note: NC is never without DT, so NC only == 576.
BITWISE_MODS = {
  0 => '', 1 => 'NF', 2 => 'EZ', 8 => 'HD', 16 => 'HR', 32 => 'SD', 64 => 'DT',
  128 => 'RL', 256 => 'HT', 512 => 'NC', 1024 => 'FL', 2048 => 'AT',
  4096 => 'SO', 8192 => 'AT', 16384 => 'PF',
}
