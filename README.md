# 功能介绍
record.sh为自动录播脚本。
  * 支持youtube频道、twitcast频道、twitch频道、openrec频道、niconico生放送、niconico社区、niconico频道（支持登陆niconico账号进行录制）、mirrativ频道、reality频道、17live频道、bilibili频道、streamlink支持的直播网址、ffmpeg支持的m3u8地址。  
  * bilibili录制支持在youtube频道、twitcast频道、twitch频道、openrec频道、mirrativ频道、reality频道有直播时不进行录制，从而简单的排除转播的录制。支持在请求bilibili直播媒体流链接时使用代理。  
  * 支持按照录制时长分段。  
  * 支持rclone上传、onedrive一键脚本上传、百度云上传。支持可指定次数的上传出错重试。支持根据上传结果选择是否保留本地文件。  
  * 如果因为偶发的检测异常导致没有直播时开始录制，进而产生没有相应录像文件的log文件，脚本将会自动删除这个没有对应录像文件的log文件。  

record_twitcast.py为可选，是一个可以录制websocket的精简脚本。因为twitcast分别提供了基于h5与的websocket流，但最高清晰度仅能通过websocket获取，而ffmpeg并不能支持websocket，所以提供一个可以录制websocket的脚本。也可单独使用，方法为`python3 record_twitcast.py "ws或wss网址" "输出文件目录"`。  

download.sh与录制功能无关，是一个完全独立的小脚本。本质是轮询检测youtube频道的直播和视频页第一页，产生一个youtube视频列表，并对列表中视频的录像、封面图、标题与简介进行备份。因为youtube上时长不足两小时的直播，直播结束后到删档前仍有一段时间可以下载完整的视频，而且一旦开始下载则下载过程不受删档影响，所以也内置了在下播后及时尝试下载的功能。对于时长超过两小时的直播，则会等待压制完成后进行下载。具体用法可直接不加参数运行`download.sh`查看。（另外由于脚本的工作状态完全取决于视频列表的内容，所以直接指定或修改视频列表大概会有奇怪的作用）

感谢[live-stream-recorder](https://github.com/printempw/live-stream-recorder)、[GiGaFotress/Vtuber-recorder](https://github.com/GiGaFotress/Vtuber-recorder)。  

# 环境依赖
  * [ffmpeg](https://github.com/FFmpeg/FFmpeg)
  * [streamlink](https://github.com/streamlink/streamlink)(基于python3)
  * [livedl(可选)](https://github.com/himananiito/livedl)(基于go)， __请将编译完成的livedl文件放置于运行时目录的livedl/文件夹内__ 。否则无法使用twitcast参数与niconico相关参数进行twitcast高清录制与niconico录制。  
  * [record_twitcast.py文件(可选)](https://github.com/lovezzzxxx/liverecord/blob/master/record_twitcast.py)(基于python3 websocket库)， __请将record_twitcast.py文件放置于运行时目录的record/文件夹内__ 。否则无法使用twitcastpy参数进行twitcast高清录制。  

  * [rclone(可选)](https://github.com/rclone/rclone)(需登陆后使用)，否则无法使用rclone参数上传。  
  * [OneDrive for Business on Bash(可选)](https://github.com/0oVicero0/OneDrive)(需登陆后使用)，否则无法使用onedrive参数上传。    
  * [BaiduPCS-Go(可选)](https://github.com/iikira/BaiduPCS-Go)(需登陆后使用)，否则无法使用paidupan参数上传。    

# 使用方法
### 方法
`record.sh youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitcastpy|twitch|openrec|nicolv[:用户名,密码]|nicoco[:用户名,密码]|nicoch[:用户名,密码]|mirrativ|reality|17live|bilibili|bilibiliwget|bilibiliproxy[,代理ip:代理端口]|bilibiliproxywget[,代理ip:代理端口]|bilibiliproxydlwget[,代理ip:代理端口]|streamlink|m3u8 频道号码 [best|其他清晰度] [loop|once|视频分段时间] [10|循环检测间隔,最短录制间隔] [record_video/other|其他本地目录] [nobackup|rclone:网盘名称:|onedrive|baidupan[重试次数][keep|del]] [noexcept|排除转播的youtube频道号码] [noexcept|排除转播的twitcast频道号码] [noexcept|排除转播的twitch频道号码] [noexcept|排除转播的openrec频道号码] [noexcept|排除转播的nicolv频道号码] [noexcept|排除转播的nicoco频道号码] [noexcept|排除转播的nicoch频道号码] [noexcept|排除转播的mirrativ频道号码] [noexcept|排除转播的reality频道号码] [noexcept|排除转播的17live频道号码] [noexcept|排除转播的streamlink支持的频道网址]`  
### 示例
```
record.sh youtube "UCWCc8tO-uUl_7SJXIKJACMw"   #使用默认参数录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw

record.sh youtubeffmpeg "UCWCc8tO-uUl_7SJXIKJACMw" 1080p,720p,480p,360p,worst once loop 30 "record_video/mea" rclone:vps:baidupan3   #使用ffmpeg录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw，依次获取1080p 720p 480p 360p worst第一个可用的清晰度，在检测到直播并进行一次录制后终止，间隔30秒检测，录像保存于record_video/mea文件夹中，录制完成后自动上传到rclone中名称为vps的网盘和百度云网盘的相同路径并在上传结束后删除本地录像，如果上传失败则会保留本地录像

nohup record.sh bilibiliproxywget,127.0.0.1:1080 "12235923" best 7200 30,5 "record_video/mea_bilibili" rclone:vps:baidupan3keep "UCWCc8tO-uUl_7SJXIKJACMw" "kaguramea" "kagura0mea" "KaguraMea" > mea_bilibili.log &   #后台录制https://www.twitch.tv/kagura0mea，使用代理服务器127.0.0.1:1080获取直播媒体流链接，最高清晰度，循环检测并在录制进行7200秒时分段，间隔30秒检测，录像保存于record_video/mea文件夹中，录制完成后自动上传到rclone中名称为vps的网盘和百度云网盘的相同路径，如果出错则重试三次，上传完成后无论成功与否都保留本地录像，如果距离录制开始不足5秒则等待到5秒再开始下一次检测，log记录保存于mea_bilibili.log文件
 ```
### 参数说明

  * 必选参数，选择录制方式与相应频道号码  

网站|第一个参数|第二个参数|说明|注意事项
:---|:---|:---|:---|:---
youtube|`youtube`、`youtubeffmpeg`|`个人主页网址中的ID部分`(如UCWCc8tO-uUl_7SJXIKJACMw)|youtubeffmpeg为使用ffmpeg进行录制|请不要将第三个清晰都参数指定为best或1080p60及以上的分辨率
twitcast|`twitcast`、`twitcastffmpeg`、`twitcastpy`|`个人主页网址中的ID部分`(如kaguramea_vov)|twitcastffmpeg为使用ffmpeg进行录制，twitcastpy为使用record_twitcast.py进行录制|如果未安装相应依赖，则仅能使用twitcast参数，无法录制twitcast最高清晰度。 __请不要对同一场直播进行多个录制，会导致文件命名问题__
niconico|`nicolv`、`nicoco`、`nicoch`|分别为`niconico生放送号码`(如lv320447549)，`niconico社区号码`(如co41030)，`niconico频道号码`(如macoto2525)|可以在后方添加`:用户名,密码`来登陆nico账号进行录制(如nicolv:user@mail.com,password)|如果未安装相应依赖，则无法录制niconico。 __请不要对同一场直播使用同一账号进行多个录制，会产生websocket链接冲突导致录像卡顿或反复断联__
bilibili|`bilibili`、`bilibiliwget`、`bilibiliproxy`、`bilibiliproxywget`、`bilibiliproxydlwget`|`直播间网址中的ID部分`(如12235923)|bilibiliwget与bilibiliproxywget为使用wget进行录制。bilibiliproxy与bilibiliproxywget为通过代理获取直播媒体流网址，bilibiliproxydlwget为通过代理获取直播媒体流网址并通过代理进行录制，可以直接在后方添加`,代理ip:代理端口`指定代理服务器(如bilibiliproxy,127.0.0.1:1080)，也可以在脚本内相应部分添加代理获取方法
其他网站| `twitch`、`openrec`、`mirrativ`、`reality`、`17live`|`个人主页网址中的ID部分`，其中reality为频道名称(如果为部分名字则匹配含有这些文字的其中一个频道)或vlive_id(获取方法可于脚本内查找)|其中twitch使用streamlink检测直播状态，系统占用较高||
其他|`streamlink`、`m3u8`|`streamlink支持的个人主页网址或直播网址`、`直播媒体流的m3u8网址`||

  * 可选参数

参数|功能|默认值|其他可选值|说明
:---|:---|:---|:---|:---
第三个参数|清晰度|`best`|`清晰度1,清晰度2`，可以用,分隔来指定多个清晰度|仅支持streamlink含有的清晰度，将会依次获取尝试直到获取第一个可用的清晰度
第四个参数|是否循环和录制分段时间|`loop`|`once`或`分段秒数`|如果指定为once则会在检测到直播并进行一次录制后终止，如果指定为数字则会以loop模式进行录制并在在录制进行相应秒数时分段。 __注意分段时可能会导致十秒左右的视频缺失__
第五个参数|循环检测间隔和最短录制间隔|`10`|`循环检测间隔秒数,最短录制间隔秒数`，如果不以,分隔则两者皆为指定值|循环检测间隔是指如果未检测到直播，则等待相应时间进行下一次检测；最短录制间隔是指如果一次录制结束后，如果距离录制开始小于最短录制间隔，则等待到最短录制间隔进行下一次检测。最短录制间隔主要是为了防止检测到直播但录制出错的情况，此时一次录制结束如果立即进行下一次检测可能会因为检测过于频繁导致被封禁IP或者导致高系统占用，这种情况可能出现在网站改版等特殊时期。需要注意的是如果一次直播时间过短或者频繁断流也能触发等待。
第六个参数|本地录像存放目录|`record_video/other`|`本地目录`||
第七个参数|是否自动备份|`nobackup`|`rclone:网盘名称:/onedrive/baidupan` + `重试次数` + `无/keep/del`，不需要/与空格直接连接在一起(如onedrive1del或rclone:vps:baidupan3keep)|其中第一项中的onedrive、baidupan、both分别指上传rclone相应名称的网盘、onedrive一键脚本、百度云。第二项为重试次数，如果不指定则默认为尝试一次。第三项为上传完成后是否保留本地文件，如果不指定则上传成功将删除本地文件，上传失败将保留本地文件，keep参数为不论结果始终保留本地文件，del参数为不论结果始终删除本地文件
第八至十四个参数|bilibili的录制需要排除的转播|`noexcept`|`相应频道号码`，具体同第二个参数，顺序分别为youtube、twitcast、twitch、openrec、nicolv、nicoco、nicoch、mirrativ、reality、17live、streamlink|仅bilibili录制有效，检测到相应频道正在直播时不进行bilibili的录制
