#!/bin/bash
#Need:jq lame
guid=5150825362
QQSearchUrl="http://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp?n=1&format=json&w="
QQKeyUrl="http://base.music.qq.com/fcgi-bin/fcg_musicexpress.fcg?json=3&guid=$guid&format=json"
QQPicUrl="http://y.gtimg.cn/music/photo_new/T002R300x300M000"
QQDlUrl="http://dl.stream.qqmusic.qq.com"
QQSongInfoUrl="https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg?tpl=yqq_song_detail&format=json&songmid="
NESearchUrl="http://music.163.com/api/cloudsearch/pc?type=1&offset=0&limit=1&s="
NESongUrl="http://music.163.com/api/song/detail"
NEDlUrl="http://music.163.com/song/media/outer/url?id="
NEPicUrl=""
arg1="$1"
arg2="$2"
arg3="$3"
case "$arg1" in
	-qq) source="qq" ;;
	-ne) source="ne" ;;
	*) source="qq" && arg3="$arg2" && arg2="$arg1" ;;
esac
dlkey="$arg2"
[[ -z "$arg3" ]] && dlpath="." || dlpath="$arg3"
[[ ! -d "$dlpath" ]] && mkdir -p "$dlpath"
dlkey="$(echo $dlkey | sed -e 's/ /%20/g')"
#歌曲信息
songid=""
songmid=""
albummid=""
title=""
time=""
artist=""
albummid=""
albumtitle=""
genre=""
songalias=""
vkey=""
savename=""
quality="M800,M500,C400"
alias curl="curl --user-agent 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1'"

#传入参数，搜索内容
function getQQSongMid() {
	local SearchData="$(curl -s --referer 'http://m.y.qq.com' "$QQSearchUrl$dlkey" | jq '.data.song.list[0]')"
	[ $? -ne 0 ] && echo "链接失效，无法获取获取信息！" && exit
	# songid="$(echo "$SearchData" | jq '.songid')"
	songmid="$(echo "$SearchData" | jq '.songmid')"
	# albummid="$(echo "$SearchData" | jq '.albummid')"
	songmid="$(dealStr "$songmid")"
	# albummid=$(dealStr $albummid)
}

#传入参数，歌曲mid
function getQQSongInfo() {
	[[ -z "$1" ]] && echo "未识别出歌曲id！" && exit
	local SongData="$(curl -s "$QQSongInfoUrl$1" | jq '.data[0]')"
	[[ "$SongData" == "null" ]] && echo "未找到歌曲信息！" && exit
	title="$(echo "$SongData" | jq '.title')"
	time="$(echo "$SongData" | jq '.time_public')"
	for i in $(seq 0 4)	
	do
		tmp="$(echo "$SongData" | jq ".singer[$i].title")"
		if [ $? -eq 0 ]; then
			[[ "$tmp" == "null" ]] && break
			[[ -z "$artist" ]] && artist="$tmp" || artist="$artist","$tmp"
		fi
	done
	albumtitle="$(echo "$SongData" | jq '.album.title')"
	albummid="$(echo "$SongData" | jq '.album.mid')"
	tmp="$(echo "$SongData" | jq '.genre')"
	genre="$(getGenre "$tmp")"
	vkey="$(curl -s "$QQKeyUrl" | jq '.key')"
	#处理字符引号
	title="$(dealStr "$title")"
	time="$(dealStr "$time")"
	artist="$(dealStr "$artist")"
	albumtitle="$(dealStr "$albumtitle")"
	albummid="$(dealStr "$albummid")"
	vkey="$(dealStr "$vkey")"
}

# 获取歌曲类型，传入参数类型id
function getGenre() {
	case "$1" in
		1) echo "Pop";;
		19) echo "Country" ;;
		20) echo "Dance" ;;
		22) echo "Electronica" ;;
		23) echo "Folk" ;;
		34) echo "Rap/Hip Hop" ;;
		36) echo "Rock" ;;
		37) echo "Soundtrack" ;;
		39) echo "World Music" ;;
		*) echo "Pop";;
	esac
}

#文件下载，传入参数，1.下载路径，2.下载地址
function fileDl() {
	result=$(curl -skL -w %{http_code} -o "$1" "$2")
	if [[ "$result" == "200" ]]; then
		return 0 
	else
		[[ -f "$1" && ! -z "$1" ]] && rm -rf "$1"
		return 1
	fi
}

#去掉文字中的引号
function dealStr() {
	echo "$1" | sed -e "s/\"//g"
}

function addSongInfo() {

	lame -b 512 --tt "$title" --ta "$artist" --tl "$albumtitle" --ty "$time" --tc "$songalias" --tg "$genre" --ti "$savename.jpg" "$savename.mp3" &> /dev/null
	[ $? -eq 0 ] && mv "$savename".mp3.mp3 "$savename".mp3
	rm -rf "$savename".jpg

}

function qqSongDl() {
	savename=""$dlpath"/"$title" - "$artist""
	echo "开始下载歌曲【"$title" - "$artist"】..."
	for i in $(seq 1 3)
	do
		song_quality="$(echo $quality | cut -d',' -f"$i")"
		local SongUrl="$QQDlUrl/$song_quality$songmid.mp3?vkey=$vkey&guid=$guid&fromtag=1"
		fileDl "$savename.mp3" "$SongUrl"
		if [ $? -eq 0 ]; then
			break
		else
			[[ "$i" == '3' ]] && echo "歌曲下载失败！" && exit
		fi
	done
	#下载专辑图
	fileDl "$savename.jpg" "$QQPicUrl$albummid.jpg"
	[ $? -ne 0 ] && echo "歌曲专辑图下载失败！" && exit
}

function neSongDl() {
	savename=""$dlpath"/"$title" - "$artist""
	echo "开始下载歌曲【"$title" - "$artist"】..."
	fileDl "$savename.mp3" "$NEDlUrl$songid.mp3"
	[ $? -ne 0 ] && echo "歌曲下载失败！" && exit
	fileDl "$savename.jpg" "$NEPicUrl?param=300x300"
	[ $? -ne 0 ] && echo "歌曲专辑图下载失败！" && exit
}

function qqMusicDl() {

	if [[ -z "$(echo $dlkey | grep "^http.*")" ]]; then
		getQQSongMid
	else
		songmid="$(echo "$dlkey" | sed -e "s/http.*song\///" -e "s/\.html.*$//")"
	fi
	getQQSongInfo "$songmid"
	qqSongDl
	addSongInfo

}

function neMusicDl() {

	if [[ -z "$(echo $dlkey | grep "^http.*")" ]]; then
		getNESongId 
	else
		songid="$(echo "$dlkey" | sed -e "s/^.*id=//")"
	fi
	getNESongInfo "$songid"
	neSongDl
	addSongInfo

}

function getNESongId() {

	local SongData="$(curl -s -X POST "$NESearchUrl$dlkey" | jq '.result.songs[0]')"
	[[ "$SongData" == "null" ]] && echo "未找到歌曲信息！" && exit
	songid="$(echo "$SongData" | jq '.id')"

}

#传入参数 songid
function getNESongInfo() {

	local SongData="$(curl -s -d "id=$1&ids=[$1]" "$NESongUrl" | jq '.songs[0]')"
	[[ "$SongData" == "null" ]] && echo "未找到歌曲信息！" && exit
	title="$(echo "$SongData" | jq '.name')"
	songid="$(echo "$SongData" | jq '.id')"
	for i in $(seq 0 4)	
	do
		tmp="$(echo "$SongData" | jq ".artists[$i].name")"
		if [ $? -eq 0 ]; then
			[[ "$tmp" == "null" ]] && break
			[[ -z "$artist" ]] && artist="$tmp" || artist="$artist","$tmp"
		fi
	done

	songalias="$(echo "$SongData" | jq '.alias[0]')"
	albumtitle="$(echo "$SongData" | jq '.album.name')"
	NEPicUrl="$(echo "$SongData" | jq '.album.picUrl')"
	
	title="$(dealStr "$title")"
	artist="$(dealStr "$artist")"
	songalias="$(dealStr "$songalias")"
	albumtitle="$(dealStr "$albumtitle")"
	NEPicUrl="$(dealStr "$NEPicUrl")"
	[[ "$songalias" == "null" ]] && songalias=""

}

function help() {
	echo "Usage: $0 [-ne|-qq] {name/url} [save path]"
	echo "Option:"
	echo "\t-ne\tDownload from netease music"
	echo "\t-qq\tDownload from qq music(default)"
	echo "Example:"
	echo "\t$0 \"不要说话 陈奕迅\""
	echo "\t$0 \"不要说话\" \"./music\""
	echo "\t$0 -ne \"不要说话\""
	echo "\t$0 \"https://y.qq.com/n/yqq/song/002B2EAA3brD5b.html\""
}

function main() {
	[[ -z "$(which jq)" ]] && echo "请安装jq工具，用于解析json数据" && exit
	[[ -z "$(which lame)" ]] && echo "请安装lame工具，用于写入歌曲信息" && exit
	[[ -z "$arg1" ]] && help && exit
	[[ "$source" == "qq" ]] && qqMusicDl || neMusicDl	
}

main
