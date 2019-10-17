#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} none|live|video|livevideo[fast][触发下播后立即录像的最长直播时间][full] youtube频道号码 [loop|循环次数] [10|循环检测间隔] [3,3,3|录像最大并发数,图片最大并发数,简介最大并发数] [\"download_video/other,download_log/other.txt|本地目录,txt文件路径\"] [nobackup|rclone:网盘名称:|onedrive|baidupan[重试次数]]"
	echo "示例：${0} livevideofastfull \"UCWCc8tO-uUl_7SJXIKJACMw\" loop 15 3,5,5 \"download_video/mea,download_log/mea.txt\" rclone:vps:baidupan3"
	echo "第一个参数说明(其他参数用法基本同record.sh)：live与video为分别从直播和视频页面获取视频列表，设置为none则不更新视频列表，适用于手动提供视频列表的情况。fast为直播下播后立即录像，有机会在删档前开始下载。触发下播后立即录像的最长直播时间设置为7200可以避免下载到未压制完成的视频。full为确保下载到完整视频，防止因下播后立即录像功能导致无法下载到压制完成的视频。"
	echo "必要模块为curl、youtube-dl"
	echo "rclone上传基于\"https://github.com/rclone/rclone\"，onedrive上传基于\"https://github.com/0oVicero0/OneDrive\"，百度云上传基于BaiduPCS-Go，请登录后使用。"
	echo "注意文件路径不能带有\",\"，注意循环次数过少可能会导致下载与上传不能完成"
fi



URL_LIVE_DURATION_MAX=$(echo "${1}" | grep -o "[0-9]*") #触发下播后立即录像的最长直播时间
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
	#添加列表，for获取LIST不能加引号，awk|while无法修改外部变量
	if (echo "${1}" | grep -q "live"); then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} metadata https://www.youtube.com/channel/${PART_URL}/live"
		(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/live" | grep -q '\\"qualityLabel\\":\\"[0-9]*p\\"') && URL_ADD_LIST_LIVE=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/live" | grep -o '\\"liveStreamabilityRenderer\\":{\\"videoId\\":\\".*\\"' | head -n 1 | sed 's/\\//g' | awk -F'"' '{print $6}')
		for URL_ADD in ${URL_ADD_LIST_LIVE}; do 
			URL_LIST=$(awk '{print $1}' "${DIR_LOG}") ; URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++; done
			[[ "${URL_EXIST}" == 0 ]] && URL_TIMESTAMP=$(date +%s) && echo -e "${URL_ADD}\t${URL_TIMESTAMP}\t直播\t\t\t" >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add ${URL_ADD}\t${URL_TIMESTAMP}\t直播\t\t\t"
		done
	fi
	if (echo "${1}" | grep -q "video"); then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} metadata https://www.youtube.com/channel/${PART_URL}/videos"
		URL_ADD_LIST_VIDEO=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/videos" | grep -o '<a href="/watch?v=[^"]*"' | awk -F'[="]' '{print $4}')
		for URL_ADD in ${URL_ADD_LIST_VIDEO}; do 
			URL_LIST=$(awk '{print $1}' "${DIR_LOG}") ; URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++; done
			[[ "${URL_EXIST}" == 0 ]] && URL_TIMESTAMP=$(date +%s) && echo -e "${URL_ADD}\t${URL_TIMESTAMP}\t\t\t\t" >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add ${URL_ADD}\t${URL_TIMESTAMP}\t直播\t\t\t"
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
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} read $URL,$TIMESTAMP,$STATUS,$RECORD,$THUMBNAIL,$DESCRIPTION"
		
		
		
		#状态
		if [[ "${STATUS}" == "" ]] || [[ "${STATUS}" == "直播" ]] || [[ "${STATUS}" == "压制" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} metadata https://www.youtube.com/watch?v=${URL}"
			URL_METADATA=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}")
			
			#fast为直播下播后立即录像，更新本次检测的record状态使之立即开始下载
			if (echo "${1}" | grep -q "fast") && [[ "${STATUS}" == "直播" ]] && [[ "${RECORD}" == "" ]]; then
				URL_LIVE_STATUS=$(echo ${URL_METADATA} | grep "ytplayer" | grep -0 '\\"isLive\\":true')
				URL_LIVE_DURATION=$(( $(date +%s)-${TIMESTAMP} ))
				[[ "${URL_LIVE_STATUS}" == "" ]] && ([[ "${URL_LIVE_DURATION_MAX}" == "" ]] || [[ "${URL_LIVE_DURATION}" -lt "${URL_LIVE_DURATION_MAX}" ]]) && RECORD="录像下载待" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} fast change RECORD=${RECORD}" 
			fi
			
			URL_STATUS=$(echo ${URL_METADATA} | grep -o '\\"lengthSeconds\\":\\"[0-9]*' | awk -F'"' '{print $4}' | head -n 1)
			STATUS_BEDORE="${STATUS}"
			[[ "${URL_STATUS}" == 0 ]] && STATUS="直播"
			[[ "${URL_STATUS}" == 1 ]] && STATUS="压制"
			[[ "${URL_STATUS}" -gt 1 ]] && STATUS="正常"
			[[ "${URL_STATUS}" == "" ]] && STATUS="删除"
			[[ "${STATUS_BEDORE}" != "${STATUS}" ]] && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t${STATUS}\t\4\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change STATUS=${STATUS}"
			
			#full为确保下载到完整视频，在压制转为正常时如果已经开始录像，说明之前下载的为未压制完成的版本，则向列表另外添加timestamp和下载状态不同的新行来在压制完成后新建下载，同时更新本次检测的timestamp和下载状态使之立即开始下载
			(echo "${1}" | grep -q "full") && [[ "${STATUS_BEDORE}" == "压制" ]] && [[ "${STATUS}" == "正常" ]] && [[ "${RECORD}" == "录像"* ]] && TIMESTAMP=$(date +%s) && RECORD="" && THUMBNAIL="" && DESCRIPTION="" && echo -e "${URL}\t${TIMESTAMP}\t${STATUS}\t${RECORD}\t${THUMBNAIL}\t${DESCRIPTION}" >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} full add ${URL}\t${TIMESTAMP}\t${STATUS}\t${RECORD}\t${THUMBNAIL}\t${DESCRIPTION}"
		fi
		
		
		
		#录像，""→录像下载待/录像下载中→录像上传待/录像上传中→录像成功/录像失败
		if ([[ "${STATUS}" == "正常" ]] && [[ "${RECORD}" == "" ]]) || [[ "${RECORD}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.mkv" #注意不相同
			if [[ "${RECORD}" == "" ]]; then
				RECORD_NUM=$(grep -Eo "录像下载待|录像下载中|录像上传待|录像上传中" "${DIR_LOG}" | wc -l)
				[[ ${RECORD_NUM} -lt ${RECORD_NUM_MAX} ]] && RECORD="录像下载待" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change RECORD=${RECORD}"
			fi
			
			if [[ "${RECORD}" == "录像下载待" ]]; then
				RECORD="录像下载中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change RECORD=${RECORD}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} start url=https://www.youtube.com/watch?v=${URL} retry ${RETRY}"
					youtube-dl -q --merge-output-format mkv -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${URL}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} fail")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					RECORD="录像上传待"
					[[ "${BACKUP}" == "nobackup" ]] && RECORD="录像下载成功"
				else
					RECORD="录像下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change RECORD=${RECORD}"
				) &
			fi
			
			if [[ "${RECORD}" == "录像上传待" ]]; then
				RECORD="录像上传中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change RECORD=${RECORD}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					RECORD="录像上传成功"
				else
					RECORD="录像上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t${RECORD}\t\5\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change RECORD=${RECORD}"
				) &
			fi
		fi
		
		#图片
		if ([[ "${STATUS}" != "删除" ]] && [[ "${THUMBNAIL}" == "" ]]) || [[ "${THUMBNAIL}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.jpg"
			if [[ "${THUMBNAIL}" == "" ]]; then
				THUMBNAIL_NUM=$(grep -Eo "图片下载待|图片下载中|图片上传待|图片上传中" "${DIR_LOG}" | wc -l)
				[[ ${THUMBNAIL_NUM} -lt ${THUMBNAIL_NUM_MAX} ]] && THUMBNAIL="图片下载待" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t${THUMBNAIL}\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change THUMBNAIL=${THUMBNAIL}"
			fi
			
			if [[ "${THUMBNAIL}" == "图片下载待" ]]; then
				THUMBNAIL="图片下载中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t${THUMBNAIL}\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change THUMBNAIL=${THUMBNAIL}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} start url=https://i.ytimg.com/vi/${URL}/hqdefault.jpg retry ${RETRY}"
					wget -q -O "${DIR_LOCAL}/${FNAME}" "https://i.ytimg.com/vi/${URL}/hqdefault.jpg"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} success")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					THUMBNAIL="图片上传待"
					[[ "${BACKUP}" == "nobackup" ]] && THUMBNAIL="图片下载成功"
				else
					THUMBNAIL="图片下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t${THUMBNAIL}\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change THUMBNAIL=${THUMBNAIL}"
				) &
			fi
			
			if [[ "${THUMBNAIL}" == "图片上传待" ]]; then
				THUMBNAIL="图片上传中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t${THUMBNAIL}\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change THUMBNAIL=${THUMBNAIL}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					THUMBNAIL="图片上传成功"
				else
					THUMBNAIL="图片上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t${THUMBNAIL}\t\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change THUMBNAIL=${THUMBNAIL}"
				) &
			fi
		fi
		
		#简介
		if ([[ "${STATUS}" != "删除" ]] && [[ "${DESCRIPTION}" == "" ]]) || [[ "${DESCRIPTION}" == *"待" ]]; then
			FNAME="youtube_${PART_URL}_$(date -d @${TIMESTAMP} +"%Y%m%d_%H%M%S")_${URL}.txt"
			if [[ "${DESCRIPTION}" == "" ]]; then
				DESCRIPTION_NUM=$(grep -Eo "简介下载待|简介下载中|简介上传待|简介上传中" "${DIR_LOG}" | wc -l)
				[[ ${DESCRIPTION_NUM} -lt ${DESCRIPTION_NUM_MAX} ]] && DESCRIPTION="简介下载待" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change DESCRIPTION=${DESCRIPTION}"
			fi
			
			if [[ "${DESCRIPTION}" == "简介下载待" ]]; then
				DESCRIPTION="简介下载中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change DESCRIPTION=${DESCRIPTION}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} start url=https://www.youtube.com/watch?v=${URL} retry ${RETRY}"
					wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '\\"videoTitle\\":\\"[^\\]*' | awk -F'"' '{print $4}' > "${DIR_LOCAL}/${FNAME}"
					wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '<div id="watch-description-text".*</div>' >> "${DIR_LOCAL}/${FNAME}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} download ${DIR_LOCAL}/${FNAME} success")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					DESCRIPTION="简介上传待"
					[[ "${BACKUP}" == "nobackup" ]] && DESCRIPTION="简介下载成功"
				else
					DESCRIPTION="简介下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change DESCRIPTION=${DESCRIPTION}"
				) &
			fi
			
			if [[ "${DESCRIPTION}" == "简介上传待" ]]; then
				DESCRIPTION="简介上传中" && sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change DESCRIPTION=${DESCRIPTION}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}")
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					DESCRIPTION="简介上传成功"
				else
					DESCRIPTION="简介上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} change DESCRIPTION=${DESCRIPTION}"
				) &
			fi
		fi
		#sed -i "/${URL}\t${TIMESTAMP}/s/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/\1\t\2\t\3\t\4\t\5\t\6/" "${DIR_LOG}"
	done
	
	if [[ "${LOOP_TIME}" != "loop" ]]; then
		[[ "${LOOP}" -gt "${LOOP_TIME}" ]] && break
		let LOOP++
	fi
	LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} detect loop end retry after ${LOOPINTERVAL} seconds..."
	sleep ${LOOPINTERVAL}
done
