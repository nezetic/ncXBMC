#!/usr/bin/env ruby

=begin
    ncXBMC
    
    ncXBMC is a remote XBMC client, which aims to provide a full control of 
    the music player over a local network.
    
    It can be used to browse library, manage playlist, and control playback.
    
    The interface has been greatly inspired by ncmpc (http://hem.bredband.net/kaw/ncmpc/), 
    a curses client for the Music Player Daemon (MPD) (I'm a fan).
    
    
    Copyright (C) 2009 Cedric TESSIER
    
    Contact: nezetic.info

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end


require 'optparse'

begin
    require 'rubygems'
rescue LoadError
end

require 'ncurses'
require 'ruby-xbmc'

NCXMBC_DEFAULTPORT="8080"
NCXBMC_VERSION=0.2

module Interface
    KEY_TAB = 9
    KEY_ENTER = 10
    KEY_SPACE = 32
    KEY_RIGHT = 261
    KEY_LEFT = 260
    KEY_UP = 259
    KEY_DOWN = 258
    KEY_b = 98
    KEY_c = 99
    KEY_d = 100
    KEY_f = 102
    KEY_h = 104
    KEY_m = 109
    KEY_p = 112
    KEY_RETURN = 127

    class NcurseInterface
        REFRESH_DELAY=1 # seconds
        KEY_ESC=27

        def initialize(xbmc)
            @stdscr = Ncurses.initscr

            Ncurses.curs_set(0)
            Ncurses.noecho
            Ncurses.keypad(@stdscr,TRUE)
            Ncurses.cbreak
            @stdscr.nodelay(true)

            ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)

            if Ncurses.has_colors?
                Ncurses.start_color
                Ncurses.use_default_colors
                init_bgcolor() 
            end

            @maxy=Ncurses.getmaxy(@stdscr)
            @maxx=Ncurses.getmaxx(@stdscr)

            @xbmc = xbmc

            @wins = []
            @wins << PlaylistWin.new(@stdscr, @xbmc)
            @wins << LibraryWin.new(@stdscr, @xbmc)

            @currentwin = 0
        end

        def refresh
            @stdscr.refresh
            @wins[@currentwin].refresh
        end

        def drawCurrentWin
            @wins[@currentwin].draw
        end

        def UpdateCurrentWin
            @wins[@currentwin].update
        end

        def run
            self.drawCurrentWin
            self.refresh

            key=0
            timespent=0
            while key!=KEY_ESC
                key=@stdscr.getch

                if(key == KEY_TAB) # Tabs Cycling
                    @currentwin += 1
                    @currentwin = 0 if(@currentwin > (@wins.length - 1))

                    self.drawCurrentWin
                    self.refresh
                    next 
                end

                @wins[@currentwin].handleKey(key) if key != -1

                sleep(0.01)
                timespent += 0.01

                if(timespent >= REFRESH_DELAY)
                    timespent = 0
                    self.UpdateCurrentWin
                end
            end
        end

        protected

        def init_bgcolor(pair=1, bgcolor=Ncurses::COLOR_BLACK)
            Ncurses.init_pair(1, Ncurses::COLOR_WHITE, bgcolor)
            Ncurses.init_pair(2, Ncurses::COLOR_YELLOW, bgcolor)
            Ncurses.init_pair(3, Ncurses::COLOR_RED, bgcolor)
            Ncurses.init_pair(4, Ncurses::COLOR_GREEN, bgcolor)
            Ncurses.init_pair(5, Ncurses::COLOR_BLUE, bgcolor)
            Ncurses.init_pair(6, Ncurses::COLOR_CYAN, bgcolor)
            Ncurses.init_pair(7, Ncurses::COLOR_MAGENTA, bgcolor)
            Ncurses.init_pair(8, Ncurses::COLOR_BLACK, bgcolor)
            Ncurses.bkgd(Ncurses.COLOR_PAIR(pair))
        end

        private

        def self.finalize(id)
            Ncurses.echo()
            Ncurses.nocbreak()
            Ncurses.nl()
            Ncurses.curs_set(1)

            Ncurses.endwin
        end
    end

    class TabWins

        def initialize(pscreen, xbmc)
            @stdscr = pscreen
            @xbmc = xbmc

            @title = ""

            @maxy=Ncurses.getmaxy(@stdscr)
            @maxx=Ncurses.getmaxx(@stdscr)

            @header = Ncurses::WINDOW.new(2,@maxx,0,0)
            @main = Ncurses::WINDOW.new(@maxy-2-2,@maxx,2,0)
            @footer = Ncurses::WINDOW.new(2,@maxx,@maxy-2,0)

            @selected = 0
            @scroll   = 0

            @helpMSGCommon = "TAB     switch between windows\nESC     quit ncXBMC\n\n"
            @helpMSG = ""
        end

        def refresh
            @header.refresh
            @main.refresh
            @footer.refresh
        end

        def draw
            self.drawHeader
            self.drawMain
            self.drawFooter
        end

        def update(rheader=false, rmain=false, rfooter=false)
            if(rheader)
                drawHeader
                @header.refresh
            end
            if(rmain)
                self.drawMain
                @main.refresh
            end
            if(rfooter)
                self.drawFooter
                @footer.refresh
            end
        end

        def handleKey(key)
            #Ncurses.mvwaddstr(@main, 20, 1, "KeyCode: " + key.to_s)
            #@main.refresh

            case key
            when KEY_h then
                self.showHelp
            end
        end

        protected

        def drawHeader
            @header.erase
            @header.attron(Ncurses::A_BOLD) 
            Ncurses.mvwaddstr(@header, 0, 1, "Ncurses XBMC Client v." + NCXBMC_VERSION.to_s + " -- " + @title)
            @header.attroff(Ncurses::A_BOLD) 
            @header.mvhline(1,0,Ncurses::ACS_HLINE, @maxx)
        end

        def drawMain
            @main.erase
        end

        def drawFooter
            @footer.erase
            @footer.mvhline(0,0,Ncurses::ACS_HLINE, @maxx)
        end

        def handleScroll
            maxwy = Ncurses.getmaxy(@main) - 1
            if((@selected - @scroll) > maxwy)
                @scroll += 1 
            elsif((@selected - @scroll) < 0)
                @scroll -= 1
            end 
            return maxwy
        end

        def showHelp
            border = 15
            title = "Help"

            helpmsg = @helpMSGCommon + @helpMSG

            lines = helpmsg.count("\n") + 3
            helpwin = Ncurses::WINDOW.new(lines, @maxx-border, 2, (@maxx/2 - (@maxx-border)/2))
            Ncurses.box(helpwin, Ncurses::ACS_VLINE, Ncurses::ACS_HLINE)
            helpwin.attron(Ncurses::A_REVERSE)
            Ncurses.mvwaddstr(helpwin, 0, (@maxx-border)/2 - (title.length + 2)/2, " #{title} ")
            helpwin.attroff(Ncurses::A_REVERSE)

            linenbr = 1
            helpmsg.each { |line|
                Ncurses.mvwaddstr(helpwin, linenbr, 2, line.chomp)
                linenbr += 1
            }
            helpwin.refresh
        end
    end

    class PlaylistWin < TabWins
        def initialize(pscreen, xbmc)
            super
            @title = "Playlist"

            @forcesel = 0
            @fastRefresh = false
        end

        def drawHeader
            super

            volume = @xbmc.GetVolume.to_i
            if(volume > 0)
                volume_label = "Volume %d%%" % volume
            else
                volume_label = "Volume Muted"
            end
            Ncurses.mvwaddstr(@header, 0, @maxx - volume_label.length - 1, volume_label)
        end

        def drawMain
            super

            if(not @fastRefresh)
                getCurrentPlaylist
                getCurrentSong
            else
                @fastRefresh = false
            end

            return if @playlist.length == 1 and @playlist[0]["artist"].nil?

            maxwy = self.handleScroll
        
            idx = 0
            @playlist.each { |song|
                line = idx - @scroll
                if(line >= 0)
                    break if(line > maxwy)

                    current = (@playing and @current_song["URL"] == song["path"])	
                    if(current)
                        @main.attron(Ncurses.COLOR_PAIR(2)) if Ncurses.has_colors?
                        @main.attron(Ncurses::A_BOLD) 
                    end
                    @main.attron(Ncurses::A_REVERSE) if(idx == @selected)
                    Ncurses.mvwaddstr(@main, line, 1, "#{song["artist"]} - #{song["title"]}")
                    if(current)
                        @main.attron(Ncurses.COLOR_PAIR(1)) if Ncurses.has_colors?
                        @main.attroff(Ncurses::A_BOLD) 
                    end
                    @main.attroff(Ncurses::A_REVERSE) if(idx == @selected)
                end
                idx += 1
            }

        end

        def drawFooter
            super

            getCurrentSong

            if(@playing)
                speed = @xbmc.GetPlaySpeed.to_i
                @footer.mvwaddstr(0, 0, '=' * (@maxx * @current_song["Percentage"].to_i / 100) + (speed == 1 ? '0': (speed > 1 ? '>>':'<<')))
                paused = (@current_song["PlayStatus"] == "Paused")
                Ncurses.mvwaddstr(@footer, 1, 1, "Playing: #{@current_song["Artist"]} - #{@current_song["Title"]}   #{(paused ? "(Pause)":"")}")
                time_label = "["+@current_song["Time"]+"/"+@current_song["Duration"]+"]"
                Ncurses.mvwaddstr(@footer, 1, @maxx - time_label.length - 1, time_label)
                speed_label = "(%dX)" % speed
                @footer.mvwaddstr(0, @maxx - speed_label.length - 1, speed_label) if(speed != 1)
            end
        end

        def update(rheader=false, rmain=false, rfooter=true)
            super

            if(@playing) # new song playing, refresh playlist
                if(not rmain and (@current_song["Changed"] == "True"))
                    self.drawMain
                    @main.refresh
                end
            end
        end

        def handleKey(key)
            super

            refresh_header = false
            refresh_main = false
            refresh_footer = false

            case key
            when KEY_LEFT then 
                @xbmc.SetVolume(@xbmc.GetVolume.to_i - 1)
                refresh_header = true
            when KEY_RIGHT then 
                @xbmc.SetVolume(@xbmc.GetVolume.to_i + 1)
                refresh_header = true
            when KEY_DOWN then
                @selected += 1 if @selected < (@playlist.length - 1)
                @fastRefresh = true
                refresh_main = true
            when KEY_UP then
                @selected -= 1 if @selected > 0
                @fastRefresh = true
                refresh_main = true
            when KEY_ENTER then
                if(@xbmc.GetPlaySpeed.to_i != 1)
                    @xbmc.SetPlaySpeed(1)
                else
                    @xbmc.SetPlaylistSong(@selected)
                end
                refresh_main = true
            when KEY_d then
                @xbmc.RemoveFromPlaylist(@selected)
                @selected -= 1 if @selected >= (@playlist.length - 1)
                @forcesel = @selected
                refresh_main = true
            when KEY_c then
                @xbmc.Stop
                @xbmc.ClearPlayList(XBMC::MUSIC_PLAYLIST)
                @selected = 0
                refresh_main = true
            when KEY_f then
                speed = @xbmc.GetPlaySpeed.to_i
                newspeed = speed < 0 ? speed / 2 : speed * 2
                newspeed = 1 if(newspeed == -1)
                @xbmc.SetPlaySpeed(newspeed) if(speed < 32)
            when KEY_b then
                speed = @xbmc.GetPlaySpeed.to_i
                newspeed = speed > 0 ? speed / 2 : speed * 2
                newspeed = -2 if(newspeed == 0)
                @xbmc.SetPlaySpeed(newspeed) if(speed > -32)
            when KEY_m then
                @xbmc.Mute
                refresh_header = true
            when KEY_p then
                @xbmc.Pause
                refresh_footer = true
            end

            self.update(refresh_header, refresh_main, refresh_footer)
        end

        def showHelp
            @helpMSG =  "UP      select previous entry\n"
            @helpMSG += "DOWN    select next entry\n"
            @helpMSG += "ENTER   play selected entry\n"
            @helpMSG += "d       remove selected entry\n"
            @helpMSG += "c       clear current playlist\n\n"
            @helpMSG += "RIGHT   Volume +\n"
            @helpMSG += "LEFT    Volume -\n"
            @helpMSG += "m       mute volume\n\n"
            @helpMSG += "f       fast forward\n"
            @helpMSG += "b       fast rewind\n"
            @helpMSG += "p       pause playback"
            super
        end

        def getCurrentSong
            @current_song = @xbmc.GetCurrentlyPlaying
            @playing = (@current_song != nil) 
        end

        def getCurrentPlaylist
            playlist = @xbmc.GetPlaylistContents
            return if(playlist == @last_playlist)
            @last_playlist = playlist

            @selected = @forcesel
            @forcesel = 0

            @playlist = []   # cache tags infos for playlist
            playlist.each { |file|
                song = @xbmc.GetTagFromFilename(file)
                @playlist.push({"path"=>file, "artist"=>song["Artist"], "title"=>song["Title"]})
            }
        end

    end

    class LibraryWin < TabWins

        def initialize(pscreen, xbmc)
            super
            @title = "Library"
            @deepth = 0
            @lastdeepth = -1
            @currentdir = nil
            @history = []

        end

        def drawMain
            super

            if(@lastdeepth != @deepth) # refresh library entries list if needed
                @list = @xbmc.GetMediaLocation("music", @currentdir)
                @lastdeepth = @deepth
            end

            maxwy = self.handleScroll

            idx = 0
            @list.each { |entry|
                line = idx - @scroll
                if(line >= 0)
                    break if(line > maxwy)

                    @main.attron(Ncurses::A_REVERSE) if(idx == @selected)
                    Ncurses.mvwaddstr(@main, line, 1, "#{entry["name"]}")
                    @main.attroff(Ncurses::A_REVERSE) if(idx == @selected)
                end
                idx += 1
            }
        end

        def drawFooter
            super

            histline =  ""
            @history.reverse.each {|old|
                histline += " > " + old[:currentname] 
            }

            Ncurses.mvwaddstr(@footer, 1, 1, histline)

            nitems_label = @list.length.to_s + " items"
            @footer.mvwaddstr(1, @maxx - nitems_label.length - 1, nitems_label)
        end

        def handleKey(key)
            super

            refresh_header = false
            refresh_main = false
            refresh_footer = false

            case key
            when KEY_DOWN then
                @selected += 1 if @selected < (@list.length - 1)
                refresh_main=true
            when KEY_UP then
                @selected -= 1 if @selected > 0
                refresh_main=true
            when KEY_ENTER then
                if @list[@selected]["type"].to_i == XBMC::TYPE_DIRECTORY
                    @history.insert(0, {:currentdir=>@currentdir, :selected=>@selected, :scroll=>@scroll, :currentname=>@list[@selected]["name"]})
                    @currentdir = @list[@selected]["path"]
                    @selected = 0
                    @scroll = 0
                    @deepth += 1
                end
                refresh_main = true
                refresh_footer = true
            when KEY_RETURN then
                return if(@history.length < 1)
                oldentry = @history.shift
                @currentdir = oldentry[:currentdir]
                @selected = oldentry[:selected]
                @scroll = oldentry[:scroll]
                @deepth -= 1
                refresh_main = true
                refresh_footer = true
            when KEY_SPACE then
                @xbmc.AddToPlayList(@list[@selected]["path"], XBMC::MUSIC_PLAYLIST, "[music]")
                @xbmc.SetCurrentPlaylist(XBMC::MUSIC_PLAYLIST)
                #@xbmc.SetPlaylistSong(0)
            when KEY_c then
                @xbmc.Stop
                @xbmc.ClearPlayList(XBMC::MUSIC_PLAYLIST)
            end

            self.update(refresh_header, refresh_main, refresh_footer)
        end

        def showHelp
            @helpMSG =  "UP      select previous entry\n"
            @helpMSG += "DOWN    select next entry\n"
            @helpMSG += "ENTER   browse selected directory\n"
            @helpMSG += "RETURN  return into previous directory\n"
            @helpMSG += "SPACE   add selected directory/file to playlist\n\n"
            @helpMSG += "c       clear current playlist"
            super
        end
    end
end

##### MAIN ######

options = {}
inputopts = OptionParser.new do |opts|
    options[:port] = NCXMBC_DEFAULTPORT

    opts.banner = "Usage: %s [options] hostname" % File.basename($0)
    opts.separator " "

    opts.on("-v", "--version", "Print version") do |v|
        options[:version] = v
    end
    opts.on("-p", "--port [NUMBER]", Integer,"Port used (default %d)" % NCXMBC_DEFAULTPORT) do |port|
        options[:port] = port
    end
    opts.on("-U", "--user [NAME]", String, "Username used for authentication") do |name|
        options[:user] = name
    end
    opts.on("-P", "--password [PASS]", String, "Password used for authentication") do |pass|
        options[:pass] = pass
    end
end 

begin
    inputopts.parse!
rescue OptionParser::InvalidOption => e
    puts "Error: " + e
    puts "\n" + inputopts.banner
    exit 1
end

if(options[:version])
    puts "ncXBMC version " + NCXBMC_VERSION.to_s
    puts <<EOF
    
Copyright (C) 2009 Cedric TESSIER
    
This program may be redistributed under
the terms of the GPL v2 License
EOF
    exit 0
end

if(ARGV.length != 1)
    puts inputopts
    exit 1 
end

hostname = ARGV.first

xbmc = XBMC::XBMC.new(hostname, options[:port], options[:user], options[:pass])

begin
    puts "Connected to " + xbmc.host + " (xbmc " + xbmc.GetSystemInfo(120).first + ")"
rescue XBMC::UnauthenticatedError => e
    puts "ERROR: " + e
    exit 1
rescue SocketError => e
    puts "ERROR: Connection error"
    puts "Please check given hostname (and/or port)"
    exit 1
end

interface = Interface::NcurseInterface.new(xbmc)
interface.run

