# xmendez@edge-security.com
#
# (quick and dirty) Bookmark manager 
#
# Trying to mimic ruby-wmii script behauvior
# Bookmark manager is mainly copied and then adapted to run from command line from the old ruby-wmii script standart plugins
# https://web.archive.org/web/20081227225803/http://eigenclass.org/hiki.rb?wmii+ruby
# 
# Add the following to your configuration:
# bindsym $mod+b exec ruby ~/.i3/scripts/bookmarks.rb --open
# bindsym $mod+Shift+b exec ruby ~/.i3/scripts/bookmarks.rb --add

BOOKMARK_FILE = File.join(ENV["HOME"], ".i3", "bookmarks.txt")

require 'openssl'

#{{{ Bookmark manager 
# Defines the following bindings:
#  bookmark        take current X11 primary selection (with wmiipsel), ask
#                  for description (suggests the page title). You can
#                  append tags to the description:
#                    Page about foo :foo :ruby :bar
#                  tags the bookmark as :foo, :ruby and :bar, and sets the
#                  description to "Page about foo"
#  bookmark-open   ask for a bookmark and open it on a new browser window
#                  The possible completions are shown as you type text from
#                  the description. You can refine the selection
#                  successively, entering a bit (e.g. a word) at a time
#                  (append a space if you don't want the first suggestion
#                  to be taken). You can also use any number of the following
#                  conditions (possible completions will only be shown
#                  after you press enter in that case):
#
#                  :tag       only bookmarks tagged with :tag
#                  ~t regexp  bookmarks whose description matches regexp
#                  ~u regexp  bookmarks whose URL matches regexp
#                  ~d 2001    bookmarks defined/last used in 2001
#                  ~d jan     bookmarks defined/last used in January
#                  ~d >4d     bookmarks defined/last used over 4 days ago
#                  ~d >4m                                      4 months ago
#                  ~d <4d     bookmarks defined/last used less than 4 days ago
#                  ~d <4m                                           4 months ago
#                  ~d q1      bookmarks defined/last used in the first quarter
#                             (q1..q4)
#                 
#                 Example:
#                   eigen :ruby ~d <3m
#                 returns all bookmarks with "eigen" in the description or the
#                 URL, tagged as :ruby, used/defined in the last 3 months
#                 
#                 There are also some commands that apply to the current list
#                 (they will only be recognized as commands if you don't enter
#                 anything else on the same line):
#
#                 !o          open all the bookmarks
#
#                 Usage example:
#                 
#                  :blog<enter>    to select all the bookmarks tagged as :blog
#                  !o<enter>       to open them all
require 'time'
require 'thread'
class BookmarkManager
  Bookmark = Struct.new(:description, :url, :tags, :date)

  def initialize(filename)
    @filename = filename
    @bookmarks = []
    @bookmark_index = Hash.new{|h,k| h[k] = {}}
    @loaded = false
    @mutex = Mutex.new
  end

  def load
    @bookmarks = []
    @bookmark_index.clear
    IO.foreach(@filename) do |line|
      desc, url, tags, date = line.chomp.split(/\t/).map{|x| x.strip}
      tags = (tags || "").split(/\s/)
      begin
        date = Time.rfc822(date)
      rescue
        date = Time.new
      end
      bm = Bookmark.new(desc, url, tags, date)
      @bookmarks << bm
      @bookmark_index[desc][url] = bm
    end rescue nil
    @loaded = true
  end

  # Returns the bookmark if unique.
  def [](desc)
    self.load unless @loaded
    return nil unless @bookmark_index.has_key?(desc)
    bms = @bookmark_index[desc]
    if bms.size == 1
      bms.values[0]
    else
      nil
    end
  end

  # Returns true if it was a new bookmark, false if the (desc,url) was not
  # unique or it was older than the existent.
  def add_bookmark(desc, url, tags, date)
    self.load unless @loaded
    ret = true
    if @bookmark_index.has_key?(desc) && @bookmark_index[desc].has_key?(url)
      return false if @bookmark_index[desc][url].date >= date
      @bookmarks.delete @bookmark_index[desc][url]
      ret = false
    end
    bm = Bookmark.new(desc, url, tags, date)
    @bookmarks << bm
    @bookmark_index[desc][url] = bm
    ret
  end

  def bookmarks
    self.load unless @loaded
    @bookmarks
  end

  # This method is thread-safe, not process-safe.
  # It will merge the bookmark list with that on disk, avoiding data losses.
  def save!
    @mutex.synchronize do
      merge!
      tmpfile = @filename + "_tmp_#{Process.pid}"
      File.open(tmpfile, "a") do |f|
        @bookmarks.sort_by{|bm| bm.date}.reverse_each do |bm|
          f.puts [bm.description, bm.url, bm.tags.join(" "), bm.date.rfc822].join("\t")
        end
        f.sync
      end
      File.rename(tmpfile, @filename) # atomic if on the same FS and fleh
    end
  end

  def merge!
    IO.foreach(@filename) do |line|
      desc, url, tags, date = line.chomp.split(/\t/).map{|x| x.strip}
      tags = (tags || "").split(/\s/)
      begin
        date = Time.rfc822(date)
      rescue
        date = Time.new
      end
      add_bookmark(desc, url, tags, date)
    end rescue nil
  end
  private :merge!

  def satisfy_date_condition?(bookmark, condition)
    date = bookmark.date
    case condition
    when /^q1$/i then date.month >= 12 || date.month <= 4
    when /^q2$/i then date.month >= 3  && date.month <= 7
    when /^q3$/i then date.month >= 6  && date.month <= 10
    when /^q4$/i then date.month >= 9 || date.month <= 1
    when /^\d+$/ then date.year == condition.to_i
    when /^\w+$/ then date.month - 1 == Time::RFC2822_MONTH_NAME.index(condition.capitalize)
    when /^([><])(\d+)([md])/
      sign, units, type = $1, $2.to_i, $3
      multiplier = 3600 * 24
      multiplier *= 30.4375 if type == 'm'
      case sign
      when '<' then  Time.new - date <= units * multiplier
      when '>' then  Time.new - date >= units * multiplier
      end
    end
  end
  private :satisfy_date_condition?
  
  def refine_selection(expression, choices=self.bookmarks)
    expression = expression.strip
    pieces = expression.split(/\s+/)
    criteria = []
    option_needed = false
    pieces.each do |x|
      case option_needed
      when true then    criteria.last << " #{x}"; option_needed = false
      when false then   criteria << x; option_needed = true if /^~\w/ =~ x 
      end
    end
    choices.select do |bm|
      criteria.all? do |criterion|
        case criterion
        when /~t\s+(\S+)/ then Regexp.new($1) =~ bm.description
        when /~u\s+(\S+)/ then Regexp.new($1) =~ bm.url
        when /~d\s+(\S+)/ then satisfy_date_condition?(bm, $1)
        when /:\w+$/      then bm.tags.include?(criterion)
        else bm.description.index(criterion) or bm.url.index(criterion)
        end
      end
    end
  end
end

######

require "shellwords"
def dmenu_wrapper(items)
    selection = Array.new

    command = "dmenu -b"
    pipe = IO.popen(command, "w+")

    items.each do |item|
      pipe.puts item
    end

    pipe.close_write
    value = pipe.read
    pipe.close

    if $?.exitstatus > 0
      return ""
    end

    return value

end

def bookmark_it
    url = `xsel`.strip
    if %r{^http://} =~ url or %r{^https://} =~ url
	#puts url
	
	begin
	    #contents = open(url){|f| f.read}
	    contents = open(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}){|f| f.read}
	    title = CGI.unescapeHTML((contents[%r{title>(.*)</title>}im, 1] || "").strip).gsub(/&[^;]+;/, "")
	    title.gsub!(/\s+/, " ")
	rescue ArgumentError
	    title = "Parsing title Error | " + url
	rescue OpenURI::HTTPError
	    title = "Open HTTP Error | " + url
	end
	
	#choice = dmenu_wrapper([title, title.downcase, title.capitalize])
	choice = dmenu_wrapper([title.downcase])
          tags = choice[/(:\S+\s*)+$/] || ""
          description = choice[0..-1-tags.size].strip
          if description =~ /\S/
            bm_manager = BookmarkManager.new(BOOKMARK_FILE)
            bm_manager.add_bookmark(description, url, tags.split(/\s+/), Time.new)
            bm_manager.save!
          end
    end
end

def bookmark_open
    bm_manager = BookmarkManager.new(BOOKMARK_FILE)
    open_bookmark = lambda do |bm|
      case browser = ENV["BROWSER"]
      when nil then system "/etc/alternatives/x-www-browser '#{bm.url}' &"
      else system "#{browser} '#{bm.url}' &"
      end
    end


    refine_choices = lambda do |bookmarks|
      options = bookmarks.sort_by{|x| x.description}.map do |x| 
        "#{x.description} : #{x.url.gsub(%r[http://], '')}"
      end
      
      choice = dmenu_wrapper(options)
        condition = choice.strip
        unless condition.empty?
          if condition == "!o"
            if bookmarks.size <= 
               (limit = 10)
              bookmarks.each do |bm|
                bm.date = Time.new
                open_bookmark.call(bm)
              end
              bm_manager.save!
            else
              puts "Tried to open #{bookmarks.size} bookmarks at a time."
              puts "Refusing since it's over multiple-open-limit (#{limit})."
            end
          elsif bm = bm_manager[condition] || (bm = bm_manager[condition.gsub(/ : \S+$/, "")])
            bm.date = Time.new
            bm_manager.save!
            open_bookmark.call(bm)
          else
            choices = bm_manager.refine_selection(condition, bookmarks)
            refine_choices.call(choices) unless choices.empty?
          end
        end
    end
    refine_choices.call(bm_manager.bookmarks)
end

require 'optparse'


require 'open-uri'
require 'cgi'

hash_options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: your_app [options]"
  opts.on('--open', 'Open bookmark') do 
    bookmark_open
    exit
  end
  opts.on('--add', 'Add selection to bookmark') do 
    bookmark_it
    exit
  end
  opts.on('--version', 'Display the version') do 
    puts "VERSION"
    exit
  end
  opts.on('-h', '--help', 'Display this help') do 
    puts opts
    exit
  end
end.parse!
