

cd $home ; mkdir -p liverecord ; cd liverecord #新建liverecord的安装目录

cur_dir="$(pwd)" #定义当前路径

[[ -d livedl ]] || [[ -f livedl ]] && echo "请使用`sudo rm -rf livedl`指令删除livedl文件或文件夹后重试" && exit 1 #git clone需要空文件夹

sudo apt update #更新库
sudo apt install -y curl ffmpeg git build-essential default-jre unzip python3 python3-pip python3-setuptools #安装所需库

#安装python3相关录制工具
python3 -m pip install --user --upgrade pip
pip3 install --user --upgrade git+https://github.com/streamlink/streamlink.git
pip3 install --user --upgrade git+https://github.com/ytdl-org/youtube-dl.git
pip3 install --user --upgrade git+https://github.com/soimort/you-get.git
echo 'export PATH=$PATH:/usr/local/bin'>>~/.bashrc #修改默认环境变量，如不希望可以注释掉
echo 'export PATH=$HOME/.local/bin:$PATH'>>~/.bashrc #因为加了 --user 参数，所以要再加上一个环境变量使得pip安装的包可以正常运行
export PATH=$PATH:/usr/local/bin
export PATH=$HOME/.local/bin:$PATH
source ~/.bashrc

#安装go语言环境
sudo rm -rf $(go env GOROOT) #如果有已经安装的go环境，先卸载，新老版本会有冲突，如不希望可以注释掉
curl -OJL https://golang.org/dl/go1.17.5.linux-amd64.tar.gz #安装go环境，如不希望可以注释掉
sudo tar -C /usr/local -xzf go1.17.5.linux-amd64.tar.gz ; rm go1.17.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin'>>~/.bashrc #修改默认环境变量，如不希望可以注释掉
export PATH=$PATH:/usr/local/go/bin

#编译安装livedl
cd ${cur_dir}
echo "此处可能需要较长时间，请耐心等待"
git clone https://github.com/nnn-revo2012/livedl.git ; 
if [ ! -d "livedl" ]; then
    echo "livedl 项目文件夹不存在，请确认该项目的github仓库 https://github.com/nnn-revo2012/livedl 是否被删除"
    exit 1
else
    cd livedl/src ; go build -o livedl livedl.go ; rm -r `ls | grep -v "^livedl$"`
fi

#安装BilibiliLiveRecorder
cd ${cur_dir}
mkdir -p BilibiliLiveRecorder ; cd BilibiliLiveRecorder ; 
curl -OJL https://github.com/nICEnnnnnnnLee/BilibiliLiveRecorder/releases/download/V2.16.0/BilibiliLiveRecord.v2.16.0.zip ; unzip BilibiliLiveRecord.v2.16.0.zip
rm BilibiliLiveRecord.v2.15.0.zip

#下载录制脚本并赋予权限
cd ${cur_dir}
mkdir -p record
curl https://raw.githubusercontent.com/lovezzzxxx/liverecord/master/record.sh > record/record.sh ; chmod +x record/record.sh
curl https://raw.githubusercontent.com/lovezzzxxx/liverecord/master/record_new.sh > record/record_new.sh ; chmod +x record/record_new.sh
curl https://raw.githubusercontent.com/lovezzzxxx/liverecord/master/record_twitcast.py > record/record_twitcast.py; chmod +x record/record_twitcast.py

#配置自动上传
cd ${cur_dir}
curl https://rclone.org/install.sh | bash #配置rclone自动上传
sudo curl -O https://raw.githubusercontent.com/MoeClub/OneList/master/OneDriveUploader/amd64/linux/OneDriveUploader -o /usr/local/bin #配置onedrive自动上传
sudo chmod +x /usr/local/bin/OneDriveUploader
go install github.com/qjfoidnh/BaiduPCS-Go@latest #配置百度云自动上传
echo 'export PATH=$PATH:'`echo ~`'/go/bin'>>~/.bashrc #修改默认环境变量，如不希望可以注释掉
source ~/.bashrc

#提示登陆
echo '请手动运行`source ~/.bashrc`或者重新链接ssh更新环境变量使下列命令生效'
echo '使用`rclone config`登陆rclone'
echo '使用`OneDriveUploader -cn -a "打开https://github.com/MoeClub/OneList/tree/master/OneDriveUploader中的相应网页并登录后浏览器地址栏返回的url"`登陆rclone'
echo '使用`BaiduPCS-Go login -bduss="百度网盘网页cookie中bduss项的值"`登陆BaiduPCS-Go，'
