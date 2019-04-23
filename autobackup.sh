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
			ERRFLAG_ONEDRIVE=0
			ERRFLAG_BAIDUPAN=0
			if [[ "${BACKUP}" == "onedrive"* ]]; then #上传onedrive
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start"
				onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${ONEFILE}" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? ))
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} stopped"
				if [[ ${ERRFLAG_ONEDRIVE} != 0 ]]; then echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"; fi
				if [[ ${ERRFLAG_ONEDRIVE} == 0 && "${BACKUP}" == "onedrive" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
				if [[ "${BACKUP}" == "onedrivedel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
			fi
			if [[ "${BACKUP}" == "baidupan"* ]]; then #上传baidupan
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start"
				BaiduPCS-Go upload "${DIR_LOCAL}/${ONEFILE}" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? ))
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} stopped"
				if [[ ${ERRFLAG_BAIDUPAN} != 0 ]]; then echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"; fi
				if [[ ${ERRFLAG_BAIDUPAN} == 0 && "${BACKUP}" == "baidupan" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
				if [[ "${BACKUP}" == "baidupandel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
			fi
			if [[ "${BACKUP}" == "both"* ]]; then
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start"
				onedrive -s -f "${DIR_ONEDRIVE}" "${DIR_LOCAL}/${ONEFILE}" ; ERRFLAG_ONEDRIVE=$(( ${ERRFLAG_ONEDRIVE}+$? ))
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} stopped"
				if [[ ${ERRFLAG_ONEDRIVE} != 0 ]]; then echo "${LOG_PREFIX} upload onedrive ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"; fi
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} start"
				BaiduPCS-Go upload "${DIR_LOCAL}/${ONEFILE}" "${DIR_BAIDUPAN}" > /dev/null ; ERRFLAG_BAIDUPAN=$(( ${ERRFLAG_BAIDUPAN}+$? ))
				LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]") ; echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} stopped"
				if [[ ${ERRFLAG_BAIDUPAN} != 0 ]]; then echo "${LOG_PREFIX} upload baidupan ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD} error"; fi
				if [[ ${ERRFLAG_ONEDRIVE} == 0 && ${ERRFLAG_BAIDUPAN} == 0 && "${BACKUP}" == "both" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE} to ${DIR_CLOUD}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
				if [[ "${BACKUP}" == "bothdel" ]]; then echo "${LOG_PREFIX} remove ${DIR_LOCAL}/${ONEFILE}" ; rm -f "${DIR_LOCAL}/${ONEFILE}"; fi
			fi
			
		else
			LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
			echo "${LOG_PREFIX} keep file $count ${DIR_LOCAL}/${ONEFILE}" #保留文件
		fi
	done
	
	LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
	echo "${LOG_PREFIX} backup done retry after ${INTERVAL} seconds..."
	[[ "${LOOP}" == "once" ]] && break
	
	sleep ${INTERVAL}
done
