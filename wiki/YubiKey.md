Yubico公司生产的一种安全密钥，可用于多种身份认证、二次认证、公钥加密场景。

## 功能接口 

YubiKey总共有三种功能接口：OTP、FIDO和CCID。一个YubiKey 5系（比如YubiKey 5 NFC等）同时支持三种接口，而Yubico Security Key只支持FIDO接口。

-   OTP：静态密码, Yubico OTP, Challenge-Response, 传统的OATH-HOTP
-   FIDO：FIDO2，U2F
-   CCID：OpenPGP, PIV, OATH

功能接口不同于物理接口。不同型号的YubiKey可能会有不同的物理接口，比如USB-A、USB-C、NFC、Lightning等。

通过YubiKey Manager -\> Interfaces 可以设置各个接口和功能的开启状态（OTP接口下的四种功能只能一起关闭或者打开）。

### 1. FIDO

系统将YubiKey的FIDO接口识别为一个HID设备。YubiKey通过该接口来支持FIDO联盟的[U2F协议](https://zh.wikipedia.org/wiki/%E9%80%9A%E7%94%A8%E7%AC%AC%E4%BA%8C%E5%9B%A0%E7%B4%A0)以及更新版的[FIDO2协议](https://zh.wikipedia.org/wiki/FIDO2)，提供网站登录的二次验证（2FA）以及无密码登录功能。该二次验证方式比传统的TOTP更加安全（防止MITM）、更加方便（只需轻触无需输入）。

支持该功能的网站包括Google、Twitter、Facebook、Github等等（完整列表详见 [1](https://www.yubico.com/ca/works-with-yubikey/catalog/?series=1&sort=popular) 以及 [2](https://www.buybitcoinworldwide.com/dongle-auth/#) ）。该功能也需要设备和浏览器的支持，最新版本的各种浏览器以及Android（无谷歌框架的安卓系统无法支持）、iOS系统（13+）均支持该功能。

许多其他厂商的硬件密钥也支持FIDO U2F或者FIDO2协议，比如[SoloKeys](https://solokeys.com/)和[Nitrokey](https://www.nitrokey.com/)等。

#### 1.1. FIDO2

FIDO2需要浏览器支持Webauthn协议（现代浏览器都支持）。

这是YubiKey使用最方便的一种模式。

1.  第一次使用可以在 YubiKey Manager -\> Applications -\> FIDO2 中设置FIDO2 PIN。
2.  在支持该功能的网站中找到二次验证或者无密码登录设置，选择添加YubiKey
3.  登录时在看到浏览器提示后轻触YubiKey，然后输入FIDO2 PIN。

FIDO2的应用场景

-   与LUKS集成 [https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html](https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html)
-   SSH登录 [https://wiki.archlinux.org/title/SSH_keys#FIDO/U2F](https://wiki.archlinux.org/title/SSH_keys#FIDO/U2F)
-   支持FIDO2的服务 [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=5&sort=popular](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=5&sort=popular)

#### 1.2. U2F

U2F是FIDO2的前身，基本上已经被FIDO2取代。使用方法和FIDO2几乎一样，主要用于二次验证，但不支持PIN保护和无密码登录。

不同于FIDO2的Webauthn标准协议，U2F需要浏览器有针对U2F的特殊支持。兼容U2F的硬件密钥都可以兼容FIDO2，但反之不然。

### 2. CCID

系统会将YubiKey的CCID接口识别为一个智能卡读卡器，不同的YubiKey功能会被识别为读卡器上不同的智能卡。YubiKey通过该接口支持PIV、OpenPGP以及OATH三种功能。

#### 2.1. OATH

OATH是一种生成二次验证码的标准，包括TOTP和HOTP两种验证码。通过这个接口使用OATH功能可以存储32组密钥，与此相对的，通过OTP接口使用OATH-HOTP只能存储一组密钥。

-   TOTP: 此模式即Google Authenticator等二次验证应用所使用的算法，此算法依赖当前时间，而YubiKey没有内建时钟，所以依赖YubiKey所连接的设备的时间。
-   HOTP: 此模式和TOTP类似，但不依赖时间而是依赖计数器来生成验证码。每生成一次验证码，内部计数器加1。

以上两种验证码，都可以通过Yubico Authenticator应用来输入密钥及生成二次验证码，具体方法参考 [https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/oath/yubico-authenticator.md](https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/oath/yubico-authenticator.md)

支持TOTP的服务非常多，就不在此举例。支持HOTP的服务可在此找到列表： [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=2&sort=popular](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=2&sort=popular)

#### 2.2. PIV

PIV模块可用于存储非对称加密密钥，并可进行登录、验证、加密解密等操作。

PIV模块共有四个可以直接存储的槽可以储存四个证书。此外还有20个槽用于存储历史证书，以方便解密过去的密文。

-   9a 插槽：PIV 验证。验证智能卡和持卡人（比如用于操作系统登录、ssh、wifi、OpenVPN、curl、Android code、Mac code、屏幕自动解锁）。通常 PIN 只会请求一次，在后续操作中可能会被重复使用。
-   9c 插槽：电子签名。签名对象（Android code 签名、Mac code 签名、储存中间 CA 私钥签名）。一般来说，每次操作都需要验证 PIN。
-   9d 插槽：钥匙管理。以保密为目的加密对象时，通常 PIN 只需要请求一次，在后续操作中可以重复使用。
-   9e 插槽：安全卡验证。当需要物理手段进行验证时（比如门锁），通常情况不需要验证 PIN。

第一次使用PIV功能，需要设置PIN。

-   打开YubiKey Manager -\> Applications -\> PIV，点击Configure PINs
-   分别设置PIN，PUK和Management Key。默认的PIN、PUK和Management Key分别为：123456，12345678和010203040506070801020304050607080102030405060708。

基于PIV的应用场景很多，可以实现SSH登录、操作系统登录、全盘加密等，以下就常见应用举例。

-   MacOS登录: 打开 YubiKey Manager -\> Applications -\> PIV，点击Setup for macOS可以完成配对。配对完成后下次登录，只需要输入PIV PIN而无需输入系统密码。
-   Windows登录: [https://support.yubico.com/hc/en-us/articles/360013708460-Yubico-Login-for-Windows-Configuration-Guide](https://support.yubico.com/hc/en-us/articles/360013708460-Yubico-Login-for-Windows-Configuration-Guide)
-   SSH登录:
    -   [ssh-agent + opensc](https://ruimarinho.gitbooks.io/yubikey-handbook/content/ssh/authenticating-ssh-with-piv-and-pkcs11-client/)
    -   [ssh-agent + pkcs11](https://developers.yubico.com/PIV/Guides/SSH_with_PIV_and_PKCS11.html)
    -   [yubikey-agent](https://github.com/FiloSottile/yubikey-agent)
    -   [pivy-agent](https://github.com/TritonDataCenter/pivy#using-pivy-agent)
-   其它支持PIV的服务和应用可在此找到列表： [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=6&sort=popular](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=6&sort=popular)

#### 2.3. OpenPGP

YubiKey的这个接口兼容OpenPGP标准，配合GnuPG等软件可以进行邮件签名加密解密等操作。

-   导入密钥： [https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/importing-keys.md](https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/importing-keys.md)
-   设置PIN： [https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/editing-metadata.md](https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/editing-metadata.md)
-   为密钥设置触摸保护： [https://github.com/a-dma/yubitouch](https://github.com/a-dma/yubitouch)
-   使用多个Yubikey： [https://github.com/drduh/YubiKey-Guide#using-multiple-keys](https://github.com/drduh/YubiKey-Guide#using-multiple-keys)

在切换多个Yubikey时，使用如下命令

    gpg-connect-agent "scd serialno" "learn --force" /bye

OpenPGP的应用场景很多，以下仅就常见的应用举例。

-   SSH登录 [https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/authenticating-ssh-with-gpg.md](https://github.com/iamtwz/yubikey-handbook-chinese/blob/master/openpgp/authenticating-ssh-with-gpg.md)
-   Git签名 [https://ruimarinho.gitbooks.io/yubikey-handbook/content/openpgp/git-signing/](https://ruimarinho.gitbooks.io/yubikey-handbook/content/openpgp/git-signing/)
-   Docker内容信任 [https://ruimarinho.gitbooks.io/yubikey-handbook/content/docker-content-trust/](https://ruimarinho.gitbooks.io/yubikey-handbook/content/docker-content-trust/)

### 3. OTP

这是从最初版本的YubiKey继承下来的传统接口，系统会将该接口识别为一个键盘设备。该接口的名字因为最初只支持Yubico OTP而命名，如今它具有误导性，因为它支持静态密码、Yubico OTP、Challenge-Response以及传统的OATH-HOTP（新的OATH通过CCID接口实现）四种功能。

OTP接口有两个槽，分别对应轻触和长按YubiKey。每个槽都可以配制成四个功能中的任意一个。

注意：如非必要，尽量使用前面两种模式而不是这种模式。

-   OTP下的模式要么无加密（Static password），要么功能受限（OATH-HOTP仅支持一组密钥），要么使用对称加密（密钥不仅存储在Yubikey中，也存在验证服务器上，验证服务器本身的安全性限制了这种模式的安全性），而且Yubico OTP协议容易受到依赖目标系统与验证服务器的连接安全，因此需要目标系统通过HTTPS或者HMAC来验证验证服务器。总之相对U2F等更现代的协议，此协议相对更不安全。
-   由于键盘布局的问题，这种模式能完全正常使用的字符是有限制的。Yubico OTP通过使用ModHex[1](https://resources.yubico.com/53ZDUYE6/as/9hccqgx9bwwqq96mhkk8jb4h/Static_Password_Function.pdf)绕过了这种限制，但静态密码就没有这么幸运了。

#### 3.1. 静态密码

通过YubiKey Manager可以设置静态密码。使用时轻触或者长按YubiKey即可在当前光标处输入提前设置的密码。

#### 3.2. Yubico OTP

这种模式下，YubiKey通过对称加密算法生成一次性的token发送给服务器进行验证。服务器拥有和YubiKey一样的对称加密密钥，通过解密token来验证用户身份。

YubiKey在出厂时已经内置了一组密钥。如果使用Yubico提供的YubiCloud服务器进行验证，则无需任何配置。

注意：出厂密钥具有一个特殊的前缀CC，如果清除后则无法再生成。某些服务强制需要使用CC前缀的密钥。

支持该模式的服务有： [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=3&sort=popular-for-individuals](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=3&sort=popular-for-individuals)

#### 3.3. Challenge-Response

这个模式下YubiKey可以根据事先存储的密钥对输入值进行变换，输出一个哈希值。YubiKey支持HMAC-SHA1和Yubico OTP两种算法。

使用方法

-   在YubiKey Manager -\> Applications -\> OTP -\> Configure 选择 Challenge-response，生成一个新密钥或者输入一个以前的密钥。

主要使用场景有

-   LUKS Full Disk Encryption [https://github.com/agherzan/yubikey-full-disk-encryption](https://github.com/agherzan/yubikey-full-disk-encryption)
-   登录Mac [https://developers.yubico.com/yubico-pam/MacOS_X_Challenge-Response.html](https://developers.yubico.com/yubico-pam/MacOS_X_Challenge-Response.html)
-   在KeepassXC中保护密码数据库 [https://keepassxc.org/docs/KeePassXC_UserGuide.html#\_database_settings](https://keepassxc.org/docs/KeePassXC_UserGuide.html#_database_settings)
-   其它支持该协议的服务有： [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=8&sort=popular](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=8&sort=popular)

#### 3.4. OATH-HOTP

这个功能和基于CCID接口的[OATH-HOTP](/YubiKey#OATH)所提供的功能相同。区别是这个功能只支持一组密钥，CCID接口支持32组密钥；这个功能激活更方便，只需要轻触或者长按即可，无需软件支持，而CCID接口需要Yubico Authenticator应用支持。

使用方式

-   在YubiKey Manager -\> Applications -\> OTP -\> Configure选择OATH-HOTP，然后输入密钥。
-   在需要输入验证码时，轻触或者长按YubiKey。

支持HOTP的服务列表： [https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=2&sort=popular](https://www.yubico.com/ca/works-with-yubikey/catalog/?protocol=2&sort=popular)

## 应用下载

-   [YubiKey Manager](https://www.yubico.com/support/download/yubikey-manager/): YubiKey配置工具
-   [Yubico Authenticator](https://www.yubico.com/products/yubico-authenticator/): 二次验证码生成工具
-   [YubiKey Smart Card Minidriver (Windows)](https://www.yubico.com/support/download/smart-card-drivers-tools/): Windows智能卡驱动

## 固件版本

Yubico [声称](https://support.yubico.com/hc/en-us/articles/360013708760-YubiKey-Firmware-Is-Not-Upgradeable)为了安全起见，YubiKey的固件是无法升级的。所以购买YubiKey时除了留意硬件规格，还要留意固件版本。

-   有些固件版本有已知的安全漏洞： [https://www.yubico.com/support/security-advisories/](https://www.yubico.com/support/security-advisories/)
-   有些功能只在新版本的固件中支持
    -   [https://docs.yubico.com/hardware/yubikey/yk-5/tech-manual/yk5-overview-5.4.html#](https://docs.yubico.com/hardware/yubikey/yk-5/tech-manual/yk5-overview-5.4.html#)
    -   [https://www.yubico.com/blog/whats-new-in-yubikey-firmware-5-2-3/](https://www.yubico.com/blog/whats-new-in-yubikey-firmware-5-2-3/)

## 参考资料

-   官方使用向导 [https://www.yubico.com/setup/](https://www.yubico.com/setup/)
-   [https://docs.yubico.com/hardware/yubikey/yk-5/tech-manual/index.html](https://docs.yubico.com/hardware/yubikey/yk-5/tech-manual/index.html)
-   不同型号特性比较 [https://www.yubico.com/products/compare-products-series/](https://www.yubico.com/products/compare-products-series/)
-   官方手册 [https://support.yubico.com/support/solutions/articles/15000014219-yubikey-5-series-technical-manual](https://support.yubico.com/support/solutions/articles/15000014219-yubikey-5-series-technical-manual)
-   固件5.2.3 [https://www.yubico.com/blog/whats-new-in-yubikey-firmware-5-2-3/](https://www.yubico.com/blog/whats-new-in-yubikey-firmware-5-2-3/)
-   YubiKey Handbook [https://ruimarinho.gitbooks.io/yubikey-handbook/content/](https://ruimarinho.gitbooks.io/yubikey-handbook/content/) - [中文版](https://github.com/iamtwz/yubikey-handbook-chinese)
-   YubiKey Guide [https://github.com/drduh/YubiKey-Guide](https://github.com/drduh/YubiKey-Guide)
-   [https://wiki.archlinux.org/title/YubiKey#OTP_slot_implementation](https://wiki.archlinux.org/title/YubiKey#OTP_slot_implementation)
-   [三种SSH登录方式比较](https://developers.yubico.com/PIV/Guides/Securing_SSH_with_OpenPGP_or_PIV.html)
