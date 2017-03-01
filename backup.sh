#!/bin/bash

#备份网站相关配置
web_path='/data/htdocs/'                    #网站文件路径
conf_path='/usr/local/nginx/conf/vhost/'    #nginx配置文件路径
username='mysql-user'              #数据库用户名                     
password='mysql-password' #数据库密码
target_path='/data/wwwbak/backup_files/' #要备份到哪个目录，此目录会自动创建


#服务器互相备份
#上传远程服务器FTP配置
ftp_ip=('120.1.21.62' '116.2.134.201' '120.15.18.116')
ftp_port=('21' '21' '21')
ftp_username=('backup' 'backup_user' 'backup_xxx')
ftp_password=('bakpwd' 'bakpwd' 'bakpwd')

#备份目录
back_path=$target_path`date +%Y-%m-%d/`
[ !-d $back_path]&&mkdir -p $back_path

#备份配置文件
function backup_conf(){
   \cp -R ${conf_path}* $back_path
}
#备份数据库
function backup_database()
{
    webs=$(ls -l $web_path |awk '/^d/ {print $NF}')
    for i in $webs
    do
        dbname=$(cat $web_path$i'/data/common.inc.php' 2>>error.log|grep 'cfg_dbname'|awk -F "'"  '{print $2}')
        mysqldump -u$username -p$password -B $dbname -lF>$back_path$dbname".sql" 2>>error.log
        [ $? -ne 0 ]&&rm -rf $back_path$dbname".sql" 2>>error.log
    done
}
#备份网站文件
function backup_website(){
    #Delete backup files for more than 7 days
    find $target_path -type d -mtime +5 | xargs rm -rf
    #Delete empty directory
    target_directory=$(ls $target_path)
    for j in $target_directory
    do
        file_count=$(ls $target_path$j|wc -l)
        [ $file_count -eq 0 ]&&rm -rf $target_path$j
    done
    webs=$(ls -l $web_path |awk '/^d/ {print $NF}')
    for i in $webs
    do
        rm -rf ${web_path-/tmp/}${i}/data/tplcache 2>>error.log
        mkdir ${web_path}${i}/data/tplcache 2>>error.log
        chmod -R 777 ${web_path}${i}/data/tplcache 2>>error.log
        find ${web_path-/tmp/}$i -size +15M -exec rm -rf {} \;
        tar -zcf ${back_path}$i".tar.gz" -C ${web_path} $i 2>>error.log
    done
}

function upftp(){
local_ip=`cat /etc/sysconfig/network-scripts/ifcfg-eth1|grep IPADDR|awk -F "=" '{print $2}'`
ftp -v -n $1 $2 <<EOF
user $3 $4
binary
mkdir $local_ip
cd $local_ip
lcd $back_path
prompt
mput $5
close
bye
EOF
}
function upload(){
    for((i=0;i<`echo ${#ftp_ip[@]}`;i++)){
        upftp ${ftp_ip[$i]} ${ftp_port[$i]} ${ftp_username[$i]} ${ftp_password[$i]} ${1-"*"}
    }
}

if [ "$1" == 'ftp' ];then
    touch ${back_path}test.file
    upload "test.file"
else
    backup_conf
    backup_database
    backup_website
    upload
fi

