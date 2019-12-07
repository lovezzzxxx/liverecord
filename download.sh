#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} none|live|video|long[fast][触发下播后立即录像的最长直播时间][full] youtube频道号码 [loop|循环次数] [10,50|循环检测间隔,视频列表最大长度] [3,3,3|录像最大并发数,图片最大并发数,简介最大并发数] [\"download_video/other,download_log/other.log|本地目录,视频列表文件路径\"] [nobackup|rclone:网盘名称:|onedrive|baidupan[重试次数]]"
	echo "示例：${0} livevideofastfull \"UCWCc8tO-uUl_7SJXIKJACMw\" loop 10,50 3,3,3 \"download_video/mea,download_log/mea.log\" rclone:vps:3"
	echo "第一个参数说明(其他参数用法基本同record.sh)：live、video、long分别为从直播、视频页面(前30个视频)、上传视频列表页面(前100个视频)获取视频列表(请务必将视频列表最大长度设置为更大的值)，设置为none则不更新视频列表，适用于手动提供视频列表的情况。fast为直播下播后立即录像，有机会在删档前开始下载。触发下播后立即录像的最长直播时间设置为7200可以避免下载到未压制完成的视频。full为确保下载到完整视频，防止因下播后立即录像功能导致无法下载到压制完成的视频。"
	echo "必要模块为curl、youtube-dl、ffmpeg"
	echo "rclone上传基于\"https://github.com/rclone/rclone\"，onedrive上传基于\"https://github.com/0oVicero0/OneDrive\"，百度云上传基于BaiduPCS-Go，请登录后使用。"
	echo "注意文件路径不能带有\",\"，注意循环次数过少可能会导致下载与上传不能完成"
	exit 1
fi



URL_LIVE_DURATION_MAX=$(echo "${1}" | grep -o "[0-9]*") #触发下播后立即录像的最长直播时间
PART_URL="${2}" #youtube频道号码
LOOP_TIME="${3:-loop}" #是否循环或循环次数
LOOPINTERVAL_LINEMAX="${4:-10,50}" ; LOOPINTERVAL="$(echo $LOOPINTERVAL_LINEMAX | awk -F"," '{print $1}')" ; LINEMAX="$(echo $LOOPINTERVAL_LINEMAX | awk -F"," '{print $2}')" #循环检测间隔与视频列表最大长度
NUM_MAX="${5:-3,3,3}" #最大并发数
RECORD_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $1}')" ; THUMBNAIL_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $2}')" ; DESCRIPTION_NUM_MAX="$(echo $NUM_MAX | awk -F"," '{print $3}')"
[[ "${THUMBNAIL_NUM_MAX}" == "" ]] && THUMBNAIL_NUM_MAX="${RECORD_NUM_MAX}" ; [[ "${DESCRIPTION_NUM_MAX}" == "" ]] && DESCRIPTION_NUM_MAX="${RECORD_NUM_MAX}"
LOCAL_LOG="${6:-download_video/other,download_log/other.log}" ; DIR_LOCAL="$(echo ${LOCAL_LOG} | awk -F"," '{print $1}')" ; DIR_LOG="$(echo ${LOCAL_LOG} | awk -F"," '{print $2}')" #本地目录,log文件路径
mkdir -p "${DIR_LOCAL}" ; mkdir -p "$(echo ${DIR_LOG} | sed -n "s/\/[^\/]*$//p")" ; touch "${DIR_LOG}"
BACKUP="${7:-nobackup}" #自动备份
BACKUP_DISK="$(echo "${BACKUP}" | awk -F":" '{print $1}')$(echo "${BACKUP}" | awk -F":" '{print $NF}')" ; DIR_RCLONE="$(echo "${BACKUP}" | awk -F":" '{print $2}'):${DIR_LOCAL}" ; DIR_ONEDRIVE="${DIR_LOCAL}" ; DIR_BAIDUPAN="${DIR_LOCAL}" #选择网盘与网盘路径
RETRY_MAX=$(echo "${BACKUP}" | awk -F":" '{print $NF}' | grep -o "[0-9]*") ; [[ ! -n "${RETRY_MAX}" ]] && RETRY_MAX=1 #自动备份重试次数



LOOP=1

while true; do
	#添加末尾换行符，清理多余行
	ADD_ENTER=$(tail -n 1 "${DIR_LOG}" | wc -l)
	[[ "${ADD_ENTER}" == 0 ]] && echo >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add enter"
	LINETOTAL=$(cat "${DIR_LOG}" | wc -l)
	[[ "${LINEMAX}" != "" ]] && [[ ${LINETOTAL} -gt ${LINEMAX} ]] && LINEDEL=$(( ${LINETOTAL}-${LINEMAX} )) && sed -i '1,'"${LINEDEL}"'d' "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} delete first ${LINEDEL} line"
	
	#添加列表，for获取LIST不能加引号，awk|while无法修改外部变量
	if (echo "${1}" | grep -q "live"); then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} metadata https://www.youtube.com/channel/${PART_URL}/live"
		URL_ADD_LIST_LIVE_METADATA=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/live")
		if (echo "${URL_ADD_LIST_LIVE_METADATA}" | grep -q '\\"qualityLabel\\":\\"[0-9]*p\\"'); then
			URL_ADD_LIVE_URL=$(echo "${URL_ADD_LIST_LIVE_METADATA}" | grep -o '\\"liveStreamabilityRenderer\\":{\\"videoId\\":\\".*\\"' | head -n 1 | sed 's/\\//g' | awk -F'"' '{print $6}')
			URL_ADD_LIVE_TIMESTAMP=$(echo "${URL_ADD_LIST_LIVE_METADATA}" | grep -o '\\"publishDate\\":\\"[^"]*\\"\|\\"startTimestamp\\":\\"[^"]*\\' | awk -F'"' '{print $4}' | sed -n 's/\\//p' | tail -n 1)
			[[ "${URL_ADD_LIVE_TIMESTAMP}" == "" ]] || [[ "${URL_ADD_LIVE_TIMESTAMP}" == "1969-12-31" ]] && URL_ADD_LIVE_DATE=$(date -Iseconds) ; [[ "${URL_ADD_LIVE_TIMESTAMP}" != "" ]] && [[ "${URL_ADD_LIVE_TIMESTAMP}" != "1969-12-31" ]] && URL_ADD_LIVE_DATE=$(date -d "${URL_ADD_LIVE_TIMESTAMP}" -Iseconds)
			
			URL_LIST=$(awk -F"," '{print $1}' "${DIR_LOG}") ; URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD_LIVE_URL}" == "${URL}" ]] && let URL_EXIST++ ; done
			[[ "${URL_EXIST}" == 0 ]] && echo -e "${URL_ADD_LIVE_URL},${URL_ADD_LIVE_DATE},直播,,," >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add live ${URL_ADD_LIVE_URL},${URL_ADD_LIVE_DATE},直播,,,"
		fi
	fi
	if (echo "${1}" | grep -q "video"); then
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} metadata https://www.youtube.com/channel/${PART_URL}/videos"
		URL_ADD_VIDEO_LIST=$(wget -q -O- "https://www.youtube.com/channel/${PART_URL}/videos" | grep -o '<a href="/watch?v=[^"]*"' | awk -F'[="]' '{print $4}')
		
		URL_LIST=$(awk -F"," '{print $1}' "${DIR_LOG}")
		for URL_ADD in ${URL_ADD_VIDEO_LIST}; do 
			URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++ ; done
			[[ "${URL_EXIST}" == 0 ]] && echo -e "${URL_ADD},,,,," >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add video ${URL_ADD},,,,,"
		done
	fi
	if (echo "${1}" | grep -q "long"); then
		URL_ADD_VIDEO_LIST_LONG=$(wget -q -O- "https://www.youtube.com/playlist?list=${PART_URL/UC/UU}" | grep -o '<a href="/watch?v=[^"]*"' | awk -F'[="&]' '{print $4}')
			
		URL_LIST=$(awk -F"," '{print $1}' "${DIR_LOG}")
		for URL_ADD in ${URL_ADD_VIDEO_LIST_LONG}; do 
			URL_EXIST=0
			for URL in ${URL_LIST}; do [[ "${URL_ADD}" == "${URL}" ]] && let URL_EXIST++ ; done
			[[ "${URL_EXIST}" == 0 ]] && echo -e "${URL_ADD},,,,," >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} add long ${URL_ADD},,,,,"
		done
	fi
	
	
	
	awk '{print $0}' "${DIR_LOG}" | while read LINE; do
		#读取
		URL=$(echo "${LINE}" | awk -F',' '{print $1}')
		DATE=$(echo "${LINE}" | awk -F',' '{print $2}')
		STATUS=$(echo "${LINE}" | awk -F',' '{print $3}')
		RECORD=$(echo "${LINE}" | awk -F',' '{print $4}')
		THUMBNAIL=$(echo "${LINE}" | awk -F',' '{print $5}')
		DESCRIPTION=$(echo "${LINE}" | awk -F',' '{print $6}')
		#LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} read ${LINE}"
		
		#格式化
		[[ "${URL}" == "" ]] && continue
		SPLIT_NUM=$(echo $LINE | awk '{print gsub(",",",",$0)}')
		[[ "${SPLIT_NUM}" == 0 ]] && sed -i "/^${URL}$/c ${URL},,,,," "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} fix ${URL},,,,," 
		[[ "${SPLIT_NUM}" != 0 ]] && [[ "${SPLIT_NUM}" != 5 ]] && sed -i "/${URL},${DATE}/c ${URL},${DATE},,,," "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} fix ${URL},${DATE},,,," 
		if [[ "${DATE}" == "" ]]; then
			TIMESTAMP=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}" | grep -o '\\"publishDate\\":\\"[^"]*\\"\|\\"startTimestamp\\":\\"[^"]*\\' | awk -F'"' '{print $4}' | sed -n 's/\\//p' | tail -n 1)
			[[ "${TIMESTAMP}" == "" ]] || [[ "${TIMESTAMP}" == "1969-12-31" ]] && DATE=$(date -Iseconds) ; [[ "${TIMESTAMP}" != "" ]] && [[ "${TIMESTAMP}" != "1969-12-31" ]] && DATE=$(date -d "${TIMESTAMP}" -Iseconds)
			sed -i "/${URL},,/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,${DATE},\3,\4,\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} fix DATE=${DATE}"
		fi
		
		
		
		#状态
		#live:即将直播(qualityLabel-,isLive-,videoIsLivePremiere-,lengthSeconds=0)，直播(qualityLabel+,isLive+,videoIsLivePremiere-,lengthSeconds=0)，停止直播(qualityLabel-,isLive-,videoIsLivePremiere-,lengthSeconds=0)
		#videos:即将首播(qualityLabel-,isLive-,videoIsLivePremiere+,lengthSeconds=0)，首播(qualityLabel+,isLive+,videoIsLivePremiere+,lengthSeconds>1)，停止首播(qualityLabel+,isLive-,videoIsLivePremiere+,lengthSeconds>1)，压制(qualityLabel+,isLive-,videoIsLivePremiere-,lengthSeconds=1)，正常(qualityLabel+,isLive-,videoIsLivePremiere-,lengthSeconds>1)
		#playlist:正常(qualityLabel+,isLive-,lengthSeconds>1)
		#other:删除("")
		if [[ "${STATUS}" == "" ]] || [[ "${STATUS}" == "直播" ]] || [[ "${STATUS}" == "首播" ]] || [[ "${STATUS}" == "压制" ]]; then
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} metadata https://www.youtube.com/watch?v=${URL}"
			URL_METADATA=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}")
			
			URL_STATUS_LIVE=$(echo ${URL_METADATA} | grep "ytplayer" | grep -o '\\"isLive\\":true')
			URL_STATUS_PREMIERE=$(echo ${URL_METADATA} | grep -o '\\"videoIsLivePremiere\\":true')
			URL_STATUS_LENGTH=$(echo ${URL_METADATA} | grep -o '\\"lengthSeconds\\":\\"[0-9]*' | awk -F'"' '{print $4}' | head -n 1)
			STATUS_BEDORE="${STATUS}"
			
			[[ "${URL_STATUS_PREMIERE}" == "" ]] && [[ "${URL_STATUS_LENGTH}" == 0 ]] && STATUS="直播"
			[[ "${URL_STATUS_LENGTH}" == 1 ]] && STATUS="压制"
			[[ "${URL_STATUS_PREMIERE}" == "" ]] && [[ "${URL_STATUS_LENGTH}" -gt 1 ]] && STATUS="正常"
			
			[[ "${URL_STATUS_PREMIERE}" != "" ]] && [[ "${URL_STATUS_LENGTH}" == 0 ]] && STATUS="首播"
			[[ "${URL_STATUS_PREMIERE}" != "" ]] && [[ "${URL_STATUS_LIVE}" != "" ]] && [[ "${URL_STATUS_LENGTH}" -gt 1 ]] && STATUS="首播"
			[[ "${URL_STATUS_PREMIERE}" != "" ]] && [[ "${URL_STATUS_LIVE}" == "" ]] && [[ "${URL_STATUS_LENGTH}" -gt 1 ]] && STATUS="正常"
			
			[[ "${URL_STATUS_LENGTH}" == "" ]] && STATUS="删除"
			
			[[ "${STATUS_BEDORE}" != "${STATUS}" ]] && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,${STATUS},\4,\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change STATUS=${STATUS}"
			
			#fast为直播下播后立即录像，更新本次检测的record状态使之立即开始下载
			if (echo "${1}" | grep -q "fast") && [[ "${STATUS_BEDORE}" == "直播" ]] && ([[ "${STATUS}" != "直播" ]] || [[ "${URL_STATUS_LIVE}" == "" ]]) && [[ "${RECORD}" == "" ]]; then
				URL_LIVE_DURATION=$(( $(date +%s)-$(date -d "${DATE}" +%s) ))
				([[ "${URL_LIVE_DURATION_MAX}" == "" ]] || [[ "${URL_LIVE_DURATION}" -lt "${URL_LIVE_DURATION_MAX}" ]]) && RECORD="录像下载待" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} fast change RECORD=${RECORD}" 
			fi
			#full为确保下载到完整视频，在压制转为正常时如果已经开始录像，说明之前下载的为未压制完成的版本，则向列表另外添加timestamp和下载状态不同的新行来在压制完成后新建下载，同时更新本次检测的timestamp和下载状态使之立即开始下载
			if (echo "${1}" | grep -q "full") && [[ "${STATUS_BEDORE}" == "压制" ]] && [[ "${STATUS}" == "正常" ]] && [[ "${RECORD}" == "录像"* ]]; then
				DATE=$(date -Iseconds) && RECORD="" && THUMBNAIL="" && DESCRIPTION="" && echo -e "${URL},${DATE},${STATUS},${RECORD},${THUMBNAIL},${DESCRIPTION}" >> "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo -e "${LOG_PREFIX} ${LINE} full add ${URL},${DATE},${STATUS},${RECORD},${THUMBNAIL},${DESCRIPTION}"
			fi
		fi
		
		
		
		#录像，""→录像下载待/录像下载中→录像上传待/录像上传中→录像成功/录像失败
		if ([[ "${STATUS}" == "正常" ]] && [[ "${RECORD}" == "" ]]) || [[ "${RECORD}" == *"待" ]]; then
			FNAME_DATE=$(date -d "${DATE}" +"%Y%m%d_%H%M%S")
			FNAME="youtube_${PART_URL}_${FNAME_DATE}_${URL}.mkv" #注意不相同
			if [[ "${RECORD}" == "" ]]; then
				RECORD_NUM=$(grep -Eo "录像下载待|录像下载中|录像上传待|录像上传中" "${DIR_LOG}" | wc -l)
				[[ ${RECORD_NUM} -lt ${RECORD_NUM_MAX} ]] && RECORD="录像下载待" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change RECORD=${RECORD}"
			fi
			
			if [[ "${RECORD}" == "录像下载待" ]]; then
				RECORD="录像下载中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change RECORD=${RECORD}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} start url=https://www.youtube.com/watch?v=${URL} retry ${RETRY}"
					youtube-dl -q --merge-output-format mkv -o "${DIR_LOCAL}/${FNAME}" "https://www.youtube.com/watch?v=${URL}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} fail")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					RECORD="录像上传待"
					[[ "${BACKUP}" == "nobackup" ]] && RECORD="录像下载成功"
				else
					RECORD="录像下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change RECORD=${RECORD}"
				) &
			fi
			
			if [[ "${RECORD}" == "录像上传待" ]]; then
				RECORD="录像上传中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change RECORD=${RECORD}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}" 2>&1)
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					RECORD="录像上传成功"
				else
					RECORD="录像上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,${RECORD},\5,\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change RECORD=${RECORD}"
				) &
			fi
		fi
		
		#图片
		if ([[ "${STATUS}" != "删除" ]] && [[ "${THUMBNAIL}" == "" ]]) || [[ "${THUMBNAIL}" == *"待" ]]; then
			FNAME_DATE=$(date -d "${DATE}" +"%Y%m%d_%H%M%S")
			FNAME="youtube_${PART_URL}_${FNAME_DATE}_${URL}.jpg"
			if [[ "${THUMBNAIL}" == "" ]]; then
				THUMBNAIL_NUM=$(grep -Eo "图片下载待|图片下载中|图片上传待|图片上传中" "${DIR_LOG}" | wc -l)
				[[ ${THUMBNAIL_NUM} -lt ${THUMBNAIL_NUM_MAX} ]] && THUMBNAIL="图片下载待" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,${THUMBNAIL},\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change THUMBNAIL=${THUMBNAIL}"
			fi
			
			if [[ "${THUMBNAIL}" == "图片下载待" ]]; then
				THUMBNAIL="图片下载中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,${THUMBNAIL},\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change THUMBNAIL=${THUMBNAIL}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} start url=https://i.ytimg.com/vi/${URL}/hqdefault.jpg retry ${RETRY}"
					THUMBNAIL_ERRORFLAG=$(wget -o- -O "${DIR_LOCAL}/${FNAME}" "https://i.ytimg.com/vi/${URL}/maxresdefault.jpg")
					(echo "${THUMBNAIL_ERRORFLAG}" | grep -q "ERROR") && wget -q -O "${DIR_LOCAL}/${FNAME}" "https://i.ytimg.com/vi/${URL}/hqdefault.jpg"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} success")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					THUMBNAIL="图片上传待"
					[[ "${BACKUP}" == "nobackup" ]] && THUMBNAIL="图片下载成功"
				else
					THUMBNAIL="图片下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,${THUMBNAIL},\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change THUMBNAIL=${THUMBNAIL}"
				) &
			fi
			
			if [[ "${THUMBNAIL}" == "图片上传待" ]]; then
				THUMBNAIL="图片上传中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,${THUMBNAIL},\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change THUMBNAIL=${THUMBNAIL}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}" 2>&1)
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					THUMBNAIL="图片上传成功"
				else
					THUMBNAIL="图片上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,${THUMBNAIL},\6/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change THUMBNAIL=${THUMBNAIL}"
				) &
			fi
		fi
		
		#简介
		if ([[ "${STATUS}" != "删除" ]] && [[ "${DESCRIPTION}" == "" ]]) || [[ "${DESCRIPTION}" == *"待" ]]; then
			FNAME_DATE=$(date -d "${DATE}" +"%Y%m%d_%H%M%S")
			FNAME="youtube_${PART_URL}_${FNAME_DATE}_${URL}.txt"
			if [[ "${DESCRIPTION}" == "" ]]; then
				DESCRIPTION_NUM=$(grep -Eo "简介下载待|简介下载中|简介上传待|简介上传中" "${DIR_LOG}" | wc -l)
				[[ ${DESCRIPTION_NUM} -lt ${DESCRIPTION_NUM_MAX} ]] && DESCRIPTION="简介下载待" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change DESCRIPTION=${DESCRIPTION}"
			fi
			
			if [[ "${DESCRIPTION}" == "简介下载待" ]]; then
				DESCRIPTION="简介下载中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change DESCRIPTION=${DESCRIPTION}"
				(
				RETRY=1
				until [[ ${RETRY} -gt ${RETRY_MAX} ]]; do
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} start url=https://www.youtube.com/watch?v=${URL} retry ${RETRY}"
					URL_DESCRIPTION=$(wget -q -O- "https://www.youtube.com/watch?v=${URL}")
					URL_DESCRIPTION_STARTTIMESTAMP=$(echo "${URL_DESCRIPTION}" | grep -o '\\"publishDate\\":\\"[^"]*\\"\|\\"startTimestamp\\":\\"[^"]*\\' | awk -F'"' '{print $4}' | sed -n 's/\\//p' | tail -n 1)
					[[ "${URL_DESCRIPTION_STARTTIMESTAMP}" == "" ]] && URL_DESCRIPTION_STARTDATE=0 ; [[ "${URL_DESCRIPTION_STARTTIMESTAMP}" != "" ]] && URL_DESCRIPTION_STARTDATE=$(date -d "${URL_DESCRIPTION_STARTTIMESTAMP}" +"%Y%m%d_%H%M%S")
					URL_DESCRIPTION_ENDTIMESTAMP=$(echo "${URL_DESCRIPTION}" | grep -o '\\"publishDate\\":\\"[^"]*\\"\|\\"endTimestamp\\":\\"[^"]*\\' | awk -F'"' '{print $4}' | sed -n 's/\\//p' | tail -n 1)
					[[ "${URL_DESCRIPTION_ENDTIMESTAMP}" == "" ]] && URL_DESCRIPTION_ENDDATE=0 ; [[ "${URL_DESCRIPTION_ENDTIMESTAMP}" != "" ]] && URL_DESCRIPTION_ENDDATE=$(date -d "${URL_DESCRIPTION_ENDTIMESTAMP}" +"%Y%m%d_%H%M%S")
					URL_DESCRIPTION_TITLE=$(echo "${URL_DESCRIPTION}" | grep -o '\\"videoTitle\\":\\"[^\\]*' | awk -F'"' '{print $4}')
					URL_DESCRIPTION_TEXT=$(echo "${URL_DESCRIPTION}" | grep -o '<div id="watch-description-text".*</div>')
					echo -e "STARTDATE=${URL_DESCRIPTION_STARTDATE}\nENDDATE=${URL_DESCRIPTION_ENDDATE}\nTITLE=${URL_DESCRIPTION_TITLE}\nTEXT=${URL_DESCRIPTION_TEXT}" > "${DIR_LOCAL}/${FNAME}"
					[[ -f "${DIR_LOCAL}/${FNAME}" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} success") && break
					let RETRY++
				done
				[[ -f "${DIR_LOCAL}/${FNAME}" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} download ${DIR_LOCAL}/${FNAME} success")
				
				if [[ -f "${DIR_LOCAL}/${FNAME}" ]]; then
					DESCRIPTION="简介上传待"
					[[ "${BACKUP}" == "nobackup" ]] && DESCRIPTION="简介下载成功"
				else
					DESCRIPTION="简介下载失败"
					LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				fi
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change DESCRIPTION=${DESCRIPTION}"
				) &
			fi
			
			if [[ "${DESCRIPTION}" == "简介上传待" ]]; then
				DESCRIPTION="简介上传中" && sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change DESCRIPTION=${DESCRIPTION}"
				(
				RCLONE_RETRY=1 ; RCLONE_ERRFLAG=""
				if [[ "${BACKUP_DISK}" == *"rclone"* ]]; then
					until [[ ${RCLONE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} start retry ${RCLONE_RETRY}"
						RCLONE_ERRFLAG=$(rclone copy "${DIR_LOCAL}/${FNAME}" "${DIR_RCLONE}" 2>&1)
						[[ "${RCLONE_ERRFLAG}" == "" ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success") && break
						let RCLONE_RETRY++
					done
					[[ "${RCLONE_ERRFLAG}" == "" ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload rclone ${DIR_LOCAL}/${FNAME} success")
				fi
				
				ONEDRIVE_RETRY=1 ; ONEDRIVE_ERRFLAG=0
				if [[ "${BACKUP_DISK}" == *"onedrive"* ]]; then
					until [[ ${ONEDRIVE_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} start retry ${ONEDRIVE_RETRY}"
						onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${FNAME}"
						ONEDRIVE_ERRFLAG=$?
						[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} success") && break
						let ONEDRIVE_RETRY++
					done
					[[ "${ONEDRIVE_ERRFLAG}" == 0 ]] || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload onedrive ${DIR_LOCAL}/${FNAME} fail")
				fi
				
				BAIDUPAN_RETRY=1 ; BAIDUPAN_ERRFLAG="成功"
				if [[ "${BACKUP_DISK}" == *"baidupan"* ]]; then			
					until [[ ${BAIDUPAN_RETRY} -gt ${RETRY_MAX} ]]; do
						LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} start retry ${BAIDUPAN_RETRY}"
						BAIDUPAN_ERRFLAG=$(BaiduPCS-Go upload "${DIR_LOCAL}/${FNAME}" "${DIR_BAIDUPAN}")
						(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") && (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success") && break
						let BAIDUPAN_RETRY++
					done
					(echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功") || (LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} upload baidupan ${DIR_LOCAL}/${FNAME} success")
				fi
				
				if [[ "${RCLONE_ERRFLAG}" = "" ]] && [[ "${ONEDRIVE_ERRFLAG}" == 0 ]] && (echo "${BAIDUPAN_ERRFLAG}" | grep -q "成功"); then
					DESCRIPTION="简介上传成功"
				else
					DESCRIPTION="简介上传失败"
				fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} ${LINE} remove ${DIR_LOCAL}/${FNAME}" ; rm "${DIR_LOCAL}/${FNAME}"
				sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,${DESCRIPTION}/" "${DIR_LOG}" && LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") && echo "${LOG_PREFIX} ${LINE} change DESCRIPTION=${DESCRIPTION}"
				) &
			fi
		fi
		#sed -i "/${URL},${DATE}/s/\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\),\([^,]*\)/\1,\2,\3,\4,\5,\6/" "${DIR_LOG}"
	done
	
	if [[ "${LOOP_TIME}" != "loop" ]]; then
		[[ "${LOOP}" -gt "${LOOP_TIME}" ]] && break
		let LOOP++
	fi
	LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} detect loop end retry after ${LOOPINTERVAL} seconds..."
	sleep ${LOOPINTERVAL}
done
