#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} onedrive|baidupan \"本地目录\" [6|其他保留文件数] [loop|once] [1800|其他监视间隔] [\"record_video/other|onedrive或baidupan目录|/\"]"
	echo "示例：${0} onedrive \"record_video/other\" 6 loop 1800 \"record_video/other\""
	exit 1
fi

DIR_LOCAL="${2}" #本地目录
FILENUMBER="${3:-6}" #保留文件数
LOOP="${4:-loop}" #是否循环
INTERVAL="${5:-1800}" #监视间隔
DIR_CLOUD="${6:-record_video/other}" #onedrive或baidupan目录
DIR_ONEDRIVE=${DIR_CLOUD}
DIR_BAIDUPAN=${DIR_CLOUD}

if [ "${1}" == "onedrive" ]; then
	while true; do
		count=0;
		eval ls -tl "record" 2>/dev/null | awk '/^-/{print $NF}' | while read ONEFILE ; do #根据修改时间判断文件新旧
			let count++
			if [ ${count} -gt ${FILENUMBER} ]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} start" #开始上传
				onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${ONEFILE}"
				
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} stopped. remove ${DIR_LOCAL}/${ONEFILE}" #删除文件
				rm -f "${DIR_LOCAL}/${ONEFILE}"
				
			else
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} keep file $count ${DIR_LOCAL}/${ONEFILE}" #保留文件
			fi
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} backup done. retry after ${INTERVAL} seconds..."
		[[ "${LOOP}" == "once" ]] && break
		
		sleep ${INTERVAL}
	done
fi

if [ "${1}" == "baidupan" ]; then
	while true; do
		count=0;
		eval ls -t ${DIR_LOCAL} 2>/dev/null | while read ONEFILE ; do #根据修改时间判断文件新旧
			let count++
			if [ ${count} -gt ${FILENUMBER} ]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} start" #开始上传
				BaiduPCS-Go upload "${DIR_LOCAL}/${ONEFILE}" "${DIR_BAIDUPAN}" > /dev/null
				
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} stopped. remove ${DIR_LOCAL}/${ONEFILE}" #删除文件
				rm -f "${DIR_LOCAL}/${ONEFILE}"
				
			else
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				echo "${LOG_PREFIX} keep file $count ${DIR_LOCAL}/${ONEFILE}" #保留文件
			fi
		done
		
		LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
		echo "${LOG_PREFIX} backup done. retry after ${INTERVAL} seconds..."
		[[ "${LOOP}" == "once" ]] && break
		
		sleep ${INTERVAL}
	done
fi
