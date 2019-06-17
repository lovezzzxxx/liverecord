# liverecord
record.sh为主要的自动录播脚本，支持youtube频道、twitcast频道、twitch频道、openrec频道、mirrativ频道、reality频道、niconico生放送、niconico社区、niconico频道、bilibili直播间、其它streamlink支持的直播网址和ffmpeg支持的m3u8地址。其中youtube和twitch未使用api或网页解析的方法检测直播状态，相应频道数量过多会占用更多资源。  
bilibili录制支持在youtube频道、twitcast频道、twitch频道、openrec频道、mirrativ频道、reality频道有直播时不进行录制，从而简单的排除转播的录制。
支持按照录制分段， __注意分段时可能会导致十秒左右的视频缺失__ 。  
支持选择自动备份到onedrive或者百度云。支持选择是否根据上传结果保留本地文件。  
如果因为偶发的检测异常导致没有直播时开始录制，进而产生没有相应录像文件的log文件，脚本将会自动删除这个没有对应录像文件的log文件。

recordcurl.sh主要功能同上，使用简单解析网页的方式完成youtube直播状态检测以减少系统占用（仅提供另一种方式，并非必要）。  
autobackup.sh间隔固定时间检测指定文件夹，当文件夹中的文件数量超过指定数量时，按照修改时间将最旧的文件上传到onedrive或者百度云并删除本地文件（仅提供另一种备份方式，并非必要）。  

感谢[live-stream-recorder](https://github.com/printempw/live-stream-recorder)、[GiGaFotress/Vtuber-recorder](https://github.com/GiGaFotress/Vtuber-recorder)。  

# 环境依赖
自动录播需要curl，[ffmpeg](https://github.com/FFmpeg/FFmpeg)，[streamlink](https://github.com/streamlink/streamlink)(基于python3)，[livedl](https://github.com/himananiito/livedl)(基于go)。  
其中livedl为可选，目的是支持twitcast高清录制和niconico相关的录制， __请将编译完成的livedl文件放置于用户目录的livedl/文件夹内__  。如果不希望使用livedl可以选择twitcastffmpeg参数而非twitcast参数进行twitcast的录制。如果需要niconico会员或者niconico频道会员请在livedl中登录，详见livedl的github页面。  

onedrive自动备份功能需要[OneDrive for Business on Bash](https://github.com/0oVicero0/OneDrive)，在服务器获取授权后即可使用。  
百度云自动备份功能需要[BaiduPCS-Go](https://github.com/iikira/BaiduPCS-Go)，在服务器登陆后即可使用。如果上传不稳定建议尝试修改设置为使用https方式上传。  

# 自动录播使用方法
### 方法
`record.sh youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitch|openrec|mirrativ|reality|nicolv|nicoco|nicoch|bilibili|streamlink|m3u8" "频道号码" [best|其他清晰度] [loop|once|视频分段时间] [10|其他监视间隔] ["record_video/other|其他本地目录"] [nobackup|onedrive|baidupan|both|onedrivekeep|baidupankeep|bothkeep|onedrivedel|baidupandel|bothdel] ["noexcept|排除转播的youtube频道号码"] ["noexcept|排除转播的twitcast频道号码"] ["noexcept|排除转播的twitch频道号码"] ["noexcept|排除转播的openrec频道号码"] ["noexcept|排除转播的streamlink支持的频道网址"]`  
### 示例
```
record.sh youtube "UCWCc8tO-uUl_7SJXIKJACMw"   #录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw

record.sh bilibili "12235923" once loop 30 "record_video/mea_bilibili" both "UCWCc8tO-uUl_7SJXIKJACMw"   #录制https://live.bilibili.com/12235923，最高清晰度，在检测到直播并进行一次录制后终止，间隔30秒检测，录像保存于record_video/mea_bilibili文件夹中，录制完成后自动上传到onedrive和百度云相同路径并在上传结束后删除本地录像，在https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw有直播时不进行录制

nohup record.sh bilibili "12235923" best 7200 30 "record_video/mea_bilibili" bothkeep "UCWCc8tO-uUl_7SJXIKJACMw" "kaguramea" "kagura0mea" "KaguraMea" > mea_bilibili.log &   #后台录制https://www.twitch.tv/kagura0mea，最高清晰度，循环检测并在录制进行7200秒时分段，间隔30秒检测，录像保存于record_video/mea文件夹中，录制完成后自动上传到onedrive和百度云相同路径并在上传完成后保留本地录像，log记录保存于mea_bilibili.log文件
 ```
### 参数说明
第一个参数必选，选择录制平台。可选参数为youtube、youtubeffmpeg、twitcast、twitcastffmpeg、twitch、openrec、mirrativ、reality、nicolv、nicoco、nicoch、bilibili、streamlink、m3u8。其中youtubeffmpeg与twitcastffmpeg为使用ffmpeg进行录制，无法录制高清流但不需要配置livedl。  
第二个参数必选，选择频道号码。其中youtube、twitcast、twitch、openrec、mirrativ为对应网站个人主页网址中的ID部分，reality为频道名称(如果为部分名字则匹配含有该名字的其中一个频道)或vlive_id(获取方法可于脚本内查找)，nicolv为niconico生放送号码(如lv320447549)，nicoco为niconico社区号码(如co41030)，nicoch为niconico频道号码(如macoto2525)，bilibili为直播间号码，streamlink为直播网址，m3u8为直播m3u8文件网址。  

第三个参数可选，选择清晰度，默认为best。  
第四个参数可选，选择是否循环或者录制分段时间，默认为loop。如果指定为once则会在检测到直播并进行一次录制后终止，如果指定为数字则会在录制进行相应秒数时分段，使用视频分段功能时为loop模式。 __注意分段时可能会导致十秒左右的视频缺失__ 。  
第五个参数可选，选择监视间隔，默认为10秒。  
第六个参数可选，选择本地录像存放目录，默认为record_video/other文件夹。  
第七个参数可选，选择是否自动备份，默认为nobackup。可选参数为nobackup、onedrive、baidupan、both、onedrivenot、baidupannot、bothnot、onedrivedel、baidupandel、bothdel。其中onedrive、baidupan、both分别指上传onedrive、上传百度云、同时上传，在一次录制完成后开始上传，上传路径与本地路径相同，如果上传成功则删除本地文件，上传失败将会保留本地文件。带有keep的参数即使上传成功也会保留本地文件。带有del的参数即使上传失败也会删除本地文件。  

第八到十四个参数可选，默认为noexcept。按照顺序分别为选择排除转播的youtube频道号码、排除转播的twitcast频道号码、排除转播的twitch频道号码、noexcept|排除转播的openrec频道号码、排除转播的mirrativ频道号码、排除转播的reality频道号码、排除转播的streamlink支持的频道网址，相应频道正在直播时不进行录制。排除转播功能仅支持bilibili录制。  

# 自动备份使用方法
### 方法
`autobackup.sh onedrive|baidupan|both|onedrivekeep|baidupankeep|bothkeep|onedrivedel|baidupandel|bothdel "本地目录" [保留文件数] [loop|once] [监视间隔] ["onedrive或者百度云目录"]`  
### 示例
```
autobackup.sh onedrive "record_video/other" #当record_video/other中的文件数量超过6时将修改时间将最旧的文件上传到onedrive的record_video/other文件夹并删除本地文件，间隔1800秒检测一次
autobackup.sh onedrive "record_video/other" 6 loop 1800 "record_video/other" #作用同上
nohup autobackup.sh onedrive "record_video/other" 6 loop 1800 "record_video/other" > backup.log & #后台运行，作用同上，log记录保存于backup.log文件
```
### 参数说明
第一个参数必选，选择上传网盘。可选参数为onedrive、baidupan、both、onedrivekeep、baidupankeep、bothkeep、onedrivedel、baidupandel、bothdel。其中onedrive、baidupan、both分别指上传onedrive、上传百度云、同时上传，在一次录制完成后开始上传，上传路径与本地路径相同，如果上传成功则删除本地文件，上传失败将会保留本地文件。带有keep的参数即使上传成功也会保留本地文件。带有del的参数即使上传失败也会删除本地文件。
第二个参数必选，选择需要监视的本地目录。  

第三个参数可选，选择保留文件数，默认为6。  
第四个参数可选，选择是否循环，默认为loop。如果指定为once则会在检测一次后终止。  
第五个参数可选，选择监视间隔，默认为1800秒。  
第六个参数可选，选择网盘存放目录，默认为record_video/other文件夹。  
