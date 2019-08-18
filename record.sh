#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitch|openrec|nicolv[:用户名,密码]|nicoco[:用户名,密码]|nicoch[:用户名,密码]|mirrativ|reality|17live|bilibili|streamlink|m3u8 \"频道号码\" [best|其他清晰度] [loop|once|视频分段时间] [10|其他监视间隔] [\"record_video/other|其他本地目录\"] [nobackup|onedrive重试次数|baidupan重试次数|both重试次数|onedrive重试次数keep|baidupan重试次数keep|both重试次数keep|onedrive重试次数del|baidupan重试次数del|both重试次数del] [\"noexcept|排除转播的youtube频道号码\"] [\"noexcept|排除转播的twitcast频道号码\"] [\"noexcept|排除转播的twitch频道号码\"] [\"noexcept|排除转播的openrec频道号码\"] [\"noexcept|排除转播的nicolv频道号码\"] [\"noexcept|排除转播的nicoco频道号码\"] [\"noexcept|排除转播的nicoch频道号码\"] [\"noexcept|排除转播的mirrativ频道号码\"] [\"noexcept|排除转播的reality频道号码\"] [\"noexcept|排除转播的17live频道号码\"] [\"noexcept|排除转播的streamlink支持的频道网址\"]"
	echo "示例：${0} bilibili \"12235923\" best,1080p60,1080p,720p,480p,360p,worst 14400 30 \"record_video/mea_bilibili\" both3keep \"UCWCc8tO-uUl_7SJXIKJACMw\" \"kaguramea\" \"kagura0mea\" \"KaguraMea\" "
	echo "必要模块为curl、streamlink、ffmpeg，可选模块为livedl、请将livedl文件放置于此用户目录livedl文件夹内。"
	echo "onedrive自动备份基于\"https://github.com/0oVicero0/OneDrive\"，百度云自动备份基于BaiduPCS-Go，请登录后使用。"
	echo "注意使用ffmpeg录制youtube直播仅支持1080p以下的清晰度，请不要使用best和1080p60及以上的参数"
	echo "仅bilibili支持排除转播功能"
	exit 1
fi

if [[ "${1}" == "twitcast" || "${1}" == "nicolv"* || "${1}" == "nicoco"* || "${1}" == "nicoch"* ]]; then
	[[ ! -f "livedl/livedl" ]] && echo "需要livedl，请将livedl文件放置于运行时目录的livedl文件夹内"
fi



NICO_ID_PSW=$(echo "${1}" | awk -F":" '{print $2}')
PART_URL="${2}" #频道号码
FORMAT="${3:-best}" #清晰度
LOOPORTIME="${4:-loop}" #是否循环或者视频分段时间
INTERVAL="${5:-10}" #监视间隔
DIR_LOCAL="${6:-record_video/other}" #本地目录
BACKUP="${7:-nobackup}" #自动备份
EXCEPT_YOUTUBE_PART_URL="${8:-noexcept}" #排除转播的频道号码
EXCEPT_TWITCAST_PART_URL="${9:-noexcept}"
EXCEPT_TWITCH_PART_URL="${10:-noexcept}"
EXCEPT_OPENREC_PART_URL="${11:-noexcept}"
EXCEPT_NICOLV_PART_URL="${12:-noexcept}"
EXCEPT_NICOCO_PART_URL="${13:-noexcept}"
EXCEPT_NICOCH_PART_URL="${14:-noexcept}"
EXCEPT_MIRRATIVE_PART_URL="${15:-noexcept}"
EXCEPT_REALITY_PART_URL="${16:-noexcept}"
EXCEPT_17LIVE_PART_URL="${17:-noexcept}"
EXCEPT_STREAM_PART_URL="${18:-noexcept}"

[[ "${1}" == "youtube" || "${1}" == "youtubeffmpeg" ]] && FULL_URL="https://www.youtube.com/channel/${PART_URL}/live"
[[ "${1}" == "twitcast"  || "${1}" == "twitcastffmpeg" ]] && FULL_URL="https://twitcasting.tv/${PART_URL}"
[[ "${1}" == "twitch" ]] && FULL_URL="https://twitch.tv/${PART_URL}"
[[ "${1}" == "openrec" ]] && FULL_URL="https://openrec.tv/user/${PART_URL}"
[[ "${1}" == "nicolv"* ]] && FULL_URL="https://live.nicovideo.jp/gate/${PART_URL}"
[[ "${1}" == "nicoco"* ]] && FULL_URL="https://com.nicovideo.jp/community/${PART_URL}"
[[ "${1}" == "nicoch"* ]] && FULL_URL="https://ch.nicovideo.jp/${PART_URL}/live"
[[ "${1}" == "mirrativ" ]] && FULL_URL="https://www.mirrativ.com/user/${PART_URL}"
[[ "${1}" == "reality" ]] && FULL_URL="reality_${PART_URL}"
[[ "${1}" == "17live" ]] && FULL_URL="https://17.live/live/${PART_URL}"
[[ "${1}" == "bilibili" ]] && FULL_URL="https://live.bilibili.com/${PART_URL}"
[[ "${1}" == "streamlink" ]] && FULL_URL="${PART_URL}"
[[ "${1}" == "m3u8" ]] && FULL_URL="${PART_URL}"

DIR_ONEDRIVE="${DIR_LOCAL}"
DIR_BAIDUPAN="${DIR_LOCAL}"
mkdir -p "${DIR_LOCAL}"
BACKUP_RETRY=$(echo "${BACKUP}" | grep -o "[0-9]*") #自动备份重试次数
[[ ! -n "${BACKUP_RETRY}" ]] && BACKUP_RETRY=1

[[ "${EXCEPT_YOUTUBE_PART_URL}" == "noexcept" ]] || EXCEPT_YOUTUBE_FULL_URL="https://www.youtube.com/channel/${EXCEPT_YOUTUBE_PART_URL}/live"
[[ "${EXCEPT_TWITCAST_PART_URL}" == "noexcept" ]] || EXCEPT_TWITCAST_FULL_URL="https://twitcasting.tv/${EXCEPT_TWITCAST_PART_URL}"
[[ "${EXCEPT_TWITCH_PART_URL}" == "noexcept" ]] || EXCEPT_TWITCH_FULL_URL="https://twitch.tv/${EXCEPT_TWITCH_PART_URL}"
[[ "${EXCEPT_OPENREC_PART_URL}" == "noexcept" ]] || EXCEPT_OPENREC_FULL_URL="https://openrec.tv/user/${EXCEPT_OPENREC_PART_URL}"
[[ "${EXCEPT_NICOLV_PART_URL}" == "noexcept" ]] || EXCEPT_NICOLV_FULL_URL="https://live.nicovideo.jp/gate/${EXCEPT_NICOLV_PART_URL}"
[[ "${EXCEPT_NICOCO_PART_URL}" == "noexcept" ]] || EXCEPT_NICOCO_FULL_URL="https://com.nicovideo.jp/community/${EXCEPT_NICOCO_PART_URL}"
[[ "${EXCEPT_NICOCH_PART_URL}" == "noexcept" ]] || EXCEPT_NICOCH_FULL_URL="https://ch.nicovideo.jp/${EXCEPT_NICOCH_PART_URL}"
[[ "${EXCEPT_MIRRATIV_PART_URL}" == "noexcept" ]] || EXCEPT_MIRRATIV_FULL_URL="https://www.mirrativ.com/user/${EXCEPT_OPENREC_PART_URL}"
[[ "${EXCEPT_REALITY_PART_URL}" == "noexcept" ]] || EXCEPT_REALITY_FULL_URL="reality_${PART_URL}"
[[ "${EXCEPT_17LIVE_PART_URL}" == "noexcept" ]] || EXCEPT_17LIVE_FULL_URL="https://17.live/live/${EXCEPT_17LIVE_PART_URL}"
[[ "${EXCEPT_STREAM_PART_URL}" == "noexcept" ]] || EXCEPT_STREAM_FULL_URL="${EXCEPT_STREAM_PART_URL}"



while true; do
	while true; do
		if [[ "${1}" == "youtube" || "${1}" == "youtubeffmpeg" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			(wget -q -O- "${FULL_URL}" | grep -q '\\"isLive\\":true') && break
		fi
		if [[ "${1}" == "twitcast" || "${1}" == "twitcastffmpeg" ]]; then
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			(wget -q -O- "https://twitcasting.tv/streamserver.php?target=${PART_URL}&mode=client" | grep -q '"live":true') && break
		fi
		if [[ "${1}" == "twitch" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}")
			(echo "${STREAM_URL}" | grep -q ".m3u8") && break
		fi
		if [[ "${1}" == "openrec" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(wget -q -O- "${FULL_URL}" | grep -o 'href="https://www.openrec.tv/live/.*" class' | head -n 1 | awk -F'"' '{print $2}')
			[[ -n "${LIVE_URL}" ]] && break
		fi
		
		if [[ "${1}" == "nicolv"* ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(curl -s -I "https://live.nicovideo.jp/gate/${PART_URL}" | grep -o "https://live2.nicovideo.jp/watch/lv[0-9]*")
			[[ -n "${LIVE_URL}" ]] && break
		fi
		if [[ "${1}" == "nicoco"* ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(wget -q -O- "https://com.nicovideo.jp/community/${PART_URL}" | grep -o '<a class="now_live_inner" href="https://live.nicovideo.jp/watch/lv[0-9]*' | head -n 1 | awk -F'"?' '{print $4}')
			[[ -n "${LIVE_URL}" ]] && break
		fi
		if [[ "${1}" == "nicoch"* ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(wget -q -O- "https://ch.nicovideo.jp/${PART_URL}/live" | awk 'BEGIN{RS="<section class=";FS="\n";ORS="\n";OFS="\t"} $1 ~ /sub now/ {LIVE_POS=match($0,"https://live.nicovideo.jp/watch/lv[0-9]*");LIVE=substr($0,LIVE_POS,RLENGTH);print LIVE}' | head -n 1)
			[[ -n "${LIVE_URL}" ]] && break
			LIVE_ID=$(wget -q -O- "https://ch.nicovideo.jp/${PART_URL}" | grep -o "data-live_id=\"[0-9]*\" data-live_status=\"onair\"" | head -n 1 | awk -F'"' '{print $2}') ; LIVE_URL="https://live.nicovideo.jp/watch/lv${LIVE_ID}"
			[[ -n "${LIVE_ID}" ]] && break
		fi
		
		if [[ "${1}" == "mirrativ" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(wget -q -O- "https://www.mirrativ.com/api/user/profile?user_id=${PART_URL}" | grep -o '"live_id":".*"' | awk -F'"' '{print $4}')
			[[ -n "${LIVE_URL}" ]] && break
		fi
		if [[ "${1}" == "reality" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			STREAM_ID=$(curl -s -X POST "https://media-prod-dot-vlive-prod.appspot.com/api/v1/media/lives_user" | awk -v PART_URL="${PART_URL}" 'BEGIN{RS="\"StreamingServer\"";FS=",";ORS="\n";OFS="\t"} {M3U8_POS=match($0,"\"view_endpoint\":\"[^\"]*\"");M3U8=substr($0,M3U8_POS,RLENGTH) ; ID_POS=match($0,"\"vlive_id\":\"[^\"]*\"");ID=substr($0,ID_POS,RLENGTH) ; if(match($0,"\"nickname\":\"[^\"]*"PART_URL"[^\"]*\"|\"vlive_id\":\""PART_URL"\"")) print M3U8,ID}' | head -n 1)
			[[ -n "${STREAM_ID}" ]] && break
		fi
		if [[ "${1}" == "17live" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_STATUS=$(curl -s -X POST 'http://api-dsa.17app.co/api/v1/liveStreams/getLiveStreamInfo' --data "{\"liveStreamID\": ${PART_URL}}" | grep -o '\\"closeBy\\":\\"\\"')
			[[ -n "${LIVE_STATUS}" ]] && break
		fi
		if [[ "${1}" == "streamlink" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}")
			(echo "${STREAM_URL}" | grep -Eq ".m3u8|.flv|rtmp:") && break
		fi
		
		if [[ "${1}" == "bilibili" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			if (wget -q -O- "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=${PART_URL}" | grep -q '"live_status":1'); then
				if [[ "${EXCEPT_YOUTUBE_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_YOUTUBE_FULL_URL}" #检测排除直播
					(wget -q -O- "${EXCEPT_YOUTUBE_FULL_URL}" | grep -q '\\"isLive\\":true') && echo "${LOG_PREFIX} ${EXCEPT_YOUTUBE_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_TWITCAST_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_TWITCAST_FULL_URL}"
					(wget -q -O- "https://twitcasting.tv/streamserver.php?target=${EXCEPT_TWITCAST_PART_URL}&mode=client" | grep -q '"live":true') && echo "${LOG_PREFIX} ${EXCEPT_TWITCAST_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_TWITCH_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_TWITCH_FULL_URL}"
					EXCEPT_TWITCH_STREAM_URL=$(streamlink --stream-url "${EXCEPT_TWITCH_FULL_URL}" "${FORMAT}")
					(echo "${EXCEPT_TWITCH_STREAM_URL}" | grep -q ".m3u8") && echo "${LOG_PREFIX} ${EXCEPT_TWITCH_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_OPENREC_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_OPENREC_FULL_URL}"
					EXCEPT_OPENREC_LIVE_URL=$(wget -q -O- "${EXCEPT_OPENREC_FULL_URL}" | grep -o 'href="https://www.openrec.tv/live/.*" class' | head -n 1 | awk -F'"' '{print $2}')
					[[ -n "${EXCEPT_OPENREC_LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_OPENREC_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				
				if [[ "${EXCEPT_NICOLV_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_NICOLV_FULL_URL}"
					EXCEPT_NICOLV_LIVE_URL=$(curl -s -I "https://live.nicovideo.jp/gate/${EXCEPT_NICOLV_PART_URL}" | grep -o "https://live2.nicovideo.jp/watch/lv[0-9]*")
					[[ -n "${EXCEPT_NICOLV_LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_NICOLV_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_NICOCO_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_NICOCO_FULL_URL}"
					EXCEPT_NICOCO_LIVE_URL=$(wget -q -O- "https://com.nicovideo.jp/community/${EXCEPT_NICOCO_PART_URL}" | grep -o '<a class="now_live_inner" href="https://live.nicovideo.jp/watch/lv[0-9]*' | head -n 1 | awk -F'"?' '{print $4}')
					[[ -n "${EXCEPT_NICOCO_LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_NICOCO_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_NICOCH_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_NICOCH_FULL_URL}"
					EXCEPT_NICOCH_LIVE_URL=$(wget -q -O- "https://ch.nicovideo.jp/${EXCEPT_NICOCH_PART_URL}/live" | awk 'BEGIN{RS="<section class=";FS="\n";ORS="\n";OFS="\t"} $1 ~ /sub now/ {LIVE_POS=match($0,"https://live.nicovideo.jp/watch/lv[0-9]*");LIVE=substr($0,LIVE_POS,RLENGTH);print LIVE}' | head -n 1)
					[[ -n "${EXCEPT_NICOCH_LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_NICOCH_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
					EXCEPT_NICOCH_LIVE_ID=$(wget -q -O- "https://ch.nicovideo.jp/${EXCEPT_NICOCH_PART_URL}" | grep -o "data-live_id=\"[0-9]*\" data-live_status=\"onair\"" | head -n 1 | awk -F'"' '{print $2}') ; LIVE_URL="https://live.nicovideo.jp/watch/lv${LIVE_ID}"
					[[ -n "${EXCEPT_NICOCH_LIVE_ID}" ]] && echo "${LOG_PREFIX} ${EXCEPT_NICOCH_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				
				if [[ "${EXCEPT_MIRRATIV_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_MIRRATIV_FULL_URL}"
					EXCEPT_MIRRATIV_LIVE_URL=$(wget -q -O- "https://www.mirrativ.com/api/user/profile?user_id=${EXCEPT_MIRRATIV_PART_URL}" | grep -o '"live_id":".*"' | awk -F'"' '{print $4}')
					[[ -n "${EXCEPT_MIRRATIV_LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_MIRRATIV_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_REALITY_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_REALITY_FULL_URL}"
					EXCEPT_REALITY_STREAM_URL=$(curl -s -X POST "https://media-prod-dot-vlive-prod.appspot.com/api/v1/media/lives_user" | awk -v PART_URL="${EXCEPT_REALITY_PART_URL}" 'BEGIN{RS="\"StreamingServer\"";FS=",";ORS="\n";OFS="\t"} {M3U8_POS=match($0,"\"view_endpoint\":\"[^\"]*\"");M3U8=substr($0,M3U8_POS,RLENGTH) ;ID_POS=match($0,"\"vlive_id\":\"[^\"]*\"");ID=substr($0,ID_POS,RLENGTH);if(match($0,"\"nickname\":\"[^\"]*"PART_URL"[^\"]*\"|\"vlive_id\":\""PART_URL"\"")) print M3U8,ID}' | head -n 1)
					[[ -n "${EXCEPT_REALITY_STREAM_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_REALITY_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_17LIVE_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_17LIVE_FULL_URL}"
					EXCEPT_17LIVE_LIVE_STATUS=$(curl -s -X POST 'http://api-dsa.17app.co/api/v1/liveStreams/getLiveStreamInfo' --data "{\"liveStreamID\": ${EXCEPT_17LIVE_PART_URL}}" | grep -o '\\"closeBy\\":\\"\\"')
					[[ -n "${EXCEPT_17LIVE_LIVE_STATUS}" ]] && echo "${LOG_PREFIX} ${EXCEPT_17LIVE_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				if [[ "${EXCEPT_STREAM_PART_URL}" != "noexcept" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} metadata ${EXCEPT_STREAM_FULL_URL}"
					EXCEPT_STREAM_STREAM_URL=$(streamlink --stream-url "${EXCEPT_STREAM_FULL_URL}" "${FORMAT}")
					(echo "${EXCEPT_STREAM_STREAM_URL}" | grep -Eq ".m3u8|.flv|rtmp:") && echo "${LOG_PREFIX} ${EXCEPT_STREAM_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				fi
				break
			fi
		fi
		
		if [[ "${1}" == "m3u8" ]]; then 
			break
		fi
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} not available retry after ${INTERVAL} seconds..."
		sleep ${INTERVAL}
	done
	
	
	
	if [[ "${1}" == "youtube" || "${1}" == "youtubeffmpeg" ]]; then ID=$(wget -q -O- "${FULL_URL}" | grep -o '\\"videoId\\":\\".*\\"' | sed 's/\\//g' | awk -F'"' '{print $4}') ; FNAME="youtube_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${ID}.ts"; fi
	if [[ "${1}" == "youtubeffmpeg" ]]; then STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}"); fi
	if [[ "${1}" == "twitcast" || "${1}" == "twitcastffmpeg" ]]; then ID=$(wget -q -O- "https://twitcasting.tv/streamserver.php?target=${PART_URL}&mode=client" | grep -o '"id":[0-9]*' | awk -F':' '{print $2}') ; DLNAME="${PART_URL/:/：}_${ID}.ts" ; FNAME="twitcast_${PART_URL/:/：}_$(date +"%Y%m%d_%H%M%S")_${ID}.ts"; fi
	if [[ "${1}" == "twitcastffmpeg" ]]; then STREAM_URL="http://twitcasting.tv/${PART_URL}/metastream.m3u8?video=1"; fi
	if [[ "${1}" == "twitch" ]]; then FNAME="twitch_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "openrec" ]]; then STREAM_URL=$(streamlink --stream-url "${LIVE_URL}" "${FORMAT}") ; FNAME="openrec_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "nicolv"* || "${1}" == "nicoco"* || "${1}" == "nicoch"* ]]; then ID=$(echo ${LIVE_URL} | grep -o "lv[0-9]*") ; DLNAME="niconico_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${ID}" ; FNAME="niconico_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${ID}.ts"; fi
	if [[ "${1}" == "mirrativ" ]]; then STREAM_URL=$(wget -q -O- "https://www.mirrativ.com/api/live/live?live_id=${LIVE_URL}" | grep -o '"streaming_url_hls":".*m3u8"' | awk -F'"' '{print $4}') ; FNAME="mirrativ_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "reality" ]]; then ID=$(echo ${STREAM_ID} | awk -F'"' '{print $8}') ; STREAM_URL=$(echo ${STREAM_ID} | awk -F'"' '{print $4}') ; FNAME="reality_${ID}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "17live" ]]; then STREAM_URL=$(curl -s -X POST 'http://api-dsa.17app.co/api/v1/liveStreams/getLiveStreamInfo' --data "{\"liveStreamID\": ${PART_URL}}" | grep -o '\\"webUrl\\":\\"[^\\]*' | awk -F'\"' '{print $4}') ; FNAME="17live_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "bilibili" ]]; then STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}") ; FNAME="bilibili_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "streamlink" ]]; then FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "m3u8" ]]; then STREAM_URL="${FULL_URL}" ; FNAME="m3u8_$(date +"%Y%m%d_%H%M%S").ts"; fi
	
	if [[ "${LOOPORTIME}" == "once" || "${LOOPORTIME}" == "loop" ]]; then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record start" #开始录制
		if [[ "${1}" == "youtube" ]]; then
			streamlink --loglevel trace -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${ID}" "${FORMAT}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		if [[ "${1}" == "twitcast" ]]; then
			livedl/livedl -tcas "${PART_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		if [[ "${1}" == "nicolv"* || "${1}" == "nicoco"* || "${1}" == "nicoch"* ]]; then
			if [[ -n "${NICO_ID_PSW}" ]]; then
				livedl/livedl -nico-login-only=on -nico-login "${NICO_ID_PSW}" -nico-force-reservation=on -nico-limit-bw 0 -nico-format "${DLNAME}" -nico "${LIVE_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
			else
				livedl/livedl -nico-login-only=off -nico-force-reservation=on -nico-limit-bw 0 -nico-format "${DLNAME}" -nico "${LIVE_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
			fi
		fi
		if [[ "${1}" == "youtubeffmpeg" || "${1}" == "twitcastffmpeg" || "${1}" == "twitch" || "${1}" == "openrec" || "${1}" == "mirrativ" || "${1}" == "reality" || "${1}" == "17live" || "${1}" == "bilibili" || "${1}" == "streamlink" || "${1}" == "m3u8" ]]; then
			ffmpeg -i "${STREAM_URL}" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record stopped"
		
	else
		if [[ "${1}" == "youtube" ]]; then
			(streamlink --loglevel trace -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${ID}" "${FORMAT}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
		fi
		if [[ "${1}" == "twitcast" ]]; then
			(livedl/livedl -tcas "${PART_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
		fi
		if [[ "${1}" == "nicolv"* || "${1}" == "nicoco"* || "${1}" == "nicoch"* ]]; then
			if [[ -n "${NICO_ID_PSW}" ]]; then
				(livedl/livedl -nico-login-only=on -nico-login "${NICO_ID_PSW}" -nico-force-reservation=on -nico-limit-bw 0 -nico-format "${DLNAME}" -nico "${LIVE_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
			else
				(livedl/livedl -nico-login-only=off -nico-force-reservation=on -nico-limit-bw 0 -nico-format "${DLNAME}" -nico "${LIVE_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
			fi
		fi
		if [[ "${1}" == "youtubeffmpeg" || "${1}" == "twitcastffmpeg" || "${1}" == "twitch" || "${1}" == "openrec" || "${1}" == "mirrativ" || "${1}" == "reality" || "${1}" == "17live" || "${1}" == "bilibili" || "${1}" == "streamlink" || "${1}" == "m3u8" ]]; then
			(ffmpeg -i "${STREAM_URL}" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
		fi
		
		RECORDPID=$! #录制进程PID
		RECORDSTOPTIME=$(( $(date +%s)+${LOOPORTIME} )) #录制结束时间戳
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record start pid=${RECORDPID} stoptimestamp=${RECORDSTOPTIME}" #开始录制
		while true; do
			sleep 15
			PID_EXIST=$(ps aux | awk '{print $2}'| grep -w ${RECORDPID})
			if [[ ! $PID_EXIST ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} record already stopped"
				break
			else
				if [[ $(date +%s) -gt ${RECORDSTOPTIME} ]]; then #录制时间到达则终止录制
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} time up kill record process ${RECORDPID}"
					kill ${RECORDPID}
					break
				fi
			fi
		done
	fi
	
	
	
	if [[ "${1}" == "twitcast" ]]; then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} remane livedl/${DLNAME} to ${DIR_LOCAL}/${FNAME}"
		mv "livedl/${DLNAME}" "${DIR_LOCAL}/${FNAME}"
	fi
	
	(
	if [[ "${1}" == "nicolv"* || "${1}" == "nicoco"* || "${1}" == "nicoch"* ]]; then
		if [[ -f "livedl/${DLNAME}.sqlite3" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} convert start livedl/${DLNAME}.sqlite3 to livedl/${DLNAME}.ts"
			livedl/livedl -d2m -conv-ext=ts "${DLNAME}.sqlite3" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} convert stopped remove livedl/${DLNAME}.sqlite3 and xml"
			rm "livedl/${DLNAME}.sqlite3" ; rm "livedl/${DLNAME}.xml"
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} remane livedl/${DLNAME}.ts to ${DIR_LOCAL}/${FNAME}"
			mv "livedl/${DLNAME}.ts" "${DIR_LOCAL}/${FNAME}"
		fi
		if [[ -f "livedl/${DLNAME}(TS).sqlite3" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} convert start livedl/${DLNAME}(TS).sqlite3 to livedl/${DLNAME}(TS).ts"
			livedl/livedl -d2m -conv-ext=ts "${DLNAME}(TS).sqlite3" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} convert stopped remove livedl/${DLNAME}(TS).sqlite3 and xml"
			rm "livedl/${DLNAME}(TS).sqlite3" ; rm "livedl/${DLNAME}(TS).xml"
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} remane livedl/${DLNAME}(TS).ts to ${DIR_LOCAL}/${FNAME}"
			mv "livedl/${DLNAME}(TS).ts" "${DIR_LOCAL}/${FNAME}"
		fi
	fi
	
	
	
	if [[ ! -f "${DIR_LOCAL}/${FNAME}" ]]; then #判断是否无录像
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} ${DIR_LOCAL}/${FNAME} file not exist, remove ${DIR_LOCAL}/${FNAME}.log"
		rm -f "${DIR_LOCAL}/${FNAME}.log"
	else
		ONEDRIVE_FILE_RETRY=1
		ONEDRIVE_FILE_ERRFLAG=0
		if [[ "${BACKUP}" == "onedrive"* || "${BACKUP}" == "both"* ]]; then
			until [[ ${ONEDRIVE_FILE_RETRY} -gt ${BACKUP_RETRY} ]]; do
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_FILE_RETRY}"
				onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
				ONEDRIVE_FILE_ERRFLAG=$?
				[[ "${ONEDRIVE_FILE_ERRFLAG}" == 0 ]] && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} success" && break
				let ONEDRIVE_FILE_RETRY++
			done
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			[[ "${ONEDRIVE_FILE_ERRFLAG}" == 0 ]] || echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} fail" && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} fail" > "${DIR_LOCAL}/${FNAME}.onedrivefail.log" && echo "${ONEDRIVE_FILE_ERRFLAG}" >> "${DIR_LOCAL}/${FNAME}.onedrivefail.log"
		fi
		ONEDRIVE_LOG_RETRY=1
		ONEDRIVE_LOG_ERRFLAG=0
		if [[ "${BACKUP}" == "onedrive"* || "${BACKUP}" == "both"* ]]; then
			until [[ ${ONEDRIVE_LOG_RETRY} -gt ${BACKUP_RETRY} ]]; do
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start retry ${ONEDRIVE_LOG_RETRY}"
				onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log"
				ONEDRIVE_LOG_ERRFLAG=$?
				[[ "${ONEDRIVE_LOG_ERRFLAG}" == 0 ]] && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log success" && break
				let ONEDRIVE_LOG_RETRY++
			done
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			[[ "${ONEDRIVE_LOG_ERRFLAG}" == 0 ]] || echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log fail" && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log fail" > "${DIR_LOCAL}/${FNAME}.log.onedrivefail.log" && echo "${ONEDRIVE_LOG_ERRFLAG}" >> "${DIR_LOCAL}/${FNAME}.log.onedrivefail.log"
		fi
		BAIDUPAN_FILE_RETRY=1
		BAIDUPAN_FILE_ERRFLAG="成功"
		if [[ "${BACKUP}" == "baidupan"* || "${BACKUP}" == "both"* ]]; then
			
			until [[ ${BAIDUPAN_FILE_RETRY} -gt ${BACKUP_RETRY} ]]; do
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_FILE_RETRY}"
				BAIDUPAN_FILE_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
				(echo "${BAIDUPAN_FILE_ERRFLAG}" | grep -q "成功") && echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success" && break
				let BAIDUPAN_FILE_RETRY++
			done
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			(echo "${BAIDUPAN_FILE_ERRFLAG}" | grep -q "成功") || echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} fail" && echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} fail" > "${DIR_LOCAL}/${FNAME}.baidupanfail.log" && echo "${BAIDUPAN_FILE_ERRFLAG}" >> "${DIR_LOCAL}/${FNAME}.baidupanfail.log"
		fi
		BAIDUPAN_LOG_RETRY=1
		BAIDUPAN_LOG_ERRFLAG="成功"
		if [[ "${BACKUP}" == "baidupan"* || "${BACKUP}" == "both"* ]]; then
			until [[ ${BAIDUPAN_LOG_RETRY} -gt ${BACKUP_RETRY} ]]; do
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start retry ${BAIDUPAN_LOG_RETRY}"
				BAIDUPAN_LOG_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}")
				(echo "${BAIDUPAN_LOG_ERRFLAG}" | grep -q "成功") && echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log success" && break
				let BAIDUPAN_LOG_RETRY++
			done
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			(echo "${BAIDUPAN_FILE_ERRFLAG}" | grep -q "成功") || echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log fail" && echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log fail" > "${DIR_LOCAL}/${FNAME}.log.baidupanfail.log" && echo "${BAIDUPAN_LOG_ERRFLAG}" >> "${DIR_LOCAL}/${FNAME}.log.baidupanfail.log"
		fi
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") #清除文件
		[[ "${BACKUP}" == *"keep" ]] && (echo "${LOG_PREFIX} force keep ${DIR_LOCAL}/${FNAME}" ; echo "${LOG_PREFIX} force keep ${DIR_LOCAL}/${FNAME}.log")
		[[ "${BACKUP}" == *"del" ]] && (echo "${LOG_PREFIX} force delete ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; echo "${LOG_PREFIX} force delete ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log")
		[[ "${BACKUP}" == "onedrive" || "${BACKUP}" == "baidupan" || "${BACKUP}" == "both" || "${BACKUP}" == *[0-9] ]] && [[ "${ONEDRIVE_FILE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_FILE_ERRFLAG}" | grep -q "成功") && (echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}")
		[[ "${BACKUP}" == "onedrive" || "${BACKUP}" == "baidupan" || "${BACKUP}" == "both" || "${BACKUP}" == *[0-9] ]] && [[ "${ONEDRIVE_LOG_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_LOG_ERRFLAG}" | grep -q "成功") && (echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log")
	fi
	)&
	
	
	
	[[ "${LOOP}" == "once" ]] && break
done
