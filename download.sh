#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} [live|video|livevideo] youtube频道号码 [loop|循环次数] [10|循环检测间隔] [3,3,3|录像最大并发数,图片最大并发数,简介最大并发数] [\"download_video/other,download_log/other.txt|本地目录,txt文件路径\"] [nobackup|rclone:网盘名称:|onedrive|baidupan[重试次数]]"
	echo "示例：${0} livevideo \"UCWCc8tO-uUl_7SJXIKJACMw\" loop 15 3,5,5 \"download_video/mea,download_log/mea.txt\" rclone:vps:baidupan3"
	echo "必要模块为curl、youtube-dl"
	echo "rclone上传基于\"https://github.com/rclone/rclone\"，onedrive上传基于\"https://github.com/0oVicero0/OneDrive\"，百度云上传基于BaiduPCS-Go，请登录后使用。"
	echo "注意文件路径不能带有\",\"，注意循环次数过少可能会导致下载与上传不能完成"
fi



LIVE_VIDEO="${1}" #直播或视频
PART_URL="${2}" #youtube频道号码
LOOP_TIME="${3:-loop}" #是否循环或循环次数
LOOPINTERVAL="${4:-10}" #循环检测间隔
NUM_MAX="${5:-3,5,5}" #最大并发数
RECORD_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $1}')" ; THUMBNAIL_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $2}')" ; DESCRIPTION_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $3}')"
[[ "${THUMBNAIL_NUM_MAX}" == "" ]] && THUMBNAIL_NUM_MAX="${RECORD_NUM_MAX}" ; [[ "${DESCRIPTION_NUM_MAX}" == "" ]] && DESCRIPTION_NUM_MAX="${RECORD_NUM_MAX}"
LOCAL_LOG="${6:-download_video/other,download_log/other.txt}" ; DIR_LOCAL="$(echo ${LOCAL_LOG} | awk -F"," '{print $1}')" ; DIR_LOG="$(echo ${LOCAL_LOG} | awk -F"," '{print $2}')" #本地目录,log文件路径
mkdir -p "${DIR_LOCAL}" ; mkdir -p "$(echo ${DIR_LOG} | sed -n "s/\/[^\/]*$//p")" ; touch "${DIR_LOG}"
BACKUP="${7:-nobackup}" #自动备份
BACKUP_DISK="$(echo "${BACKUP}" | awk -F":" '{print $1}')$(echo "${BACKUP}" | awk -F":" '{print $NF}')" ; DIR_RCLONE="$(echo "${BACKUP}" | awk -F":" '{print $2}'):${DIR_LOCAL}" ; DIR_ONEDRIVE="${DIR_LOCAL}" ; DIR_BAIDUPAN="${DIR_LOCAL}" #选择网盘与网盘路径
RETRY_MAX=$(echo "${BACKUP}" | awk -F":" '{print $NF}' | grep -o "[0-9]*") ; [[ ! -n "${RETRY_MAX}" ]] && RETRY_MAX=1 #自动备份重试次数



LOOP=1

while true; do
	echo $LOOP
	#添加列表，for获取LIST不能加引号，awk|while无法修改外部变量
	if (echo "${1}" | grep -q "live"); then
		(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/live" | grep -q '\\"qualityLabel\\":\\"[0-9]*p\\"') && URL_ADD_LIST_LIVE=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/live" | grep -o '\\"liveStreamabilityRenderer\\":{\\"videoId\\":\\".*\\"' | head -n 1 | sed 's/\\//g' | awk -F'"' '{print $6}')
		for URL_ADD in ${URL_ADD_LIST_LIVE}; do 
			URL_LIST=$(awk '{print $1}' "${DIR_LOG}") ; URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++; done
			if [[ "${URL_EXIST}" == 0 ]]; then URL_TIMESTAMP=$(date +%s); echo -e "${URL_ADD}\t${URL_TIMESTAMP}\t直播\t\t\t" >> "${DIR_LOG}"; fi
		done
	fi
	if (echo "${1}" | grep -q "video"); then
		URL_ADD_LIST_VIDEO=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/videos" | grep -o '<a href="/watch?v=[^"]*"' | awk -F'[="]' '{print $4}')
		for URL_ADD in ${URL_ADD_LIST_VIDEO}; do 
			URL_LIST=$(awk '{print $1}' "${DIR_LOG}") ; URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++; done
			if [[ "${URL_EXIST}" == 0 ]]; then URL_TIMESTAMP=$(date +%s); echo -e "${URL_ADD}\t${URL_TIMESTAMP}\t\t\t\t" >> "${DIR_LOG}"; fi
		done
	fi
	
	
	
	awk '{print $0}' "${DIR_LOG}" | while read LINE; do
		#读取
		URL=$(echo "${LINE}" | awk -F'\t' '{print $1}')
		TIMESTAMP=$(echo "${LINE}" | awk -F'\t' '{print $2}')
		STATUS=$(echo "${LINE}" | awk -F'\t' '{print $3}')
		RECORD=$(echo "${LINE}" | awk -F'\t' '{print $4}')
		THUMBNAIL=$(echo "${LINE}" | awk -F'\t' '{print $5}')
		DESCRIPTION=$(echo "${LINE}" | awk -F'\t' '{print $6}')
		echo $URL,$TIMESTAMP,$STATUS,$RECORD,$THUMBNAIL,$DESCRIPTION
		
		
		#不足两小时直播下播后立即录像
		if [[ "${STATUS}" == "直播" ]] && [[ "${RECORD}" == "" ]]; then
			URL_LIVE_STATUS=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep "ytplayer" | grep -0 '\\"isLive\\":true')
			URL_LIVE_DURATION=$(( $(date +%s)-${TIMESTAMP} ))
			[[ "${URL_LIVE_STATUS}" != "" ]] && [[ "${URL_LIVE_DURATION}" -lt 7200 ]] && RECORD=="录像下载待" && RETRY=0
			sed -i "/${URL}/s/录像[^\t]*/${RECORD}/" "${DIR_LOG}"
		fi
		
		#状态
		if [[ "${STATUS}" == "" ]] || [[ "${STATUS}" == "直播" ]] || [[ "${STATUS}" == "压制" ]]; then
			URL_STATUS=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '\\"lengthSeconds\\":\\"[0-9]*' | awk -F'"' '{print $4}' | head -n 1)
			[[ "${URL_STATUS}" == 0 ]] && STATUS="直播"
			[[ "${URL_STATUS}" == 1 ]] && STATUS="压制"
			[[ "${URL_STATUS}" -gt 1 ]] && STATUS="正常"
			[[ "${URL_STATUS}" == "" ]] && STATUS="删除"
			sed -i "/${URL}/s/[^\t]*\t[^\t]*\t[^\t]*/${URL}\t${TIMESTAMP}\t${STATUS}/" "${DIR_LOG}"
		fi
		
		
		
		#录像，""→录像下载待/录像下载中→录像上传待/录像上传中→录像成功/录像失败
		if [[ "${STATUS}" == "正常" ]] && [[ "${RECORD}" == "" ]] || [[ "${RECORD}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.mkv" #注意不相同
			if [[ "${RECORD}" == "" ]]; then
				RECORD_NUM=$(grep -Eo "录像下载待|录像下载中|录像上传待|录像上传中" "${DIR_LOG}" | wc -l)
				[[ ${RECORD_NUM} -lt ${RECORD_NUM_MAX} ]] && RECORD="录像下载待" && sed -i "/${URL}/c ${URL}\t${TIMESTAMP}\t${STATUS}\t${RECORD}\t${THUMBNAIL}\t${DESCRIPTION}" "${DIR_LOG}" #注意相同
			fi
			
			if [[ "${RECORD}" == "录像下载待" ]]; then
				RECORD="录像下载中"
				sed -i "/${URL}/s/录像[^\t]*/${RECORD}/" "${DIR_LOG}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					youtube-dl -q --merge-output-format mkv -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${URL}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && break
					let RETRY++
				done
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					RECORD="录像上传待"
					[[ "${BACKUP}" == "nobackup" ]] && RECORD="录像下载成功"
				else
					RECORD="录像下载失败"
					rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}/s/录像[^\t]*/${RECORD}/" "${DIR_LOG}"
				) &
			fi
			
			if [[ "${RECORD}" == "录像上传待" ]]; then
				RECORD="录像上传中"
				sed -i "/${URL}/s/录像[^\t]*/${RECORD}/" "${DIR_LOG}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && break
						let RCLONE_RETRY++
					done
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && break
						let ONEDRIVE_RETRY++
					done
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && break
						let BAIDUPAN_RETRY++
					done
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					RECORD="录像上传成功"
				else
					RECORD="录像上传失败"
				fi
				rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}/s/录像[^\t]*/${RECORD}/" "${DIR_LOG}"
				)&
			fi
		fi
		
		#图片
		if [[ "${STATUS}" == "正常" ]] && [[ "${THUMBNAIL}" == "" ]] || [[ "${THUMBNAIL}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.jpg"
			if [[ "${THUMBNAIL}" == "" ]]; then
				THUMBNAIL_NUM=$(grep -Eo "图片下载待|图片下载中|图片上传待|图片上传中" "${DIR_LOG}" | wc -l)
				[[ ${THUMBNAIL_NUM} -lt ${THUMBNAIL_NUM_MAX} ]] && THUMBNAIL="图片下载待" && sed -i "/${URL}/c ${URL}\t${TIMESTAMP}\t${STATUS}\t${RECORD}\t${THUMBNAIL}\t${DESCRIPTION}" "${DIR_LOG}"
			fi
			
			if [[ "${THUMBNAIL}" == "图片下载待" ]]; then
				THUMBNAIL="图片下载中"
				sed -i "/${URL}/s/图片[^\t]*/${THUMBNAIL}/" "${DIR_LOG}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					wget -q -O "${DIR_LOCAL}/${FNAME}" "https://i.ytimg.com/vi/${URL}/hqdefault.jpg"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && break
					let RETRY++
				done
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					THUMBNAIL="图片上传待"
					[[ "${BACKUP}" == "nobackup" ]] && THUMBNAIL="图片下载成功"
				else
					THUMBNAIL="图片下载失败"
					rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}/s/图片[^\t]*/${THUMBNAIL}/" "${DIR_LOG}"
				) &
			fi
			
			if [[ "${THUMBNAIL}" == "图片上传待" ]]; then
				THUMBNAIL="图片上传中"
				sed -i "/${URL}/s/图片[^\t]*/${THUMBNAIL}/" "${DIR_LOG}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && break
						let RCLONE_RETRY++
					done
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && break
						let ONEDRIVE_RETRY++
					done
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && break
						let BAIDUPAN_RETRY++
					done
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					THUMBNAIL="图片上传成功"
				else
					THUMBNAIL="图片上传失败"
				fi
				rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}/s/图片[^\t]*/${THUMBNAIL}/" "${DIR_LOG}"
				)&
			fi
		fi
		
		#简介
		if [[ "${STATUS}" == "正常" ]] && [[ "${DESCRIPTION}" == "" ]] || [[ "${DESCRIPTION}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.txt"
			if [[ "${DESCRIPTION}" == "" ]]; then
				DESCRIPTION_NUM=$(grep -Eo "简介下载待|简介下载中|简介上传待|简介上传中" "${DIR_LOG}" | wc -l)
				[[ ${DESCRIPTION_NUM} -lt ${DESCRIPTION_NUM_MAX} ]] && DESCRIPTION="简介下载待" &&	sed -i "/${URL}/c ${URL}\t${TIMESTAMP}\t${STATUS}\t${RECORD}\t${THUMBNAIL}\t${DESCRIPTION}" "${DIR_LOG}"
			fi
			
			if [[ "${DESCRIPTION}" == "简介下载待" ]]; then
				DESCRIPTION="简介下载中"
				sed -i "/${URL}/s/简介[^\t]*/${DESCRIPTION}/" "${DIR_LOG}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '\\"videoTitle\\":\\"[^\\]*' | awk -F'"' '{print $4}' > "${DIR_LOCAL}/${FNAME}"
					wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '<div id="watch-description-text".*</div>' >> "${DIR_LOCAL}/${FNAME}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && break
					let RETRY++
				done
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					DESCRIPTION="简介上传待"
					[[ "${BACKUP}" == "nobackup" ]] && DESCRIPTION="简介下载成功"
				else
					DESCRIPTION="简介下载失败"
					rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}/s/简介[^\t]*/${DESCRIPTION}/" "${DIR_LOG}"
				) &
			fi
			
			if [[ "${DESCRIPTION}" == "简介上传待" ]]; then
				DESCRIPTION="简介上传中"
				sed -i "/${URL}/s/简介[^\t]*/${DESCRIPTION}/" "${DIR_LOG}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && break
						let RCLONE_RETRY++
					done
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && break
						let ONEDRIVE_RETRY++
					done
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && break
						let BAIDUPAN_RETRY++
					done
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					DESCRIPTION="简介上传成功"
				else
					DESCRIPTION="简介上传失败"
				fi
				rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}/s/简介[^\t]*/${DESCRIPTION}/" "${DIR_LOG}"
				)&
			fi
		fi
	done
	
	if [[ "${LOOP_TIME}" != "loop" ]]; then
		[[ "${LOOP}" -gt "${LOOP_TIME}" ]] && break
	fi
	let LOOP++
	sleep ${LOOPINTERVAL}
done
