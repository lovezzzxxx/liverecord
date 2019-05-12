#!/bin/bash

if [[ ! -n "${1}" ]]; then
	echo "${0} onedrive|baidupan|both|onedrivekeep|baidupankeep|bothkeep|onedrivedel|baidupandel|bothdel \"本地目录\" [6|其他保留文件数] [loop|once] [1800|其他监视间隔] [\"record_video/other|onedrive或baidupan目录|/\"]"
	echo "示例：${0} onedrive \"record_video/other\" 6 loop 1800 \"record_video/other\""
	exit 1
fi



BACKUP="${1}"
DIR_LOCAL="${2}" #本地目录
FILENUMBER="${3:-6}" #保留文件数
LOOP="${4:-loop}" #是否循环
INTERVAL="${5:-1800}" #监视间隔
DIR_CLOUD="${6:-record_video/other}" #onedrive或baidupan目录

DIR_ONEDRIVE=${DIR_CLOUD}
DIR_BAIDUPAN=${DIR_CLOUD}



while true; do
	count=0;
	eval ls -tl "record" | awk '/^-/{print $NF}' | while read ONEFILE ; do #根据修改时间判断文件新旧
		let count++
		if [ ${count} -gt ${FILENUMBER} ]; then
			ERRFLAG_ONEDRIVE_FILE=0 ; ERRFLAG_BAIDUPAN_FILE="全部上传完毕"
			if [[ "${BACKUP}" == "onedrive"* || "${BACKUP}" == "both"* ]]; then #上传onedrive
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start" ; onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${ONEFILE}" ; ERRFLAG_ONEDRIVE_FILE=$? ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				[[ "${ERRFLAG_ONEDRIVE_FILE}" == 0 ]] && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} success"
				[[ "${ERRFLAG_ONEDRIVE_FILE}" != 0 ]] && echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"
			fi
			if [[ "${BACKUP}" == "baidupan"* || "${BACKUP}" == "both"* ]]; then #上传baidupan
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start" ; ERRFLAG_BAIDUPAN=&(BaiduPCS-Go upload "${DIR_LOCAL}/${ONEFILE}" "${DIR_BAIDUPAN}") ; LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
				(echo "${ERRFLAG_BAIDUPAN_FILE}" | grep -q "全部上传完毕") && echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} success"
				(echo "${ERRFLAG_BAIDUPAN_FILE}" | grep -q "全部上传完毕") || echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"
			fi
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") #清除文件
			[[ "${BACKUP}" == *"keep" ]] && (echo "${LOG_PREFIX} force keep ${DIR_LOCAL}/${ONEFILE}" )
			[[ "${BACKUP}" == *"del" ]] && (echo "${LOG_PREFIX} force delete ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}")
			[[ "${BACKUP}" == "onedrive" || "${BACKUP}" == "baidupan" || "${BACKUP}" == "both" ]] && [[ "${ERRFLAG_ONEDRIVE_FILE}" == 0 ]] && (echo "${ERRFLAG_BAIDUPAN_FILE}" | grep -q "全部上传完毕") && (echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}")
		
		
		
		else
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} keep $count ${DIR_LOCAL}/${ONEFILE}" #保留文件
		fi
	done
	
	
	
	LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
	echo "${LOG_PREFIX} backup done retry after ${INTERVAL} seconds..."
	[[ "${LOOP}" == "once" ]] && break
	sleep ${INTERVAL}
done
