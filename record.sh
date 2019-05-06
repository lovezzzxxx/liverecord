#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} youtube|youtubeffmmpeg|twitcast|twitcastffmpeg|twitch|openrec|bilibili|streamlink|m3u8 \"频道号码\" [best|其他清晰度] [loop|once|视频分段时间] [10|其他监视间隔] [\"record_video/other|其他本地目录\"] [nobackup|onedrive|baidupan|both|onedrivekeep|baidupankeep|bothkeep|onedrivedel|baidupandel|bothdel] [\"noexcept|排除转播的youtube频道号码\"] [\"noexcept|排除转播的twitcast频道号码\"] [\"noexcept|排除转播的twitch频道号码\"] [\"noexcept|排除转播的openrec频道号码\"] [\"noexcept|排除转播的streamlink支持的频道网址\"]"
	echo "示例：${0} bilibili \"12235923\" best loop 30 3600 \"record_video/mea_bilibili\" both \"UCWCc8tO-uUl_7SJXIKJACMw\" \"kaguramea\" \"kagura0mea\" \"KaguraMea\" "
	echo "仅bilibili支持排除youtube转播，twitcast和m3u8不支持清晰度选择但仍有相应参数，m3u8不支持自动备份但仍有相应参数。"
	echo "所需模块为youtube-dl、streamlink、ffmpeg"
	echo "youtube录制基于youtube-dl，twitcast录制基于livedl，请将livedl文件放置于此用户目录livedl文件夹内。"
	echo "onedrive自动备份基于\"https://github.com/0oVicero0/OneDrive\"，百度云自动备份基于BaiduPCS-Go。"
	exit 1
fi

if [[ "${1}" == "twitcast" ]]; then
	if [[ ! -f "livedl/livedl" ]]; then
		echo "需要livedl，请将livedl文件放置于此用户目录livedl文件夹内"
	fi
fi



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
EXCEPT_STREAM_PART_URL="${12:-noexcept}"

[[ "${1}" == "youtube" || "${1}" == "youtubeffmmpeg" ]] && FULL_URL="https://www.youtube.com/channel/${PART_URL}/live"
[[ "${1}" == "twitcast"  || "${1}" == "twitcastffmpeg" ]] && FULL_URL="https://twitcasting.tv/${PART_URL}"
[[ "${1}" == "twitch" ]] && FULL_URL="https://twitch.tv/${PART_URL}"
[[ "${1}" == "openrec" ]] && FULL_URL="https://openrec.tv/user/${PART_URL}"
[[ "${1}" == "bilibili" ]] && FULL_URL="https://live.bilibili.com/${PART_URL}"
[[ "${1}" == "streamlink" ]] && FULL_URL="${PART_URL}"
[[ "${1}" == "m3u8" ]] && FULL_URL="${PART_URL}"

DIR_ONEDRIVE="${DIR_LOCAL}"
DIR_BAIDUPAN="${DIR_LOCAL}"
mkdir -p "${DIR_LOCAL}"

[[ "${EXCEPT_YOUTUBE_PART_URL}" == "noexcept" ]] || EXCEPT_YOUTUBE_FULL_URL="https://www.youtube.com/channel/${EXCEPT_YOUTUBE_PART_URL}/live"
[[ "${EXCEPT_TWITCAST_PART_URL}" == "noexcept" ]] || EXCEPT_TWITCAST_FULL_URL="https://twitcasting.tv/${EXCEPT_TWITCAST_PART_URL}"
[[ "${EXCEPT_TWITCH_PART_URL}" == "noexcept" ]] || EXCEPT_TWITCH_FULL_URL="https://twitch.tv/${EXCEPT_TWITCH_PART_URL}"
[[ "${EXCEPT_OPENREC_PART_URL}" == "noexcept" ]] || EXCEPT_OPENREC_FULL_URL="https://openrec.tv/user/${EXCEPT_OPENREC_PART_URL}"
[[ "${EXCEPT_STREAM_PART_URL}" == "noexcept" ]] || EXCEPT_OPENREC_FULL_URL="${EXCEPT_STREAM_PART_URL}"



while true; do
	while true; do
		if [[ "${1}" == "youtube" || "${1}" == "youtubeffmmpeg" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}" #检测直播
			METADATA=$(youtube-dl --get-id --get-title --get-description --no-playlist --playlist-items 1 --match-filter is_live "${FULL_URL}" 2>/dev/null)
			[[ -n "${METADATA}" ]] && break
		fi
		if [[ "${1}" == "twitcast" || "${1}" == "twitcastffmpeg" ]]; then
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			(curl -s "https://twitcasting.tv/streamserver.php?target=${PART_URL}&mode=client" | grep -q '"live":true') && break
		fi
		if [[ "${1}" == "twitch" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			STREAM_URL=$(streamlink --stream-url "twitch.tv/${PART_URL}" "${FORMAT}")
			(echo "${STREAM_URL}" | grep -q ".m3u8") && break
		fi
		if [[ "${1}" == "openrec" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			LIVE_URL=$(curl -s "https://www.openrec.tv/user/${PART_URL}" | grep -Eoi "href=\"https://www.openrec.tv/live/(.+)\" class" | head -n 1 | cut -d '"' -f 2)
			[[ -n "${LIVE_URL}" ]] && break
		fi
		
		if [[ "${1}" == "bilibili" ]]; then
			if [[ "${EXCEPT_YOUTUBE_PART_URL}" != "noexcept" ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT_YOUTUBE_FULL_URL}" #检测排除直播
				METADATA=$(youtube-dl --get-id --get-title --get-description --no-playlist --playlist-items 1 --match-filter is_live "${EXCEPT_YOUTUBE_FULL_URL}" 2>/dev/null)
				[[ -n "${METADATA}" ]] && echo "${LOG_PREFIX} ${EXCEPT_YOUTUBE_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
			fi
			if [[ "${EXCEPT_TWITCAST_PART_URL}" != "noexcept" ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT_TWITCAST_FULL_URL}"
				(curl -s "https://twitcasting.tv/streamserver.php?target=${EXCEPT_TWITCAST_PART_URL}&mode=client" | grep -q '"live":true') && echo "${LOG_PREFIX} ${EXCEPT_TWITCAST_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
			fi
			if [[ "${EXCEPT_TWITCH_PART_URL}" != "noexcept" ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT_TWITCH_FULL_URL}"
				STREAM_URL=$(streamlink --stream-url "twitch.tv/${EXCEPT_TWITCH_PART_URL}" "${FORMAT}")
				(echo "${STREAM_URL}" | grep -q ".m3u8") && echo "${LOG_PREFIX} ${EXCEPT_TWITCH_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
			fi
			if [[ "${EXCEPT_OPENREC_PART_URL}" != "noexcept" ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT_OPENREC_FULL_URL}"
				LIVE_URL=$(curl -s "https://www.openrec.tv/user/${EXCEPT_OPENREC_PART_URL}" | grep -Eoi "href=\"https://www.openrec.tv/live/(.+)\" class" | head -n 1 | cut -d '"' -f 2)
				[[ -n "${LIVE_URL}" ]] && echo "${LOG_PREFIX} ${EXCEPT_OPENREC_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
			fi
			if [[ "${EXCEPT_STREAM_PART_URL}" != "noexcept" ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT_STREAM_FULL_URL}"
				STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}")
				(echo "${STREAM_URL}" | grep -q ".m3u8") && echo "${LOG_PREFIX} ${EXCEPT_STREAM_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue
				(echo "${STREAM_URL}" | grep -q ".flv") && echo "${LOG_PREFIX} ${EXCEPT_STREAM_FULL_URL} is restream now. retry after ${INTERVAL} seconds..." && sleep ${INTERVAL} && continue		
			fi
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			(curl -s "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=${PART_URL}&from=room" | grep -q '\"live_status\"\:1') && break
		fi
		
		if [[ "${1}" == "streamlink" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${FULL_URL}"
			STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}")
			(echo "${STREAM_URL}" | grep -q ".m3u8") && break
			(echo "${STREAM_URL}" | grep -q ".flv") && break
		fi
		if [[ "${1}" == "m3u8" ]]; then 
			break
		fi
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} not available retry after ${INTERVAL} seconds..."
		sleep ${INTERVAL}
	done
	
	
	
	if [[ "${1}" == "youtube" ]]; then ID=$(echo "${METADATA}" | sed -n '2p') ; FNAME="youtube_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${ID}.ts" ; echo "${METADATA}" > "${DIR_LOCAL}/${FNAME}.log"; fi
	if [[ "${1}" == "youtubeffmmpeg" ]]; then STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}") ; ID=$(echo "${METADATA}" | sed -n '2p') ; FNAME="youtube_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${ID}.ts" ; echo "${METADATA}" > "${DIR_LOCAL}/${FNAME}.log"; fi
	if [[ "${1}" == "twitcast" ]]; then DLNAME=$(curl -s "https://twitcasting.tv/streamserver.php?target=${PART_URL}&mode=client" | grep -o '"id":[0-9]*,') ; DLNAME="${PART_URL}_${DLNAME:5:-1}.ts" ; DLNAME="${DLNAME/:/：}" ; FNAME="twitcast_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts" ; FNAME="${FNAME/:/：}"; fi
	if [[ "${1}" == "twitcastffmpeg" ]]; then STREAM_URL="http://twitcasting.tv/${PART_URL}/metastream.m3u8?video=1" ; FNAME="twitcast_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "twitch" ]]; then FNAME="twitch_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "openrec" ]]; then STREAM_URL=$(streamlink --stream-url "${LIVE_URL}" "${FORMAT}") ; FNAME="openrec_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "bilibili" ]]; then STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}") ; FNAME="bilibili_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "streamlink" ]]; then FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"; fi
	if [[ "${1}" == "m3u8" ]]; then STREAM_URL="${FULL_URL}" ; FNAME="m3u8_$(date +"%Y%m%d_%H%M%S").ts"; fi
	
	if [[ "${LOOPORTIME}" == "once" || "${LOOPORTIME}" == "loop" ]]; then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record start" #开始录制
		if [[ "${1}" == "youtube" ]]; then
			streamlink --hls-live-restart --loglevel trace -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${ID}" "${FORMAT}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		if [[ "${1}" == "twitcast" ]]; then
			livedl/livedl -tcas "${PART_URL}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		if [[ "${1}" == "youtubeffmmpeg" || "${1}" == "twitcastffmpeg" || "${1}" == "twitch" || "${1}" == "openrec" || "${1}" == "bilibili" || "${1}" == "streamlink" || "${1}" == "m3u8" ]]; then
			ffmpeg -i "${STREAM_URL}" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1
		fi
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record stopped"
		
	else
		if [[ "${1}" == "youtube" ]]; then
			(streamlink --hls-live-restart --loglevel trace -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${ID}" "${FORMAT}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
		fi
		if [[ "${1}" == "twitcast" ]]; then
			(livedl/livedl -tcas "${PART_URL}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
		fi
		if [[ "${1}" == "youtubeffmmpeg" || "${1}" == "twitcastffmpeg" || "${1}" == "twitch" || "${1}" == "openrec" || "${1}" == "bilibili" || "${1}" == "streamlink" || "${1}" == "m3u8" ]]; then
			(ffmpeg -i "${STREAM_URL}" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" >> "${DIR_LOCAL}/${FNAME}.log" 2>&1) &
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
	
	
	
	ERRFLAG_ONEDRIVE=0
	ERRFLAG_BAIDUPAN=0
	if [[ "${BACKUP}" == "onedrive"* ]]; then #上传onedrive
		(LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log start" ; \
		onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? )) ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? )) ; \
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log stopped" ; \
		if [[ ${ERRFLAG_ONEDRIVE} != 0 ]]; then echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log error" ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log error" > "${DIR_LOCAL}/${FNAME}.onedriveerror.log"; fi ; \
		if [[ ${ERRFLAG_ONEDRIVE} == 0 && "${BACKUP}" == "onedrive" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi ; \
		if [[ "${BACKUP}" == "onedrivedel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi) &
	fi
	if [[ "${BACKUP}" == "baidupan"* ]]; then #上传baidupan
		(LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log start" ; \
		BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? )) ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? )) ; \
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log stopped" ; \
		if [[ ${ERRFLAG_BAIDUPAN} != 0 ]]; then echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log error" ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log error" > "${DIR_LOCAL}/${FNAME}.baidupanerror.log"; fi ; \
		if [[ ${ERRFLAG_BAIDUPAN} == 0 && "${BACKUP}" == "baidupan" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi ; \
		if [[ "${BACKUP}" == "baidupandel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi) &
	fi
	if [[ "${BACKUP}" == "both"* ]]; then
		(LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log start" ; \
		onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? )) ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? )) ; \
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log stopped" ; \
		if [[ ${ERRFLAG_ONEDRIVE} != 0 ]]; then echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log error" ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} and log error" > "${DIR_LOCAL}/${FNAME}.onedriveerror.log"; fi ; \
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log start" ; \
		BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? )) ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? )) ; \
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log stopped" ; \
		if [[ ${ERRFLAG_BAIDUPAN} != 0 ]]; then echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log error" ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} and log error" > "${DIR_LOCAL}/${FNAME}.baidupanerror.log"; fi ; \
		if [[ ${ERRFLAG_ONEDRIVE} == 0 && ${ERRFLAG_BAIDUPAN} == 0 && "${BACKUP}" == "both" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi ; \
		if [[ "${BACKUP}" == "bothdel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME} and log" ; rm -f "${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}.log"; fi) &
	fi
	
	
	
	[[ "${LOOP}" == "once" ]] && break
done
