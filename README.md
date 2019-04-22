# liverecord
自动录播脚本，自动备份脚本。  
感谢[live-stream-recorder](https://github.com/printempw/live-stream-recorder)  

# 环境依赖
自动录播需要curl，python3，youtube-dl，streamlink，ffmpeg，livedl。  
其中livedl为可选，目的是支持twitcast高清录制，请将编译完成的livedl文件放置于用户目录的livedl/文件夹内。如果不希望使用livedl可以选择twitcastffmpeg参数而非twitcast参数进行录制。  

onedrive自动备份功能需要[OneDrive for Business on Bash](https://github.com/0oVicero0/OneDrive)，在服务器获取授权后即可使用。  
百度云自动备份功能需要[BaiduPCS-Go](https://github.com/iikira/BaiduPCS-Go)，在服务器登陆后即可使用。如果上传不稳定建议尝试修改设置为使用https方式上传。  

# 自动录播使用方法
自动录播支持youtube频道、twitcast频道、twitch频道、openrec频道、bilibili直播间、其它streamlink支持的直播网址和ffmpeg支持的m3u8地址。方法为间隔固定时间检测频道直播状态。  
可以选择是否自动备份到onedrive或者百度云，即在一次录制完成后自动开始上传，在上传结束后会服务器中的录像将会被删除。__注意即使上传失败服务器中的录像仍会被删除，请确保上传的稳定性后再选择此功能。__自动备份功能不支持m3u8录制。  
bilibili录制支持在一个youtube频道有直播时不进行录制，从而简单的排除转播的录制。排除youtube转播功能仅支持bilibili录制。  

### 方法
```
record.sh youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitch|openrec|bilibili|streamlink|m3u8 "频道号码" [清晰度] [loop|once] [监视间隔] ["录像存放目录"] [nobackup|onedrive|baidupan|both] ["排除转播的youtube频道ID"]
```
### 示例
```
record.sh youtube "UCWCc8tO-uUl_7SJXIKJACMw" #录制https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw

record.sh bilibili "12235923" once loop 30 "record_video/mea_bilibili" both "UCWCc8tO-uUl_7SJXIKJACMw" #录制https://live.bilibili.com/12235923，最高清晰度，在检测到直播并进行一次录制后终止，间隔30秒检测，录像保存于record_video/mea_bilibili文件夹中，录制完成后自动上传到onedrive和百度云相同路径并在上传结束后删除本地录像，在https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw有直播时不进行录制

nohup record.sh twitch "kagura0mea" best loop 30 "record_video/mea" both > mea_twitch.log & #后台录制https://www.twitch.tv/kagura0mea，最高清晰度，循环检测，间隔30秒检测，录像保存于record_video/mea文件夹中，录制完成后自动上传到onedrive和百度云相同路径并在上传完成后删除本地录像，log记录保存于mea_twitch.log文件
 ```
### 参数说明
第一个参数必选，选择录制平台。可选参数为youtube、youtubeffmpeg、twitcast、twitcastffmpeg、twitch、openrec、bilibili、streamlink、m3u8。其中youtubeffmpeg和twitcastffmpeg为使用ffmpeg进行录制。注意twitcastffmpeg无法录制高清流但不需要配置livedl。  
第二个参数必选，选择频道号码。其中youtube、twitcast、twitch、openrec为对应网站个人主页网址中的ID部分，bilibili为直播间号码，streamlink为直播网址，m3u8为直播m3u8文件网址。  

第三个参数可选，选择清晰度，默认为best。  
第四个参数可选，选择是否循环，默认为loop。如果指定为once则会在检测到直播并进行一次录制后终止。  
第五个参数可选，选择监视间隔，默认为10秒。  
第六个参数可选，选择本地录像存放目录，默认为record_video/other文件夹。  
第七个参数可选，选择是否自动备份，默认为nobackup。可选参数为nobackup、onedrive、baidupan、both，其中both指同时上传onedrive和百度云，在一次录制完成后开始上传，上传路径与本地路径相同。自动备份功能不支持m3u8录制。  
第八个参数可选，选择排除转播的youtube频道ID，默认为noexcept。如果参数不为noexcept则作为youtube频道ID，在相应youtube频道有直播时不进行bilibili的录制。排除youtube转播功能仅支持bilibili录制。  

# 自动备份使用方法
自动备份实际是间隔固定时间检测指定文件夹，当文件夹中的文件数量超过指定数量时，按照修改时间将最旧的文件上传到onedrive或者百度云并删除本地文件。__注意即使上传失败服务器中的录像仍会被删除，请确保上传的稳定性后再选择此功能。__  

### 方法
```
autobackup.sh onedrive|baidupan "本地目录" [保留文件数] [loop|once] [监视间隔] ["onedrive或者百度云目录"]
```

### 示例
```
autobackup.sh onedrive "record_video/other" #当record_video/other中的文件数量超过6时将修改时间将最旧的文件上传到onedrive的record_video/other文件夹并删除本地文件，间隔1800秒检测一次
autobackup.sh onedrive "record_video/other" 6 loop 1800 "record_video/other" #同上
nohup autobackup.sh onedrive "record_video/other" 6 loop 1800 "record_video/other" > backup.log & #后台运行
```
### 参数说明
第一个参数必选，选择上传网盘。可选参数为onedrive、baidupan。  
第二个参数必选，选择需要监视的本地目录。  

第三个参数可选，选择保留文件数，默认为6。  
第四个参数可选，选择是否循环，默认为loop。如果指定为once则会在检测一次后终止。  
第五个参数可选，选择监视间隔，默认为1800秒。  
第六个参数可选，选择网盘存放目录，默认为record_video/other文件夹。  
