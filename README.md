## 功能介绍
record_new.sh为自动录播脚本  
  * 支持youtube频道、twitcast频道、twitch频道、openrec频道、niconico生放送、niconico社区、niconico频道、mirrativ频道、reality频道、17live频道、chaturbate频道、bilibili频道、streamlink支持的直播网址、ffmpeg支持的m3u8地址
  * 其中youtube支持cookies录制，niconico支持登录账号录制，bilibili支持cookies录制与代理
  * 可以设置在其他频道直播时不进行录制避免转播与双推流
  * 支持rclone、onedrive与baidupcs上传并根据上传情况清理本地文件  

install.sh为一键安装脚本
  * 目前仅在ubuntu18.04与19.10系统测试过，理论上较新的linux系统应该都可以使用(centos系统把apt替换为yum应该就行了)  

record_twitcast.py是录制twitcast的websocket流的精简脚本

感谢[live-stream-recorder](https://github.com/printempw/live-stream-recorder)、[GiGaFotress/Vtuber-recorder](https://github.com/GiGaFotress/Vtuber-recorder)  

## 安装方法
#### 手动安装(推荐)

<details>
<summary>环境依赖</summary>

  * 自动录播脚本，安装方法为`mkdir record ; wget -O "record/record_new.sh" "https://github.com/lovezzzxxx/liverecord/raw/master/record_new.sh" ; chmod +x record/record_new.sh`
  * [ffmpeg](https://github.com/FFmpeg/FFmpeg)，安装方法为`sudo apt install ffmpeg`。
  * [streamlink](https://github.com/streamlink/streamlink)(基于python3)，安装方法为`pip3 install streamlink`。
  * [livedl](https://github.com/nnn-revo2012/livedl)(基于go，原项目[himananiito/livedl](https://github.com/himananiito/livedl)已失效)，具体编译安装方法可以参考作者的说明， __请将编译完成的livedl文件放置于运行时命令行所在目录的livedl/文件夹内__ 。否则无法使用twitcast、nicolv、nicoco、nicoch参数。
  * [record_twitcast.py文件](https://github.com/lovezzzxxx/liverecord/blob/master/record_twitcast.py)(基于python3 websocket库)，安装方法为`mkdir record ; wget -O "record/record_twitcast.py" "https://github.com/lovezzzxxx/liverecord/raw/master/record_twitcast.py" ; chmod +x "record/record_twitcast.py"`， __如果手动安装请将record_twitcast.py文件放置于运行时命令行所在目录的record/文件夹内并给予可执行权限即可__ 。否则无法使用twitcastpy参数。
  * [you-get](https://github.com/soimort/you-get)(基于python3)，安装方法为`pip3 install you-get`。否则无法使用bilibiliy参数。
  * [BilibiliLiveRecorder](https://github.com/nICEnnnnnnnLee/BilibiliLiveRecorder)(基于java)，安装方法为`mkdir BilibiliLiveRecorder ; cd BilibiliLiveRecorder ; wget https://github.com/nICEnnnnnnnLee/BilibiliLiveRecorder/releases/download/V2.13.0/BilibiliLiveRecord.v2.13.0.zip ; unzip BilibiliLiveRecord.v2.13.0.zip ; rm BilibiliLiveRecord.v2.13.0.zip ; cd ..`。否则无法使用bilibilir参数。
  * [rclone](https://github.com/rclone/rclone)(支持onedrive、googledrive、dropbox等多种网盘，需登录后使用)，安装方法为`curl https://rclone.org/install.sh | sudo bash`，配置方法为`rclone config`后根据说明进行。否则无法使用rclone上传。
  * [OneDriveUploader](https://github.com/MoeClub/OneList/tree/master/OneDriveUploader)(支持包括世纪互联版在内的各种onedrive网盘，需登录后使用)，安装和登录方法可以参考[Rat's Blog](https://www.moerats.com/archives/1006)。否则无法使用onedrive上传。
  * [BaiduPCS-Go](https://github.com/qjfoidnh/BaiduPCS-Go)(给予go，支持百度云网盘，需登录后使用，原项目[iikira/BaiduPCS-Go](https://github.com/iikira/BaiduPCS-Go)已失效)，安装和登录方法可以参考作者的说明。否则无法使用baidupan上传。

</details>

#### 一键安装(谨慎使用)【不建议使用root用户安装】

`curl https://raw.githubusercontent.com/lovezzzxxx/liverecord/master/install.sh | bash`  
  * __一键脚本安装后脚本调用方式应为`record/record_new.sh`而非下文示例中的`./record_new.sh`__
  * 一键脚本将会自动安装下列所有环境依赖， __同时会覆盖安装go环境并添加一些环境变量__ ，如果有需要可以注释掉相应的命令或者手动安装环境依赖
  * 其中record.sh、record_new.sh和record_twitcast.py会保存于运行时命令行所在目录的record文件夹下，livedl会保存于运行时命令行所在目录的livedl文件夹下， BilibiliLiveRecorder会解压到运行时命令行所在目录的BilibiliLiveRecorder文件夹下
  * 一键脚本运行结束后会提示仍需要手动进行的操作，如更新环境变量和登录网盘账号  

## 使用方法
#### 方法
`./record_new.sh [-参数 值] 频道类型 频道号码`

#### 示例
  * 使用默认参数录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw  
`./record_new.sh youtube "UCWCc8tO-uUl_7SJXIKJACMw"`  

  * 使用ffmpeg录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw ，使用record/you-cookies.txt中的cookeis检测youtube直播 使用record/you-config.txt中的配置录制youtube直播，依次获取1080p 720p 480p 360p worst中第一个可用的清晰度，间隔30秒检测，录像保存于record_video/mea文件夹中并在录制完成后自动上传到rclone中名称为vps的网盘的record目录中如果出错重试3次 和百度云网盘用户lovezzzxxx的record_video目录中如果出错则重试2次，如果其中有1个上传成功则删除本地录像  
`./record.sh youtubeffmpeg "UCWCc8tO-uUl_7SJXIKJACMw" --you-cookies "record/you-cookies.txt" --you-config "record/you-config.txt"  -f 1080p,720p,480p,360p,worst -l 30 -o "record_video/mea" -u rclone3:vps:record -u baidupcs2:lovezzzxxx:record_video -dt 1`  

  * 将上述命令后台运行，并将输出打印到record_log/meaqua_mea_youtube.log文件中  
`nohup ./record.sh youtubeffmpeg "UCWCc8tO-uUl_7SJXIKJACMw" --you-cookies "record/you-cookies.txt" --you-config "record/you-config.txt"  -f 1080p,720p,480p,360p,worst -l 30 -o "record_video/mea" -u rclone3:vps:record -u baidupcs2:lovezzzxxx:record_video -dt 1 > record_log/meaqua_mea_youtube.log &`

#### 参数说明
参数|默认值|说明
:---|:---|:---
--nico-id|无|nico用户名
--nico-psw|无|nico密码
--you-cookies|无|youtube监测cookies文件,需要配合--you-config参数使用
--you-config|无|youtube录制配置文件,仅支持youtube频道类型
--bili-config|无|bilibili录制配置文件,仅bilibili频道类型
--bili-cookies|无|bilibili录制cookies文件,仅支持bilibiliy频道类型
--bili-proxy|无|bilibili录制代理
--bili-proxy-url|无|bilibili录制代理获取链接
-f\|--format|best|清晰度
-p\|--part-time|0|分段时间，0为不分段
-l\|--loop-interval|60|检测间隔
-ml\|--min-loop-interval|180|最短录制间隔
-ms\|--min-status|1|开始录制前需要持续检测到开播次数
-o\|-d\|--output\|--dir|record_video/other|输出目录
-u\|--upload|无|上传网盘,格式为网盘类型重试次数:盘符:路径，网盘类型支持rclone baidupcs onedrive，例如rclone3:vps:record
-dt\|--delete-type|1|删除本地录像需要成功上传的数量，默认为1，del为强制删除，keep为强制保留，all为需要全部上传成功
-e\|--except|无|排除转播，格式同录制频道，如-e youtube "UCWCc8tO-uUl_7SJXIKJACMw
* youtube会限需要--you-cookies(用于监测)与--you-config(用于录制)同时使用
* bilibili会限需要--bili-config(使用bilibili频道类型时)或--bili-cookies(使用bilibiliy频道类型时)参数


<details>
<summary>--you-cookies格式示例</summary>

```
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	FALSE	1669471182	SID	aaaaaaaaaaaaaaaaaaaaaa.
.youtube.com	TRUE	/	FALSE	1648408153	HSID	aaaaaaaaaaaaaaa
.youtube.com	TRUE	/	FALSE	1648408153	SSID	aaaaaaaaaaaaaaaa
.youtube.com	TRUE	/	FALSE	1648408153	APISID	aaaaaaaaaaaaaa/aaaaaaaaaaaaaaa
.youtube.com	TRUE	/	FALSE	1648408153	SAPISID	aaaaaaaaaaaa/aaaaaaaaaaaaaaa
```
* 浏览器中打开www.bilibili.com时按f12，打开"网络"中带有cookies的请求，复制请求头中的cookeis如`SID=aaaaaaaaaaaaaaaaaaaaaa.; HSID=aaaaaaaaaaaaaaa; SSID=aaaaaaaaaaaaaaaa; APISID=aaaaaaaaaaaaaa/aaaaaaaaaaaaaaa; SAPISID=aaaaaaaaaaaa/aaaaaaaaaaaaaaa`到[cookies转换](http://tools.bugscaner.com/cookietocookiejar/)中并设置作用域为`.youtube.com`，将结果保存到任意文本文档中并在参数中设置运行时相对路径即可，推荐在首行添加示例中的注释

</details>


<details>
<summary>--you-config格式示例</summary>

```
http-cookie=SID=aaaaaaaaaaaaaaaaaaaaaa.
http-cookie=HSID=aaaaaaaaaaaaaaa
http-cookie=SSID=aaaaaaaaaaaaaaaa
http-cookie=APISID=aaaaaaaaaaaaaa/aaaaaaaaaaaaaaa
http-cookie=SAPISID=aaaaaaaaaaaa/aaaaaaaaaaaaaaa
```
* 获取cookies方法同上，将结果修改为上述格式后保存到任意文本文档中并在参数中设置运行时相对路径即可

</details>


<details>
<summary>--bili-config格式示例</summary>

```
http-cookie=DedeUserID=aaaaaa
http-cookie=DedeUserID__ckMd5=aaaaaaaaaaaa
http-cookie=SESSDATA=aaaa%2Caaaaa
http-cookie=bili_jct=aaaaaaaa
http-cookie=sid=aaaaaa
```

</details>


<details>
<summary>--bili-cookies格式示例</summary>

```
# Netscape HTTP Cookie File
.bilibili.com	TRUE	/	FALSE	1606047748	DedeUserID	aaaaaa
.bilibili.com	TRUE	/	FALSE	1606047748	DedeUserID__ckMd5	aaaaaaaaaaaa
.bilibili.com	TRUE	/	FALSE	1606047748	SESSDATA	aaaa%2Caaaaa
.bilibili.com	TRUE	/	FALSE	1606047748	bili_jct	aaaaaaaa
.bilibili.com	TRUE	/	FALSE	1606047748	sid	aaaaaa
```

</details>

## 旧版record.sh使用方法

<details>
<summary>点击展开</summary>

record.sh基本功能同上，但使用方式有较大区别。另外youtube与bilibili不支持cookies录制，仅bilibili支持排除转播，不支持任意多个网盘上传。

## record.sh使用方法
#### 方法
`./record.sh youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitcastpy|twitch|openrec|nicolv[:用户名,密码]|nicoco[:用户名,密码]|nicoch[:用户名,密码]|mirrativ|reality|17live|chaturbate|bilibili|bilibiliproxy[,代理ip:代理端口]|bilibilir|bilibiliproxyr[,代理ip:代理端口]|streamlink|m3u8 频道号码 [best|其他清晰度] [loop|once|视频分段时间] [10,10,1|循环检测间隔,最短录制间隔,录制开始所需连续检测开播次数] [record_video/other|其他本地目录] [nobackup|rclone:网盘名称:|onedrive|baidupan[重试次数][keep|del]] [noexcept|排除转播的youtube频道号码] [noexcept|排除转播的twitcast频道号码] [noexcept|排除转播的twitch频道号码] [noexcept|排除转播的openrec频道号码] [noexcept|排除转播的nicolv频道号码] [noexcept|排除转播的nicoco频道号码] [noexcept|排除转播的nicoch频道号码] [noexcept|排除转播的mirrativ频道号码] [noexcept|排除转播的reality频道号码] [noexcept|排除转播的17live频道号码]  [noexcept|排除转播的chaturbate频道号码] [noexcept|排除转播的streamlink支持的频道网址]`

#### 示例
  * 使用默认参数录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw   
`./record.sh youtube "UCWCc8tO-uUl_7SJXIKJACMw"`  

  * 使用ffmpeg录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw ，依次获取1080p 720p 480p 360p worst中第一个可用的清晰度，在检测到直播并进行一次录制后终止，间隔30秒检测，录像保存于record_video/mea文件夹中并在录制完成后自动上传到rclone中名称为vps的网盘和百度云网盘的相同路径 如果出错则重试最多三次 上传结束后根据上传情况删除本地录像，如果上传失败则会保留本地录像  
`./record.sh youtubeffmpeg "UCWCc8tO-uUl_7SJXIKJACMw" 1080p,720p,480p,360p,worst once 30 "record_video/mea" rclone:vps:baidupan3`  

  * 后台运行，使用代理服务器127.0.0.1:1080录制https://live.bilibili.com/12235923 ，最高清晰度，循环检测并在录制进行7200秒时分段，间隔30秒检测 每次录制从开始到结束最短间隔5秒，录像保存于record_video/mea文件夹中并在录制完成后自动上传到rclone中名称为vps的网盘和onedrive和百度云网盘的相同路径 如果出错则重试最多三次 上传完成后无论成功与否都保留本地录像，在https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw https://twitcasting.tv/kaguramea_vov 有直播时不进行录制，log记录保存于mea_bilibili.log文件  
`nohup ./record.sh bilibiliproxy,127.0.0.1:1080 "12235923" best 7200 30,5 "record_video/mea_bilibili" rclone:vps:onedrivebaidupan3keep "UCWCc8tO-uUl_7SJXIKJACMw" "kaguramea_vov" > mea_bilibili.log &`  

#### 参数说明

  * 必选参数，选择录制方式与相应频道号码  

网站|第一个参数|第二个参数|说明|注意事项
:---|:---|:---|:---|:---
youtube|`youtube`、`youtubeffmpeg`|`个人主页网址中的ID部分`(如UCWCc8tO-uUl_7SJXIKJACMw)|youtubeffmpeg为使用ffmpeg进行录制|请不要将第三个清晰度参数指定为best或1080p60及以上的分辨率
twitcast|`twitcast`、`twitcastffmpeg`、`twitcastpy`|`个人主页网址中的ID部分`(如kaguramea_vov)|twitcastffmpeg为使用ffmpeg进行录制，twitcastpy为使用record_twitcast.py进行录制|如果未安装相应依赖，则仅能使用twitcast参数，无法录制twitcast最高清晰度。 __请不要对同一场直播进行多个录制，会导致文件命名问题__
niconico|`nicolv`、`nicoco`、`nicoch`|分别为`niconico生放送号码`(如lv320447549)，`niconico社区号码`(如co41030)，`niconico频道号码`(如macoto2525)|可以在后方添加`:用户名,密码`来登录nico账号进行录制(如nicolv:user@mail.com,password)|如果未安装相应依赖，则无法录制niconico。 __请不要对同一场直播使用同一账号进行多个录制，会产生websocket链接冲突导致录像卡顿或反复断连__
bilibili|`bilibili`、`bilibiliproxy`|`直播间网址中的ID部分`(如12235923)|bilibiliproxy为通过代理进行录制，可以直接在后方添加`,代理ip:代理端口`指定代理服务器(如bilibiliproxy,127.0.0.1:1080)，也可以在脚本内相应部分添加代理获取方法
其他网站| `twitch`、`openrec`、`mirrativ`、`reality`、`17live`、`chaturbate`|`个人主页网址中的ID部分`，其中reality为频道名称(如果为部分名字则匹配含有这些文字的其中一个频道)或vlive_id(获取方法可于脚本内查找)|其中twitch使用streamlink检测直播状态，系统占用较高||
其他|`streamlink`、`m3u8`|`streamlink支持的个人主页网址或直播网址`、`直播媒体流的m3u8网址`||

  * 可选参数， __需要补全中间的参数才能指定后续的参数__

参数|功能|默认值|其他可选值|说明
:---|:---|:---|:---|:---
第三个参数|清晰度|`best`|`清晰度1,清晰度2`，可以用,分隔来指定多个清晰度|仅支持streamlink含有的清晰度，将会依次获取尝试直到获取第一个可用的清晰度
第四个参数|是否循环和录制分段时间|`loop`|`once`或`分段秒数`|如果指定为once则会在检测到直播并进行一次录制后终止，如果指定为数字则会以loop模式进行录制并在在录制进行相应秒数时分段。 __注意分段时可能会有十秒左右的视频缺失__
第五个参数|循环检测间隔和最短录制间隔和录制开始所需连续检测开播次数|`10,10,1`|`循环检测间隔秒数,最短录制间隔秒数,录制开始所需连续检测开播次数`，如果不以,分隔则最短录制间隔也为此值而录制开始所需连续检测开播次数为1|循环检测间隔是指如果未检测到直播，则等待相应时间进行下一次检测；最短录制间隔是指如果一次录制结束后，如果距离录制开始小于最短录制间隔，则等待到最短录制间隔进行下一次检测。最短录制间隔主要是为了防止检测到直播但录制出错的情况，此时一次录制结束如果立即进行下一次检测可能会因为检测过于频繁导致被封禁IP或者导致高系统占用，这种情况可能出现在网站改版等特殊时期，需要注意的是如果一次直播时间过短或者频繁断流也能触发等待；录制开始所需连续检测开播次数是指需要连续检测到相应次数的开播才会开始录制，可以用于预防一些检测到直播状态实际却并没有直播的情况。
第六个参数|本地录像存放目录|`record_video/other`|`本地目录`||
第七个参数|是否自动备份|`nobackup`|`rclone:网盘名称:` + `onedrive` + `baidupan` + `重试次数` + `无/keep/del`，不需要空格直接连接在一起即可(如rclone1del或rclone:vps:onedrivebaidupan3keep)|其中前三项的rclone、onedrive、baidupan分别指上传rclone相应名称的网盘、OneDriveUploader登录的onedrive网盘、BaiduPCS-Go登录的百度云网盘。第四项为重试次数，如果不指定则默认为尝试一次。第五项为上传完成后是否保留本地文件，如果不指定则上传成功将删除本地文件，上传失败将保留本地文件，keep参数为不论结果始终保留本地文件，del参数为不论结果始终删除本地文件。如果因为偶发的检测异常导致没有直播时开始录制，进而产生没有相应录像文件的log文件，脚本将会自动删除这个没有对应录像文件的log文件
第八至十四个参数|bilibili的录制需要排除的转播|`noexcept`|`相应频道号码`，具体同第二个参数，顺序分别为youtube、twitcast、twitch、openrec、nicolv、nicoco、nicoch、mirrativ、reality、17live、chaturbate、streamlink|仅bilibili录制有效，检测到相应频道正在直播时不进行bilibili的录制

</details>
