## Tips

### 1. 切换桌面模式

-   游戏模式切换到桌面模式： 菜单 -\> `-> Power -> Switch to Desktop`
-   桌面模式切换到游戏模式： 点击桌面 `Switch to Game` 快捷方式

### 2. 设置密码

在桌面模式下需要设置密码才能使用`sudo`命令。运行Konsole打开命令行，输入以下命令来设置密码：

    passwd

在游戏模式下可以设置锁屏PIN来保护Steam Deck不被意外访问： 菜单
`-> Settings -> Security`

### 3. 安装桌面应用

-   推荐方式：在桌面模式下打开Discover App可以安装Flatpak应用。这些应用运行在沙箱中，而且不会被系统升级所覆盖。
-   其他方式：在[关闭只读模式](/SteamDeck#A.2BUXOV7VPqi.2FtqIV8P-)模式后，可以像普通Arch Linux一样用`pacman`或者`yay`来安装应用。注意：这些应用在系统升级时会被删除。
    -   pacman-key 默认没有被初始化，第一次运行pacman安装软件包会遇到签名错误。可以使用如下命令先初始化签名证书：

            sudo pacman-key --init
            sudo pacman-key --populate

### 4. 控制Flatpak应用的权限

在Flathub中搜索安装[Flatseal应用](https://flathub.org/apps/details/com.github.tchx84.Flatseal)。在Flatseal中可以详细控制每个Flatpak应用可以访问的权限。
详见[Flatseal文档](https://github.com/tchx84/Flatseal/blob/master/DOCUMENTATION.md)。

### 5. Flatpak安装的浏览器无法使用Native Messaging

某些浏览器插件使用Native Messaging与本地应用通讯，比如KeepassXC或者browserpass等。Flatpak安装的浏览器无法支持Native Messaging与host应用通讯。等待[此issue](https://github.com/flatpak/xdg-desktop-portal/issues/655)解决。

### 6. 默认进入桌面模式

运行以下命令可以让Steam Deck开机默认进入桌面模式

    steamos-session-select plasma-persistent

运行以下命令回到开机进入游戏模式

    steamos-session-select gamescope

### 7. 关闭只读模式

运行如下命令来关闭只读模式，这样就能运行`pacman`或者`yay`来安装程序了

    sudo steamos-readonly disable

运行如下命令回到只读模式

    sudo steamos-readonly enable

注意：关闭只读模式后通过`pacman`或者`yay`安裝的包在系统升级时会被删除。

### 8. 恢复系统

如果在关闭只读模式后将系统弄坏了，可以通过以下步骤恢复系统：

-   下载[恢复镜像](https://store.steampowered.com/steamos/download/?ver=steamdeck&snr=)
-   将恢复镜像写入U盘 （Windows下可以使用Rufus，Mac OS下可以使用Balena Etcher，Linux下可以使用dd命令）
-   将Steam Deck关机，将U盘插入Steam Deck，然后按住**音量减**按钮开机，在引导菜单中选择从U盘引导
-   引导后选择**Reinstall Steam OS**重新安装系统，用户数据会被尽量保留

详细步骤参考：[Steam Deck Recovery Instructions](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)

### 9. 桌面模式下的虚拟键盘和鼠标

-   触摸板可以模拟鼠标，按压右触摸板模拟鼠标点击，按压左触摸板模拟鼠标右击。
-   按STEAM + X键呼出虚拟键盘（在Steam应用运行的情况下）。

### 10. 运行模拟器

-   切换到桌面模式
-   安装emudeck: [https://www.emudeck.com/](https://www.emudeck.com/)
-   将Rom拷贝到 `~/Emulation/rom`目录。如果有Bios文件，将Bios文件拷贝到 `~/Emulation/bios`
-   运行桌面上的 Rom Manager 快捷方式，点击 `Preview -> Generate app list -> Save app list`
-   切换到游戏模式，运行模拟器游戏
-   设置手柄： [https://www.emudeck.com/#steam_input](https://www.emudeck.com/#steam_input)
-   模拟器内快捷键： [https://github.com/dragoonDorise/EmuDeck#hotkeys](https://github.com/dragoonDorise/EmuDeck#hotkeys)

### 11. 访问远程文件夹

在文件管理软件Dophin中可以直接访问远程SMB共享文件。如果需要在非KDE软件中访问远程文件，需要安装 `kio-fuse`

    sudo pacman -S kio-fuse

然后使用如下命令来访问共享目录 （替换 `smb://server/share` 为需要的远程路径）

    dbus-send --session --print-reply --type=method_call \
              --dest=org.kde.KIOFuse \
                     /org/kde/KIOFuse \
                     org.kde.KIOFuse.VFS.mountUrl "string:smb://server/share"

## 参考文档

-   [https://store.steampowered.com/steamdeck](https://store.steampowered.com/steamdeck)
-   [https://en.wikipedia.org/wiki/Steam_Deck](https://en.wikipedia.org/wiki/Steam_Deck)
-   [https://partner.steamgames.com/doc/home](https://partner.steamgames.com/doc/home)
-   [Fan The Deck](https://www.youtube.com/c/FanTheDeck)
-   [Steam Deck Desktop: FAQ](https://help.steampowered.com/en/faqs/view/671A-4453-E8D2-323C)
-   [Steam Deck Guide](https://github.com/mikeroyal/Steam-Deck-Guide)
-   [Steam Deck Recovery Instructions](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)
