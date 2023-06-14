

用电视遥控器控制Kodi，映射LG电视机遥控器的红黄蓝绿键 （`.kodi/userdata/keymaps/remote.xml`）
```
<keymap>
        <global>
                <remote>
                        <skipminus>XBMC.Action(reloadkeymaps)</skipminus>
                        <stop>XBMC.ActivateWindow(Home)</stop>
                        <red>ContextMenu</red>
                </remote>
        </global>
        <home>
                <remote>
                        <blue>XBMC.ActivateWindow(VideoLibrary,TvShowTitles)</blue>
                        <green>XBMC.ActivateWindow(VideoLibrary,MovieTitles)</green>
                        <yellow>XBMC.ActivateWindow(MyMusic)</yellow>
                </remote>
        </home>
        <FullScreenVideo>
                <remote>
                        <play>Play</play>
                        <pause>Pause</pause>
                        <stop>stop</stop>
                        <skipplus>FastForward</skipplus>
                        <skipminus>Rewind</skipminus>
                        <red>Info</red>
                        <yellow>NextSubtitle</yellow>
                        <green>subtitledelay</green>
                </remote>
        </FullScreenVideo>
</keymap>
```

游戏镜像
- [Raspberry Pi 4 Archives - Arcade Punks](https://www.arcadepunks.com/category/raspberry-pi-and-other-sbc-images/raspberry-pi-4-images/)
- 
