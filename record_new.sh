#!/bin/bash

#使用说明
if [[ ! -n "${1}" ]]; then
	echo ""
	echo ""
	echo "基本用法:"
	echo "${0} 频道类型 频道号码"
	echo "频道类型支持youtube youtubeffmpeg twitcast twitcastffmpeg twitcastpy twitch openrec nicolv nicoco nicoch mirrativ reality 17live chaturbate bilibili bilibiliy bilibilir streamlink"
	echo ""
	echo ""
	echo "参数说明:"
	echo $'--nico-id			nico用户名'
	echo $'--nico-psw			nico密码'
	echo $'--you-cookies		youtube监测cookies文件,需要配合--you-config参数使用'
	echo $'--you-config			youtube录制配置文件,仅支持youtube频道类型'
	echo $'--bili-config		bilibili录制配置文件,仅支持bilibili频道类型'
	echo $'--bili-cookies		bilibili录制cookies文件,仅支持bilibiliy频道类型'
	echo $'--bili-proxy			bilibili录制代理'
	echo $'--bili-proxy-url		bilibili录制代理获取链接'
	echo $'-f|--format			清晰度,默认为best'
	echo $'-p|--part-time			分段时间,0为不分段,默认为0'
	echo $'-l|--loop-interval		检测间隔,默认为60'
	echo $'-ml|--min-loop-interval		最短录制间隔,默认为180'
	echo $'-ms|--min-status		开始录制前需要持续检测到开播次数,默认为1'
	echo $'-o|-d|--output|--dir		输出目录,默认为record_video/other'
	echo $'-u|--upload			上传网盘,格式为网盘类型重试次数:盘符:路径,网盘类型支持rclone paidupcs onedrive,例如rclone3:vps:record'
	echo $'-dt|--delete-type		删除本地录像需要成功上传的数量,默认为1,del为强制删除,keep为强制保留,all为需要全部上传成功'
	echo $'-e|--except 频道类型 频道号码	排除转播,格式同录制频道'
	echo ""
	echo ""
	echo "示例："
	echo "${0} bilibili 12235923 -f best,1080p60,1080p,720p,480p,360p,worst -p 14400 -l 60 -ml 180 -o record_video/mea -u rclone:vps:record -u baidupcs:lovezzzxxx:record_video -dt 1 -e youtube UCWCc8tO-uUl_7SJXIKJACMw"
	echo ""
	echo ""
	echo "其他说明："
	echo "必要模块为curl streamlink ffmpeg ,可选模块为livedl python3 you-get,请将livedl文件放置于运行时目录的livedl文件夹内 ,请将BilibiliLiveRecorder解压放置于运行时目录的BilibiliLiveRecorder文件夹内,请将record_twitcast.py文件放置于运行时目录的record文件夹内。"
	echo "rclone上传基于\"https://github.com/rclone/rclone\"百度云上传基于\"https://github.com/qjfoidnh/BaiduPCS-Go\",onedrive上传基于\"https://github.com/MoeClub/OneList/tree/master/OneDriveUploader\",请登录后使用。"
	echo ""
	echo ""
	exit 1
fi

#打印log
function print(){
	echo "$(date +"[%Y-%m-%d %H:%M:%S]") $1"
}

#转换完整链接
function getfullurl(){
	local TYPE=$1
	local PART_URL=$2
	[[ $TYPE == "youtube"* ]] && echo "https://www.youtube.com/channel/${PART_URL}/live"
	[[ $TYPE == "twitcast"* ]] && echo "https://twitcasting.tv/${PART_URL}"
	[[ $TYPE == "twitch" ]] && echo "https://twitch.tv/${PART_URL}"
	[[ $TYPE == "openrec" ]] && echo "https://openrec.tv/user/${PART_URL}"
	[[ $TYPE == "nicolv" ]] && echo "https://live.nicovideo.jp/gate/${PART_URL}"
	[[ $TYPE == "nicoco" ]] && echo "https://com.nicovideo.jp/community/${PART_URL}"
	[[ $TYPE == "nicoch" ]] && echo "https://ch.nicovideo.jp/${PART_URL}/live"
	[[ $TYPE == "mirrativ" ]] && echo "https://www.mirrativ.com/user/${PART_URL}"
	[[ $TYPE == "reality" ]] && echo "reality_${PART_URL}"
	[[ $TYPE == "17live" ]] && echo "https://17.live/live/${PART_URL}"
	[[ $TYPE == "chaturbate" ]] && echo "https://chaturbate.com/${PART_URL}/"
	[[ $TYPE == "bilibili"* ]] && echo "https://live.bilibili.com/${PART_URL}"
	[[ $TYPE == "streamlink" ]] && echo "${PART_URL}"
}

#检测直播状态,返回1为开播,返回0为未开播,在不为EXCEPT时保存PAGE
LIVE_STATUS_YOUTUBE=0
LIVE_STATUS_YOUTUBE_BEFORE=0
function getlivestatus(){
	local TYPE=$1
	local PART_URL=$2
	local FULL_URL=$3
	local EXCEPT=$4
	local STATUS=0
	local LOCAL_PAGE=""
	
	if [[ $TYPE == "youtube"* ]]; then
		if [[ -n $YOU_COOKIES ]]; then
			LOCAL_PAGE=$(wget --load-cookies "$YOU_COOKIES" -q -O- "$FULL_URL")
		else
			LOCAL_PAGE=$(wget -q -O- "$FULL_URL")
		fi
		#qualityLabel开播早下播晚会在下播时多录,isLive开播晚下播早会在开播时晚录
		#(echo $LOCAL_PAGE | grep -q '\"playabilityStatus\":{\"status\":\"OK\"') && break
		if [[ $LIVE_STATUS_YOUTUBE -lt 1 ]] || [[ $EXCEPT == "except" ]]; then
			if (echo $LOCAL_PAGE | grep -q '\"qualityLabel\":\"[0-9]*p\"'); then
				STATUS=1
				[[ $EXCEPT != "except" ]] && LIVE_STATUS_YOUTUBE=3
			else
				[[ $EXCEPT != "except" ]] && let LIVE_STATUS_YOUTUBE-- && let LIVE_STATUS_YOUTUBE_BEFORE--
			fi
		else
			if (echo $LOCAL_PAGE | grep "ytplayer" | grep -q '\"isLive\":true'); then
				STATUS=1
				[[ $EXCEPT != "except" ]] && LIVE_STATUS_YOUTUBE=3
			else
				[[ $EXCEPT != "except" ]] && let LIVE_STATUS_YOUTUBE-- && let LIVE_STATUS_YOUTUBE_BEFORE--
			fi
		fi
	fi
	if [[ $TYPE == "twitcast"* ]]; then
		local LOCAL_PAGE=$(wget -q -O- "https://twitcasting.tv/streamserver.php?target=${PART_URL}&mode=client")
		if (echo $LOCAL_PAGE | grep -q '"live":true'); then STATUS=1; fi
	fi
	if [[ $TYPE == "twitch" ]]; then
		local LOCAL_PAGE=$(streamlink --stream-url "$FULL_URL" "$FORMAT")
		if (echo $LOCAL_PAGE | grep -q ".m3u8"); then STATUS=1; fi
	fi
	if [[ $TYPE == "openrec" ]]; then
		local LOCAL_PAGE=$(wget -q -O- "$FULL_URL" | grep -o 'href="https://www.openrec.tv/live/.*" class' | head -n 1 | awk -F'"' '{print $2}')
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "nicolv" ]]; then
		local LOCAL_PAGE=$(curl -s -I "https://live.nicovideo.jp/gate/${PART_URL}" | grep -o "https://live2.nicovideo.jp/watch/lv[0-9]*")
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "nicoco" ]]; then
		local LOCAL_PAGE=$(wget -q -O- "https://com.nicovideo.jp/community/${PART_URL}" | grep -o '<a class="now_live_inner" href="https://live.nicovideo.jp/watch/lv[0-9]*' | head -n 1 | awk -F'"?' '{print $4}')
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "nicoch" ]]; then
		local LOCAL_PAGE=$(wget -q -O- "https://ch.nicovideo.jp/${PART_URL}/live" | awk 'BEGIN{RS="<section class=";FS="\n";ORS="\n";OFS="\t"} $1 ~ /sub now/ {LIVE_POS=match($0,"https://live.nicovideo.jp/watch/lv[0-9]*");LIVE=substr($0,LIVE_POS,RLENGTH);print LIVE}' | head -n 1)
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; else
			local LOCAL_PAGE=$(wget -q -O- "https://ch.nicovideo.jp/${PART_URL}" | grep -o "data-live_id=\"[0-9]*\" data-live_status=\"onair\"" | head -n 1 | awk -F'"' '{print $2}')
			if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
		fi
	fi
	if [[ $TYPE == "mirrativ" ]]; then
		local LOCAL_PAGE=$(wget -q -O- "https://www.mirrativ.com/api/user/profile?user_id=${PART_URL}" | grep -o '"live_id":".*"' | awk -F'"' '{print $4}')
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "reality" ]]; then
		local LOCAL_PAGE=$(curl -s -X POST "https://media-prod-dot-vlive-prod.appspot.com/api/v1/media/lives_user" | awk -v PART_URL="${PART_URL}" 'BEGIN{RS="\"StreamingServer\"";FS=",";ORS="\n";OFS="\t"} {M3U8_POS=match($0,"\"view_endpoint\":\"[^\"]*\"");M3U8=substr($0,M3U8_POS,RLENGTH) ; ID_POS=match($0,"\"vlive_id\":\"[^\"]*\"");ID=substr($0,ID_POS,RLENGTH) ; if(match($0,"\"nickname\":\"[^\"]*"PART_URL"[^\"]*\"|\"vlive_id\":\""PART_URL"\"")) print M3U8,ID}' | head -n 1)
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "17live" ]]; then
		local LOCAL_PAGE=$(curl -s -X POST "https://api-dsa.17app.co/api/v1/lives/${PART_URL}/viewers/alive" --data-raw "{\"liveStreamID\": \"${PART_URL}\"}" | grep -o '"webUrl":"[^"]*' | awk -F'\"' '{print $4}')
		LOCAL_PAGE=${LOCAL_PAGE%%flv*}flv
		if [[ -n "${LOCAL_PAGE}" ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "chaturbate" ]]; then
		local LOCAL_PAGE=$(curl -s "https://chaturbate.com/${PART_URL}/" | grep -o "https://edge[0-9]*.stream.highwebmedia.com.*/playlist.m3u8" | sed 's/\\u002D/-/g')
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	if [[ $TYPE == "streamlink" ]]; then
		local LOCAL_PAGE=$(streamlink --stream-url "$FULL_URL" "$FORMAT")
		if (echo $LOCAL_PAGE | grep -Eq ".m3u8|.flv|rtmp:|The stream specified cannot be translated to a URL"); then STATUS=1; fi
	fi
	if [[ $TYPE == "bilibili"* ]]; then
		local LOCAL_PAGE=$(wget -q -O- "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=${PART_URL}" | grep -o '"live_status":1')
		if [[ -n $LOCAL_PAGE ]]; then STATUS=1; fi
	fi
	
	[[ $EXCEPT != "except" ]] && PAGE=$LOCAL_PAGE
	print "metadata ${EXCEPT} ${FULL_URL} status ${STATUS}"
	return $STATUS
}

#从PAGE获取STREAM_ID STREAM_URL DLNAME FNAME,STREAM_PROXY也在此获取
function prasepage(){
	if [[ $TYPE == "youtube"* ]]; then
		STREAM_ID=$(echo $PAGE | grep -o '\"liveStreamabilityRenderer\":{\"videoId\":\".*\"' | head -n 1 | awk -F'"' '{print $6}')
		FNAME="youtube_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${STREAM_ID}.ts"
	fi
	if [[ $TYPE == "youtubeffmpeg" ]]; then
		STREAM_URL=$(streamlink --stream-url "${FULL_URL}" "${FORMAT}")
	fi
	if [[ $TYPE == "twitcast"* ]]; then
		STREAM_ID=$(echo $PAGE | grep -o '"id":[0-9]*' | awk -F':' '{print $2}')
		DLNAME="${PART_URL/:/：}_${STREAM_ID}.ts"
		FNAME="twitcast_${PART_URL/:/：}_$(date +"%Y%m%d_%H%M%S")_${STREAM_ID}.ts"
	fi
	if [[ $TYPE == "twitcastffmpeg" ]]; then
		STREAM_URL=$(echo $PAGE | grep ".m3u8" | head -n 1)
	fi
	if [[ $TYPE == "twitcastpy" ]]; then
		STREAM_URL="wss://$(echo $PAGE | grep -o '"fmp4":{"host":"[^"]*"' | awk -F'"' '{print $6}')/ws.app/stream/${STREAM_ID}/fmp4/bd/1/1500?mode=source"
	fi
	if [[ $TYPE == "twitch" ]]; then
		STREAM_URL=$PAGE
		FNAME="twitch_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "openrec" ]]; then
		STREAM_URL=$(streamlink --stream-url "$PAGE" "$FORMAT")
		FNAME="openrec_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "nico"* ]]; then
		STREAM_ID=$(echo $PAGE | grep -o "lv[0-9]*")
		DLNAME="niconico_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${STREAM_ID}"
		FNAME="niconico_${PART_URL}_$(date +"%Y%m%d_%H%M%S")_${STREAM_ID}.ts"
	fi
	if [[ $TYPE == "mirrativ" ]]; then
		STREAM_URL=$(wget -q -O- "https://www.mirrativ.com/api/live/live?live_id=${PAGE}" | grep -o '"streaming_url_hls":".*m3u8"' | awk -F'"' '{print $4}')
		FNAME="mirrativ_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "reality" ]]; then
		STREAM_ID=$(echo $PAGE | awk -F'"' '{print $8}')
		STREAM_URL=$(echo $PAGE | awk -F'"' '{print $4}')
		FNAME="reality_${STREAM_ID}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "17live" ]]; then
		STREAM_URL=$PAGE
		FNAME="17live_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "chaturbate" ]]; then
		STREAM_URL="${PAGE/playlist.m3u8/}$(curl -s "${PAGE}" | tail -n 1)"
		FNAME="chaturbate_${PART_URL}_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "streamlink" ]]; then
		STREAM_URL=$PAGE
		FNAME="stream_$(date +"%Y%m%d_%H%M%S").ts"
	fi
	if [[ $TYPE == "bilibili"* ]]; then
		DLNAME="bilibili_${PART_URL}_$(date +"%Y%m%d_%H%M%S")"
		FNAME="bilibili_${PART_URL}_$(date +"%Y%m%d_%H%M%S").flv"
		if [[ -n $BILIBILI_PROXY ]]; then
			STREAM_PROXY=$BILIBILI_PROXY
		elif [[ -n $BILIBILI_PROXY_URL ]]; then
			STREAM_PROXY=$(curl -s "$BILIBILI_PROXY_URL")
		fi
		#STREAM_URL=$(wget -q -O- "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=${PART_URL}&qn=10000&platform=web" | grep -o "\"url\":\"[^\"]*\"" | head -n 1 | awk -F"\"" '{print $4}' | sed 's/\\u0026/\&/g'); fi
		#STREAM_URL=$(curl -s --proxy ${STREAM_PROXY} "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=${PART_URL}&qn=10000&platform=web" | grep -o "\"url\":\"[^\"]*\"" | grep "https://txy.live-play.acgvideo.com\|https://js.live-play.acgvideo.com\|https://ws.live-play.acgvideo.com" | head -n 1 | awk -F"\"" '{print $4}' | sed 's/\\u0026/\&/g')
	fi
}

#开始录制,返回录制进程id
function startrecord(){
	if [[ $TYPE == "youtube" ]]; then
		if [[ $LIVE_STATUS_YOUTUBE_BEFORE -lt 1 ]]; then
			if [[ -n $STREAMLINK_CONFIG ]]; then
				(streamlink --loglevel trace --hls-live-restart --config "$STREAMLINK_CONFIG" -o "${DIR}/${FNAME}" "https://www.youtube.com/watch?v=${STREAM_ID}" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(streamlink --loglevel trace --hls-live-restart -o "${DIR}/${FNAME}" "https://www.youtube.com/watch?v=${STREAM_ID}" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		else
			if  [[ -n $STREAMLINK_CONFIG ]]; then
				(streamlink --loglevel trace --config "$STREAMLINK_CONFIG" -o "${DIR}/${FNAME}" "https://www.youtube.com/watch?v=${STREAM_ID}" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(streamlink --loglevel trace -o "${DIR}/${FNAME}" "https://www.youtube.com/watch?v=${STREAM_ID}" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		fi
		LIVE_STATUS_YOUTUBE_BEFORE=3
	fi
	if [[ $TYPE == "twitcast" ]]; then
		(livedl/livedl -tcas "$PART_URL" > "${DIR}/${FNAME}.log" 2>&1) &
	fi
	if [[ $TYPE == "twitcastpy" ]]; then
		(python3 record/record_twitcast.py "$STREAM_URL" "${DIR}/${FNAME}" > "${DIR}/${FNAME}.log" 2>&1) &
	fi
	if [[ $TYPE == "nico"* ]]; then
		if [[ -n $NICO_ID_PSW ]]; then
			(livedl/livedl -nico-login-only=on -nico-login "$NICO_ID_PSW" -nico-force-reservation=on -nico-limit-bw 0 -nico-format "$DLNAME" -nico "$STREAM_ID" > "${DIR}/${FNAME}.log" 2>&1) &
		else
			(livedl/livedl -nico-login-only=off -nico-force-reservation=on -nico-limit-bw 0 -nico-format "$DLNAME" -nico "$STREAM_ID" > "${DIR}/${FNAME}.log" 2>&1) &
		fi
	fi
	if [[ $TYPE == "17live" ]]; then
		(ffmpeg -headers "Referer: https://17.live/live/${PART_URL}" -i "$STREAM_URL" -codec copy -f mpegts "${DIR}/${FNAME}" > "${DIR}/${FNAME}.log" 2>&1) &
	fi
	if [[ $TYPE == "bilibili" ]]; then
		if [[ -n $STREAM_PROXY ]]; then
			if [[ -n $STREAMLINK_CONFIG ]]; then
				(streamlink --loglevel trace --http-proxy "http://${STREAM_PROXY}/" --config "$STREAMLINK_CONFIG" -o "${DIR}/${FNAME}" "$FULL_URL" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(streamlink --loglevel trace --http-proxy "http://${STREAM_PROXY}/" -o "${DIR}/${FNAME}" "$FULL_URL" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		else
			if [[ -n $STREAMLINK_CONFIG ]]; then
				(streamlink --loglevel trace --config "$STREAMLINK_CONFIG" -o "${DIR}/${FNAME}" "$FULL_URL" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(streamlink --loglevel trace -o "${DIR}/${FNAME}" "$FULL_URL" "$FORMAT" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		fi
	fi
	if [[ $TYPE == "bilibiliy" ]]; then
		if [[ -n $STREAM_PROXY ]]; then
			if [[ -n $BILI_COOKIES ]]; then
				(you-get --debug --http-proxy "$STREAM_PROXY" -c "$BILI_COOKIES" -O "${DIR}/${DLNAME}" "$FULL_URL" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(you-get --debug --http-proxy "$STREAM_PROXY" -O "${DIR}/${DLNAME}" "$FULL_URL" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		else
			if [[ -n $BILI_COOKIES ]]; then
				(you-get --debug -c "$BILI_COOKIES" -O "${DIR}/${DLNAME}" "$FULL_URL" > "${DIR}/${FNAME}.log" 2>&1) &
			else
				(you-get --debug -O "${DIR}/${DLNAME}" "$FULL_URL" > "${DIR}/${FNAME}.log" 2>&1) &
			fi
		fi
	fi
	if [[ $TYPE == "bilibilir" ]]; then
		if [[ -n $STREAM_PROXY ]]; then
			(java -Dfile.encoding=utf-8 -jar BilibiliLiveRecorder/BiliLiveRecorder.jar "debug=true&check=false&proxy=${STREAM_PROXY}&liver=bili&id=${PART_URL}&qn=-1&saveFolder=${DIR}&fileName=${DLNAME}" > "${DIR}/${FNAME}.log" 2>&1) &
		else
			(java -Dfile.encoding=utf-8 -jar BilibiliLiveRecorder/BiliLiveRecorder.jar "debug=true&check=false&liver=bili&id=${PART_URL}&qn=-1&saveFolder=${DIR}&fileName=${DLNAME}" > "${DIR}/${FNAME}.log" 2>&1) &
		fi
	fi
	if [[ $TYPE == "youtubeffmpeg" || $TYPE == "twitcastffmpeg" || $TYPE == "twitch" || $TYPE == "openrec" || $TYPE == "mirrativ" || $TYPE == "reality" || $TYPE == "chaturbate" || $TYPE == "streamlink" ]]; then
		(ffmpeg -user_agent "Mozilla/5.0" -i "$STREAM_URL" -codec copy -f mpegts "${DIR}/${FNAME}" > "${DIR}/${FNAME}.log" 2>&1) &
	fi
	
	echo $!
}

#上传准备
function up(){
	if [[ $TYPE == "twitcast" ]]; then
		print "remane livedl/${DLNAME} to ${DIR}/${FNAME}"
		mv "livedl/${DLNAME}" "${DIR}/${FNAME}"
	fi
	if [[ $TYPE == "nico"* ]]; then
		if [[ -f "livedl/${DLNAME}.sqlite3" ]]; then
			print "convert start livedl/${DLNAME}.sqlite3 to livedl/${DLNAME}.ts"
			livedl/livedl -d2m -conv-ext=ts "${DLNAME}.sqlite3" >> "${DIR}/${FNAME}.log" 2>&1
			print "remove livedl/${DLNAME}.sqlite3 and xml"
			rm "livedl/${DLNAME}.sqlite3" ; rm "livedl/${DLNAME}.xml"
			print "remane livedl/${DLNAME}.ts to ${DIR}/${FNAME}"
			mv "livedl/${DLNAME}.ts" "${DIR}/${FNAME}"
		fi
		if [[ -f "livedl/${DLNAME}(TS).sqlite3" ]]; then
			print "convert start livedl/${DLNAME}(TS).sqlite3 to livedl/${DLNAME}(TS).ts"
			livedl/livedl -d2m -conv-ext=ts "${DLNAME}(TS).sqlite3" >> "${DIR}/${FNAME}.log" 2>&1
			print "remove livedl/${DLNAME}(TS).sqlite3 and xml"
			rm "livedl/${DLNAME}(TS).sqlite3" ; rm "livedl/${DLNAME}(TS).xml"
			print "remane livedl/${DLNAME}(TS).ts to ${DIR}/${FNAME}"
			mv "livedl/${DLNAME}(TS).ts" "${DIR}/${FNAME}"
		fi
	fi
	
	if [[ ! -f "${DIR}/${FNAME}" ]] || [[ $(ls -l "${DIR}/${FNAME}" | awk '{print $5}') == 0 ]]; then #判断是否无录像
		print "${DIR}/${FNAME} file not exist remove log"
		rm -f "${DIR}/${FNAME}" ; rm -f "${DIR}/${FNAME}.log"
	elif [[ $TYPE == "bilibili"* ]] && [[ $(ls -l "${DIR}/${FNAME}" | awk '{print $5}') -lt 3000000 ]]; then
		print "${DIR}/${FNAME} file is too small remove file and log"
		rm -f "${DIR}/${FNAME}" ; rm -f "${DIR}/${FNAME}.log"
	elif [[ -n ${!UPLOAD_TYPE_LIST[*]} ]]; then #存在上传列表才上传
		upload "${DIR}/${FNAME}"
		upload "${DIR}/${FNAME}.log"
	fi
}

#上传
function upload(){
	local FILE=$1
	local UPLOAD_STATUS=0
	
	for i in ${!UPLOAD_TYPE_LIST[*]}; do
		uploadto $FILE ${UPLOAD_TYPE_LIST[$i]} ${UPLOAD_RETRY_LIST[$i]} ${UPLOAD_DISK_LIST[$i]} ${UPLOAD_DIR_LIST[$i]}; STATUS=$?
		[[ $STATUS == 1 ]] && let UPLOAD_STATUS++
	done
	
	if [[ $DELETE_TYPE -lt 0 ]]; then
		print "force delete ${FILE}"
		rm $FILE
	elif [[ $DELETE_TYPE == 0 ]]; then
		print "force keep ${FILE}"
	elif [[ $DELETE_TYPE -gt 0 ]]; then
		if [[ ! $UPLOAD_STATUS -lt $DELETE_TYPE ]]; then
			print "upload ${UPLOAD_STATUS}/${DELETE_TYPE} delete ${FILE}"
			rm $FILE
		else
			print "upload ${UPLOAD_STATUS}/${DELETE_TYPE} keep ${FILE}"
		fi
	fi
}

#上传到,成功返回1,失败返回0
function uploadto(){
	local FILE=$1
	local TYPE=$2
	local RETRY=$3
	local DISK=$4
	local DIR=$5
	local RETRY_COUNT=0
	local STATUS=0
	
	while [[ $RETRY_COUNT -lt $RETRY ]]; do
		let RETRY_COUNT++
		print "upload ${FILE} to ${TYPE} ${DISK}:${DIR} start ${RETRY_COUNT}/${RETRY}"
		if [[ $TYPE == "rclone" ]]; then
			LOG=$(rclone copy "$FILE" "${DISK}:${DIR}" 2>&1)
			[[ $LOG == "" ]] && STATUS=1
		fi
		if [[ $TYPE == "baidupcs" ]]; then
			local WHO=$(BaiduPCS-Go who | grep -o "uid: [0-9]*" | grep -o "[0-9]*") #之后还原用户uid
			$(BaiduPCS-Go su "$DISK" > /dev/null 2>&1)
			LOG=$(BaiduPCS-Go upload "$FILE" "$DIR")
			$(BaiduPCS-Go su "$WHO" > /dev/null 2>&1)
			(echo $LOG | grep -Eq "上传文件成功, 保存到网盘路径:|秒传成功, 保存到网盘路径:|已存在, 跳过...|") && STATUS=1
		fi
		if [[ $TYPE == "onedrive" ]]; then
			LOG=$(OneDriveUploader -s "$FILE" -r "$DIR")
			LOG=$?; [[ $LOG == 0 ]] && STATUS=1
		fi
		if [[ $TYPE == "bypy" ]]; then
			LOG=$(bypy upload "$FILE" "$DIR" | tail -n 1)
			[[ $LOG == "" ]] && STATUS=1
		fi
		
		if [[ $STATUS == 1 ]]; then
			print "upload ${FILE} to ${TYPE} ${DISK}:${DIR} success"
			return $STATUS
		else
			print "upload ${FILE} to ${TYPE} ${DISK}:${DIR} fail ${RETRY_COUNT}/${RETRY}"
			[[ $RETRY_COUNT -lt $RETRY ]] && sleep $(( 60*$RETRY_COUNT ))
		fi
	done
	return $STATUS
}



#解析传入参数
while true; do
	case "$1" in
		--nico-id)
			NICO_ID=$2
			shift 2
			;;
		--nico-psw)
			NICO_PSW=$2
			shift 2
			;;
		--you-cookies)
			YOU_COOKIES=$2
			shift 2
			;;
		--you-config|--bili-config)
			STREAMLINK_CONFIG=$2
			shift 2
			;;
		--bili-cookies)
			BILI_COOKIES=$2
			shift 2
			;;
		--bili-proxy)
			BILIBILI_PROXY=$2
			shift 2
			;;
		--bili-proxy-url)
			BILIBILI_PROXY_URL=$2
			shift 2
			;;
		-f|--format)
			FORMAT=$2
			shift 2
			;;
		-p|--part-time)
			PART_TIME=$2
			shift 2
			;;
		-l|--loop-interval)
			LOOP_INTERVAL=$2
			shift 2
			;;
		-ml|--min-loop-interval)
			MIN_INTERVAL=$2
			shift 2
			;;
		-ms|--min-status)
			MIN_STATUS=$2
			shift 2
			;;
		-o|-d|--output|--dir)
			DIR=$2
			shift 2
			;;
		-u|--upload) #rclone1:: baidupcs:: onedrive3
			UPLOAD_TYPE_LIST[${#UPLOAD_TYPE_LIST[*]}]=$(echo $2 | awk -F":" '{print $1}' | grep -o "[^0-9]*")
			UPLOAD_RETRY_LIST[${#UPLOAD_RETRY_LIST[*]}]=$(echo $2 | awk -F":" '{print $1}' | grep -o "[0-9]*")
			UPLOAD_DISK_LIST[${#UPLOAD_DISK_LIST[*]}]=$(echo $2 | awk -F":" '{print $2}')
			UPLOAD_DIR_LIST[${#UPLOAD_DIR_LIST[*]}]=$(echo $2 | awk -F":" '{print $3}')
			shift 2
			;;
		-dt|--delete-type)
			DELETE_TYPE=$2
			shift 2
			;;
		-e|--except)
			EXCEPT_TYPE_LIST[${#EXCEPT_TYPE_LIST[*]}]=$2
			EXCEPT_PART_URL_LIST[${#EXCEPT_PART_URL_LIST[*]}]=$3
			shift 3
			;;
		*)
			[[ ! -n $1 ]] && break
			TYPE=$1
			PART_URL=$2
			shift 2
			;;
	esac
done

#环境检测
if [[ $TYPE == "twitcast" || "${1}" == "nico"* ]]; then
	[[ ! -f "livedl/livedl" ]] && echo "需要livedl,请将livedl文件放置于运行时目录的livedl文件夹内"
fi
if [[ $TYPE == "twitcastpy" ]]; then
	[[ ! -f "record/record_twitcast.py" ]] && echo "需要record_twitcast.py,请将record_twitcast.py文件放置于运行时目录的record文件夹内"
fi
if [[ $TYPE == "bilibilir" ]]; then
	[[ ! -f "BilibiliLiveRecorder/BiliLiveRecorder.jar" ]] && echo "需要BiliLiveRecorder.jar，请将BilibiliLiveRecorder解压放置于运行时目录的BilibiliLiveRecorder文件夹内"
fi

#初始化
NICO_ID_PSW=""; [[ -n $NICO_ID ]] && [[ -n $NICO_PSW ]] && NICO_ID_PSW="${NICO_ID},${NICO_PSW}"
[[ ! -n $FORMAT ]] && FORMAT="best"
[[ ! -n $PART_TIME ]] && PART_TIME=0
[[ ! -n $LOOP_INTERVAL ]] && LOOP_INTERVAL=60
[[ ! -n $MIN_INTERVAL ]] && MIN_INTERVAL=180
[[ ! -n $MIN_STATUS ]] && MIN_STATUS=1
[[ ! -n $DIR ]] && DIR="record_video/other"; mkdir -p "${DIR}"
[[ ! -n $DELETE_TYPE ]] && DELETE_TYPE=1; [[ $DELETE_TYPE == "del" ]] && DELETE_TYPE=-1; [[ $DELETE_TYPE == "keep" ]] && DELETE_TYPE=0; [[ $DELETE_TYPE == "all" ]] && DELETE_TYPE=${#UPLOAD_TYPE_LIST[*]}
for i in ${!UPLOAD_TYPE_LIST[*]}; do
	[[ ! -n ${UPLOAD_RETRY_LIST[$i]} ]] && UPLOAD_RETRY_LIST[$i]=1
	[[ ! -n ${UPLOAD_DISK_LIST[$i]} ]] && UPLOAD_DISK_LIST[$i]="0"
	[[ ! -n ${UPLOAD_DIR_LIST[$i]} ]] && UPLOAD_DIR_LIST[$i]=$DIR
done
for i in ${!EXCEPT_TYPE_LIST[*]}; do
	EXCEPT_FULL_URL_LIST[$i]=$(getfullurl ${EXCEPT_TYPE_LIST[$i]} ${EXCEPT_PART_URL_LIST[$i]})
done
FULL_URL=$(getfullurl $TYPE $PART_URL)

#检测与录制循环
LIVE_STATUS=0
EXCEPT_STATUS=0
while true; do
	while true; do
		#排除EXCEPT
		for i in ${!EXCEPT_TYPE_LIST[*]}; do
			getlivestatus ${EXCEPT_TYPE_LIST[$i]} ${EXCEPT_PART_URL_LIST[$i]} ${EXCEPT_FULL_URL_LIST[$i]} except; EXCEPT_STATUS=$?
			[[ $EXCEPT_STATUS == 1 ]] && sleep $LOOP_INTERVAL && break
		done
		#检测MAIN
		if [[ $EXCEPT_STATUS == 0 ]]; then
			getlivestatus $TYPE $PART_URL $FULL_URL main; STATUS=$?
			if [[ $STATUS == 1 ]]; then
				let LIVE_STATUS++
				[[ ! $LIVE_STATUS -lt $MIN_STATUS ]] && break
			else
				LIVE_STATUS=0
			fi
		fi
		sleep $LOOP_INTERVAL
	done
	
	prasepage
	
	RECORD_PID=$(startrecord) #录制进程PID
	RECORD_STOPTIME=$(( $(date +%s)+$PART_TIME )) #录制结束时间戳
	RECORD_ENDTIME=$(( $(date +%s)+$MIN_INTERVAL )) #录制循环结束的最短时间
	print "record start: PID=${RECORD_PID}, PART_URL=${PART_URL}, STREAM_ID=${STREAM_ID}, STREAM_URL=${STREAM_URL}, FNAME=${FNAME}"
	while true; do
		sleep 10
		if ! (ps aux | awk '{print $2}'| grep -wq $RECORD_PID); then
			print "record already stopped"
			break
		else
			if [[ $PART_TIME != 0 ]] && [[ $(date +%s) -gt $RECORD_STOPTIME ]]; then #录制时间到达则终止录制
				print "time up kill record process ${RECORD_PID}"
				kill $RECORD_PID
				break
			fi
		fi
	done
	
	up &
	
	if [[ $(date +%s) -lt $RECORD_ENDTIME ]]; then
		RECORD_ENDREMAIN=$(( $RECORD_ENDTIME-$(date +%s) ))
		[[ RECORD_ENDREMAIN -lt 0 ]] && RECORD_ENDREMAIN=0 #距离最短结束时间的剩余时间
		print "record end too early retry after ${RECORD_ENDREMAIN} seconds"
		sleep $RECORD_ENDREMAIN
	fi
done
