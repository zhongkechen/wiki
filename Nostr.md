我的nostr：npub1g2v2zwct4acddy9tgga282fnf0hqvv026ds7fdgykjpmh7hfw26q5uy8gt

## 介绍

nostr （Notes and Other Stuff Transmitted by Relays）是一种简单开放的网络协议，可以用来创建反审查的全球化的社交网络。

### 1. 基本概念

-   客户端：安装在手机或者浏览器中的应用
-   中继（Relay）服务器： 运行中继软件的服务器，帮助不同用户的客户端相互连接
-   账户：nostr账户就是一个密钥，分为公钥和私钥两部分。公钥（以npub开头）就是账户id，可以分享给他人。私钥（以nsec开头）相当于账户密码。私钥要妥善保管好，不可丢失或者被他人获得。

### 2. 介绍文章

-   nostr到底是什么鬼？ [https://mp.weixin.qq.com/s/RoO-oOgGAXpcGyjD8IYBdw](https://mp.weixin.qq.com/s/RoO-oOgGAXpcGyjD8IYBdw)
-   聊聊 NOSTR 和 审查 [https://coolshell.cn/articles/22367.html](https://coolshell.cn/articles/22367.html)
-   nostr协议简介 [https://github.com/nostr-protocol/nostr](https://github.com/nostr-protocol/nostr)
-   nostr Resources [https://nostr-resources.com/](https://nostr-resources.com/)

### 3. Nostr的翻墙能力如何？

仅就当前版本的Nostr协议而言，

-   Nostr客户端之间通过中继服务器连接，封锁中继服务器即可阻断客户端直连使用
-   可以自建Relay暂时绕过封锁。但Relay服务器是公开列在每个账户的信息中的，也有类似 [https://nostr.watch/](https://nostr.watch/) 这样的网站直接搜集所有relay，所以自建Relay很容易被封锁。
-   当Relay被封锁后，要重建新的relay的话
    -   重建新的Relay可导致已发布的内容丢失。不过可以通过工具从被墙的relay上拉取数据然后重新发布在新的relay上来恢复数据。
    -   并且需要重建社区：通知所有其他好友使用新的Relay才能与好友共享信息。

所以当前Nostr协议抗防火墙能力是极其弱的，不过它还在快速演进中。如果加入Relay之间同步机制和本地数据存储机制，可以使其抗防火墙能力大大增强。

相比之下，SSB的抗防火墙能力要强得多。Nostr和SSB最大的区别是，Nostr用户只拥有账户（私钥）而不拥有数据（存在Relay上），SSB用户既拥有账户（私钥）也拥有数据（存储在本地）。Nostr的优点是客户端非常轻量（不存储数据），relay也相对轻量（只存储直连账户的数据）。

## 入门

首先安装客户端，然后是注册账户，最后添加中继（可选）。然后就可以开始正常使用了，添加好友，加入群聊。

### 1. 客户端

比较知名的客户端有

-   Damus (iOS) [https://damus.io/](https://damus.io/)
-   Amethyst (Android) [https://github.com/vitorpamplona/amethyst](https://github.com/vitorpamplona/amethyst)
-   Nostros (Android) [https://github.com/KoalaSat/nostros](https://github.com/KoalaSat/nostros)
-   iris.to [https://iris.to](https://iris.to)

客户端列表

-   特性对比 [https://github.com/vishalxl/Nostr-Clients-Features-List](https://github.com/vishalxl/Nostr-Clients-Features-List)
-   完整列表 [https://github.com/aljazceru/awesome-nostr](https://github.com/aljazceru/awesome-nostr)

注意：恶意的客户端应用可能会窃取你的私钥，导致你失去你的账户。

### 2. 账户

所有客户端在第一次打开时都会提示生成新账户（公私密钥对）或者使用已有账户（使用私钥登陆）

注册后，需要妥善保管nsec开头的私钥，不要给任何人。npub开头的公钥就是你的账户id，分享给其他人就可以加你为好友了。

如何认证账户？认证账户可以将你的账户关联到一个域名，在界面上获得一个紫色的勾并且会显示认证的域名

-   [https://gist.github.com/metasikander/609a538e6a03b2f67e5c8de625baed3e](https://gist.github.com/metasikander/609a538e6a03b2f67e5c8de625baed3e)
-   [https://github.com/nostr-protocol/nips/blob/master/05.md](https://github.com/nostr-protocol/nips/blob/master/05.md)
-   [https://github.com/zhgj/zhgj.github.io](https://github.com/zhgj/zhgj.github.io)
-   [https://nvk.org/n00b-nip5](https://nvk.org/n00b-nip5)

### 3. relay中继服务

基本上客户端都会内置一些可用的relay中继服务，所以一般都可以自动连接到relay服务器。如果需要，可以定制中继服务器。中继服务器也可以自建。

#### 3.1. 常用relay节点

Damus:

-   wss://relay.damus.io
-   wss://eden.nostr.land
-   wss://relay.snort.social
-   wss://nostr.orangepill.dev
-   wss://nos.lol
-   wss://relay.current.fyi
-   wss://brb.io

Amethyst:

-   wss://nostr.bitcoiner.social
-   wss://relay.nostr.bg
-   wss://brb.io
-   wss://relay.snort.social
-   wss://nostr.rocks
-   wss://relay.damus.io
-   wss://nostr.fmt.wiz.biz
-   wss://nostr.oxtr.dev
-   wss://eden.nostr.land
-   wss://nostr-2.zebedee.cloud
-   wss://nostr-pub.wellorder.net
-   wss://nostr.mom
-   wss://nostr.orangepill.dev
-   wss://nostr-pub.semisol.dev
-   wss://nostr.onsats.org
-   wss://nostr.sandwich.farm
-   wss://relay.nostr.ch

收费relays（有利于过滤垃圾回复和公众信息流）：

-   wss://nostr.milou.lol (1.000 sats)
-   wss://eden.nostr.land (5.000 sats)
-   wss://puravida.nostr.land (10.000 sats)
-   wss://relay.orangepill.dev (4.500 sats)

工具：查找离你最近的 relays（不同relays对比） ：[https://nostr.watch/](https://nostr.watch/)

#### 3.2. 自建relay

-   [https://github.com/scsibug/nostr-rs-relay](https://github.com/scsibug/nostr-rs-relay)
-   [https://andreneves.xyz/p/set-up-a-nostr-relay-server-in-under](https://andreneves.xyz/p/set-up-a-nostr-relay-server-in-under)

### 4. 关注好友

复制好友的id（公钥），复制粘贴到搜索框即可查找到该用户，然后点击添加即可。

连接Twitter或者其它社交网络的好友

-   打开 [https://www.nostr.directory/](https://www.nostr.directory/)
-   在网站上用twitter账户登陆，可以搜索到Twitter好友的nostr ID
-   在网站上验证自己的Twitter账户，就可以让自己的Twitter好友找到自己的nostr ID
-   还可以在网站上验证自己的Telegram、Mastodon、Github账户

名人

-   Jack（推特创始人） npub1sg6plzptd64u62a878hep2kev88swjh3tw00gjsfl8f237lmu63q0uf63m
-   defi3w npub19786pedeqk8mpj9favvzxrz44h6d3d3c6ur2fe9592cgqljm9g7qcz8jjs
-   斯诺登 npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9
-   张颂文 npub10m5k6ats7mnwfwhpdaqc3ta6cffvwekc9ugx45h3syg6j4j67msqy75c5g
-   TumbleBit npub156etfp73lfc2ax0ekj557sezuag0sjzdqhljm4v9tmda62nev4rqrtug7y
-   熊越 npub1rsg3xkte3zyrn3m0jg0gwh2jpfszry0kfzew7q9tq5yq8sqjh9nquuas8t
-   超级君 npub16a7m863zhkzpd5ezzkz08rlr900eateap5dwamynssysdv6hhhqsctuk9g
-   神鱼 npub1ppgr0lsnx5l7hqulw4kcrhgctd3jqkuaxh6d0lftpd4alj2rct2qshk0zr
-   陈默 npub1zv5zhy0f83kgqz99eqfya4f4wveznkx3aa86lxcvllpcrrc9qvdsz65dtd
-   余弦 npub1n2prk4drfh570tc7qzvlcaa3pnj2fud7vu4jshymfp3w8sx2evpqx866nz
-   头雁 npub1ks5hclkksh7ghd8v2058wkut3k35xucs372u96csl4mhsm29e7gsy9cs5r
-   民道 npub15r9dfrldhzwu0s86dd6qmy6e8pka9pmncq29xxcmc0drg89dcqrqsk968a
-   郭宇 npub1ztmzpw9w4ta375wktvj98lwt6y2jjc78spg60kwyvkhjty3cr8ysengahm
-   大姨妈 npub1ana3ft0s7kznrjzu8maffwpfqd0lxj0nkv39gaqvwue7sse3w5uqmqdymm
-   和菜头 npub1rnyzrnpdguv3k90uls8h8tld8x5x43hmxnal57vnaclq7qvxaa7q8n6u3e
-   陈威廉 npub1fcn6gcrpn0p6p7yh54qnu4a5rqmns8axg5af46ylytlx0t092gfqy6y7su
-   RON npub1hn8hq6gha0vpcvpgf45z5vng987qrd4v54mw4rgu09hguzzvk83qy58enw
-   林嘉鹏 npub15tn7q4l92jaav50rlah67v42x57rlm8v0vh4v0dv69g485973yeqyq7pk8
-   陈子豪 npub1x8sh8lm7h8kpwq0njsyf35yelz9qxd2fhxzc9jp344yz5093p4rsvth5vj
-   元杰 npub1u8jx386gvmuk0r78zwtfgyr8pfflwm9wt2tp4djzdr7w49h09leqhhdwnm
-   行长 npub10xz6jj4xh5kjztusd2vuwmsp6dua7zcyqzwgnvavdwxf3uva8kxqjq03xq
-   王峰 npub1n6fa79g7wfqn2fg3x9fkfw7zn00zqe8xr8j2n0je4lk5kf7k855s68y46y
-   孔剑平 npub1qkgrzq3kxdrxsgq7cutkk9pdahw3yzmtgdc2a2vnexxu7qt8ta0sywa0qm
-   大硕 npub104ce7lgt485p6r09cfwldpjsza0sg2dghu4cr5hv73zdvc59mv0qt3hatz
-   杨虎成 npub1km9x5x7cdj79xquyqx3dy5gc3cyamwqp27eylashxskyap7rt7sstfxpur
-   星主 npub1rfvtnvxmks4rng82g84zjh4nhhtufgh5x65jpcmfxl0dslqlsgnsv7wx05
-   jialin npub1zx6mydeeqwhpcvdkyx83r8t9m2yesgyy5tdd4496fqyavgrmnkjqehqzqy
-   王大拿 npub1emx34qaf9lszh30qllvscdeaq9eahlk47e2dkyfphwc66tmva3yqq32tjh
-   买牛 npub1rxl5l333zkhwwdd0pzhxkscfny95zthxz4xtn28y8t7drxndyl4qwxwnde
-   孔华威 npub1sxrq370gs8w23vuq2a3tpw3j8wv0ehyvajfvp5ptnjsdj4epp9sq6ca5pf
-   朱砝 npub1qazh05fcjek2vgs8qwkr5k5la4jekwvvuw98queaclykz6uemr9q9dvnwv
-   吕国宁 npub1p7wwm0e82jtslz4r95nmzudtcnduumyuaq7qpjh52cg623540jds7agqnd
-   彭松 npub15vdxr28yz7cwmh889tzgvqm6v6jtpsmlmk9u2m3yg2z0swadh6eshc6dux
-   成笑 npub18yfe75urapvepvk3vnml5qf9vkrrfxh0mv90xhzfq00jh7hpupqqlf8z24
-   orangefans npub1p3xl5e283x6yxshhwqyldyzwmshzwqhxpk93e00tlpzelszt5tmsx90qfe
-   左耳朵耗子 npub1w6r99545cxea6z76e8nvzjxnymjt4nrsddld33almtm78z7fz95s3c94nu
-   gpt3 bot npub1tsgw6pncspg4d5u778hk63s3pls70evs4czfsmx0fzap9xwt203qtkhtk4

查找其它更多nostr用户

-   查找热门用户，热门帖子，热门标签 [https://nostr.band](https://nostr.band)
-   查找最受欢迎的nostr用户 [https://nostrum.pro/search/#users](https://nostrum.pro/search/#users)
-   Top50用户，增长曲线 [https://nostr.io/stats](https://nostr.io/stats)

### 5. 基础社交功能

#### 5.1. 公开帖子

发布公开的帖子给所有人，查看好友发布的公开帖子，查看所有人发布的公开帖子

如何发帖的时候引用原帖

1.  在原帖右下角找到note id，copy
2.  发帖的时候加上 \@原帖noteid

如何删除自己发的帖子

1.  登陆 snort.social
2.  导入私钥（以nsec开头）
3.  在note中选择要删除的帖子，delete

#### 5.2. 私聊

与好友1对1私聊

#### 5.3. 群聊

在Amethyst app中搜索群id可以查看及加入群

-   nostr官方群 note1yhjusgnn5fcukx5yp5qxqwg6p06fvh90avpf6k442dgtgxy487as4cpxj7
-   Amethyst 官方群 note1gg3ysktkxeffznd4xpfpq0ctw3xl080ufml0062slsyq9lpa70zsrtqve8
-   中国单身美女帅哥交流群 note1zxd7t0s5wn7p7u703c50fml0vznfwyw8dz75vwu40y29a274jk0q9dk9d9
-   ChatGPT Web3玩家群 note1lqmmdvmq3dn8hj60tgghyhjk782q36hwmt9dpjjw93qswh5hxqxqzzdwkq
-   单身交友群 note1t4uq0d68dduthdflnjt64y95tez22mc2wz2xqvswrdkp5kck5djqs92jy2
-   NFT交流群 note1aepr2z5zkyzfu4535gnh9ksnyqw5u73xk9ss6fxzl2kuyv3frx2snz7le0
-   第一中文频道 note1kntfymwsg28sh5mqztc8yxnsknpczsx3gxl6tm7zzea42xsdnleqpsg4ul

注：当前只有Android客户端Amethyst支持群聊

如何屏蔽群里广告？

-   群里点击文本，按 "hide user"

如何在频道/群里面回复其他用户时带原文

1.  点击需要回复的发言，选择 copy text
2.  粘贴到搜索框
3.  找到在频道内发言（ in channel ）的搜索结果
4.  点击第一个评论按钮，输入文本，提交post，即可在频道内附带原文进行评论

### 6. 图片和视频相关

如何换头像和 Banner

-   在设置中粘贴自己的头像链接和 banner的图片链接就可以，获取方式可以通过 opensea 等网站上的图片点击右键"获取图片链接"，或者在 [https://postimages.org/](https://postimages.org/) 生成。

如何发表图片和视频

-   粘贴图片或视频的链接到文本框，发布。

图片链接可通过以下方式获取

1.  登陆postimage.org，选择图片上传，点击start now
2.  生成图片链接，选择.jpg结尾的链接复制（选择图片链接）
3.  回到客户端，粘贴、发布即可

图片相关网站

-   Nostr艺术图片（目测应该是AI生图） [https://www.nostrland.com/](https://www.nostrland.com/)
-   查找/生成Gif动图链接 [https://tenor.com/](https://tenor.com/) [https://giphy.com/](https://giphy.com/)
-   图床，生成图片链接用来发图片 [https://nostr.build](https://nostr.build)

## 闪电网络

nostr关联到闪电网络（Lightning Network）来进行支付。

### 1. 闪电网络钱包

易用的custodial钱包 [BlueWallet](/BlueWallet) / Wallet of Satoshi

non-custodial钱包更安全，但易用性更差

浏览器插件： [https://getalby.com/](https://getalby.com/)

### 2. 闪电网络地址介绍

1.  以 lnbc 开头的是闪电网络一次性收款invoice，通常有时间限制，不可多次使用
2.  以 lnurl 开头 / 邮箱 是闪电网络长期收款地址，可以多次使用
3.  以 lndhun:// 开头类似闪电网络私钥，切勿外传

### 3. 如何通过闪电网络乞讨以及打赏

1.  下载安装bluewallet，添加闪电网络钱包
2.  乞讨：点击收款，填写金额，生成invoice，直接将invoice id（lnbc开头）复制粘贴即可
3.  打赏：点击pay按钮，调用bluewallet支付

## Nostr 相关工具网站

-   Nostr 数据统计（可查询总用户数/Top50 粉丝数，增长曲线）: [https://www.nostr.directory/stats](https://www.nostr.directory/stats)
-   创建一个nostr机器人用户，关注后自动跟踪某个关键词 [https://sb.nostr.band](https://sb.nostr.band)
-   为rss feed创建一个账户，同步rss内容到这个账户 [https://rsslay.nostr.moe/](https://rsslay.nostr.moe/)
