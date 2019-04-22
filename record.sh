#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} youtube|youtubeffmpeg|twitcast|twitcastffmpeg|twitch|openrec|bilibili|streamlink|m3u8 \"频道号码\" [best|其他清晰度] [loop|once] [10|其他监视间隔] [\"record_video/other|其他本地目录\"] [nobackup|onedrive|baidupan|both] [\"noexcept|排除转播的youtube频道号码]\"]"
	echo "示例：${0} bilibili \"12235923\" best loop 30 \"record_video/mea_bilibili\" both \"UCWCc8tO-uUl_7SJXIKJACMw\""
	echo "仅bilibili支持排除youtube转播，twitcast和m3u8不支持清晰度选择但仍有相应参数，m3u8不支持自动备份但仍有相应参数。"
	echo "所需模块为youtube-dl、streamlink、ffmpeg"
	echo "youtube录制基于youtube-dl，twitcast录制基于livedl，请将livedl文件放置于此用户目录livedl文件夹内。"
	echo "onedrive自动备份基于\"https://github.com/0oVicero0/OneDrive\"，百度云自动备份基于BaiduPCS-Go。"
	exit 1
fi

LIVE_URL="${2}" #频道号码
FORMAT="${3:-best}" #清晰度
LOOP="${4:-loop}" #是否循环
INTERVAL="${5:-10}" #监视间隔
DIR_LOCAL="${6:-record_video/other}" #本地目录
BACKUP="${7:-nobackup}" #自动备份
EXCEPT="${8:-noexcept}" #排除转播的youtube频道号码
DIR_ONEDRIVE=${DIR_LOCAL}
DIR_BAIDUPAN=${DIR_LOCAL}
mkdir -p ${DIR_LOCAL}

if [ "${1}" == "youtube" ]; then
	[[ "LIVE_URL" == "http"* ]] || LIVE_URL="https://www.youtube.com/channel/${LIVE_URL}/live" #补全网址

	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${LIVE_URL}" #检测直播。尝试获取直播流的id和标题，添加参数防止意外下载创建的播放列表
			METADATA=$(youtube-dl --get-id --get-title --get-description --no-playlist --playlist-items 1 --match-filter is_live "${LIVE_URL}" 2>/dev/null)
			[[ -n "${METADATA}" ]] && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} ${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done

		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} start" #开始录制。获取直播流id，使用ts格式防止意外中断损坏文件，使用streamlink来获得HLS支持
		ID=$(echo "${METADATA}" | sed -n '2p') 
		FNAME="youtube_${ID}_$(date +"%Y%m%d_%H%M%S").ts"
		echo "${METADATA}" > "${DIR_LOCAL}/${FNAME}.info.txt"
		streamlink --hls-live-restart --loglevel trace -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${ID}" "${FORMAT}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.info.txt start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.info.txt" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.info.txt start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.info.txt" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.info.txt start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.info.txt" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.info.txt" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi
	
if [ "${1}" == "youtubeffmpeg" ]; then
	[[ "${LIVE_URL}" == "http"* ]] || LIVE_URL="https://www.youtube.com/channel/${LIVE_URL}/live" #补全网址

	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${LIVE_URL}" #检测直播。尝试获取直播流的id和标题，添加参数防止意外下载创建的播放列表
			METADATA=$(youtube-dl --get-id --get-title --get-description --no-playlist --playlist-items 1 --match-filter is_live "${LIVE_URL}" 2>/dev/null)
			[[ -n "${METADATA}" ]] && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} ${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done

		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} start" #开始录制。获取直播流id，使用ts格式防止意外中断损坏文件，使用streamlink来获得HLS支持
		ID=$(echo "${METADATA}" | sed -n '2p') 
		FNAME="youtube_${ID}_$(date +"%Y%m%d_%H%M%S").ts"
		echo "${METADATA}" > "${DIR_LOCAL}/${FNAME}.info.txt"
		ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
			
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.info.txt start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.info.txt" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt" ; \
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.info.txt start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.info.txt" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt" ; \
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.info.txt start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.info.txt" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.info.txt" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.info.txt stopped. remove ${DIR_LOCAL}/${FNAME}.info.txt" ; rm -f "${DIR_LOCAL}/${FNAME}.info.txt") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "twitcast" ]; then
	if [[ ! -f "livedl/livedl" ]]; then
		echo "需要livedl，请将livedl文件放置于此用户目录livedl文件夹内"
		exit 1
	fi

	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata twitcasting.tv/${LIVE_URL}" #检测直播
			STREAM_API="https://twitcasting.tv/streamserver.php?target=${LIVE_URL}&mode=client"
			(curl -s "$STREAM_API" | grep -q '"live":true') && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} twitcasting.tv/${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		DLNAME=$(curl -s "https://twitcasting.tv/streamserver.php?target=${LIVE_URL}&mode=client" | grep -o '"id":[0-9]*,') ; DLNAME="${LIVE_URL}_${DLNAME:5:-1}.ts" ; DLNAME=${DLNAME/:/：}
		FNAME="twitcast_${LIVE_URL}_$(date +"%Y%m%d_%H%M%S").ts"
		echo "${LOG_PREFIX} record twitcasting.tv/${LIVE_URL} start. filename is ${FNAME}" #开始录制。使用ts格式防止意外中断损坏文件，使用livedl才能录制高清版本
		livedl/livedl -tcas "${LIVE_URL}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") #移动livedl录制文件到指定文件夹
		echo "${LOG_PREFIX} remane livedl/${DLNAME} to livedl/${FNAME}. move livedl/${FNAME} to ${DIR_LOCAL}/"
		mv "livedl/${DLNAME}" "${DIR_LOCAL}/${FNAME}"
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record twitcasting.tv/${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "twitcastffmpeg" ]; then
	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata twitcasting.tv/${LIVE_URL}" #检测直播
			STREAM_API="https://twitcasting.tv/streamserver.php?target=${LIVE_URL}&mode=client"
			(curl -s "${STREAM_API}" | grep -q '"live":true') && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} twitcasting.tv/${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record twitcasting.tv/${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件，使用livedl才能录制高清版本
		M3U8_URL="http://twitcasting.tv/${LIVE_URL}/metastream.m3u8?video=1"
		FNAME="twitcast_${LIVE_URL}_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record twitcasting.tv/${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "twitch" ]; then
	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata twitch.tv/${LIVE_URL}" #检测直播
			M3U8_URL=$(streamlink --stream-url "twitch.tv/${LIVE_URL}" "${FORMAT}")
			(echo "$M3U8_URL" | grep -q ".m3u8") && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} twitch.tv/${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "record twitch.tv/${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件
		FNAME="twitch_${LIVE_URL}_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record twitch.tv/${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "openrec" ]; then
	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata openrec.tv/user/${LIVE_URL}" #检测直播
			LIVE_URL=$(curl -s "https://www.openrec.tv/user/${LIVE_URL}" | grep -Eoi "href=\"https://www.openrec.tv/live/(.+)\" class" | head -n 1 | cut -d '"' -f 2)
			[[ -n "${LIVE_URL}" ]] && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} openrec.tv/user/${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "record openrec.tv/user/${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件
		M3U8_URL=$(streamlink --stream-url "${LIVE_URL}" "${FORMAT}")
		FNAME="openrec_${LIVE_URL}_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1

		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record openrec.tv/user/${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "bilibili" ]; then
	[[ "${LIVE_URL}" == "http"* ]] || LIVE_URL="https://live.bilibili.com/${LIVE_URL}" #补全网址
	[[ "${EXCEPT}" == "noexcept" ]] || [[ "${EXCEPT}" == "http"* ]] || EXCEPT="https://www.youtube.com/channel/${EXCEPT}/live"

	while true; do
		while true; do
			if [ "${EXCEPT}" != "noexcept" ]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} metadata ${EXCEPT}" #检测直播。尝试获取直播流的id和标题，添加参数防止意外下载创建的播放列表
				METADATA=$(youtube-dl --get-id --get-title --get-description --no-playlist --playlist-items 1 --match-filter is_live "${EXCEPT}" 2>/dev/null)
				if [[ -n "${METADATA}" ]]; then
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
					echo "${LOG_PREFIX} ${EXCEPT} is restream now. retry after ${INTERVAL} seconds..."
					sleep ${INTERVAL}
					continue
				fi
			fi
		
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${LIVE_URL}" #检测直播
			STREAM_URL=$(streamlink --stream-url "${LIVE_URL}" "${FORMAT}")
			(echo "$STREAM_URL" | grep -q ".m3u8") && break
			(echo "$STREAM_URL" | grep -q ".flv") && break

			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} ${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件
		FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "$STREAM_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "streamlink" ]; then
	while true; do
		while true; do
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} metadata ${LIVE_URL}" #检测直播
			STREAM_URL=$(streamlink --stream-url "${LIVE_URL}" "${FORMAT}")
			(echo "$STREAM_URL" | grep -q ".m3u8") && break
			(echo "$STREAM_URL" | grep -q ".flv") && break
			
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} ${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
			sleep ${INTERVAL}
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件
		FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "$STREAM_URL" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} stopped"
		if [ "${BACKUP}" == "onedrive" ]; then #开始上传onedrive
			(echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "baidupan" ]; then #开始上传baidupan
			(echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log start" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		if [ "${BACKUP}" == "both" ]; then #开始上传both
			(echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME} stopped. remove ${DIR_LOCAL}/${FNAME}" ; rm -f "${DIR_LOCAL}/${FNAME}" ; \
			echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}.log" ; BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}.log" "${DIR_BAIDUPAN}" > /dev/null ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload both ${DIR_LOCAL}/${FNAME}.log stopped. remove ${DIR_LOCAL}/${FNAME}.log" ; rm -f "${DIR_LOCAL}/${FNAME}.log") &
		fi
		[[ "${LOOP}" == "once" ]] && break
	done
fi

if [ "${1}" == "m3u8" ]; then
	while true; do
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} record ${LIVE_URL} start" #开始录制。使用ts格式防止意外中断损坏文件
		FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"
		ffmpeg -i "${LIVE_URL}" -codec copy -f mpegts "${DIR_LOCAL}/${FNAME}" > "${DIR_LOCAL}/${FNAME}.log" 2>&1
		
		[[ "$2" == "once" ]] && break

		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} ${LIVE_URL} is not available now. retry after ${INTERVAL} seconds..."
		sleep ${INTERVAL}
	done
fi
