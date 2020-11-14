#!/bin/bash

function exceptional_termination() {
  printf "======================================================================================================\n\n"
  printf "脚本意外终止\n"
  exit 1
}

printf "======================================================================================================\n"
printf "\033[32m                                         DiceRobot 快速部署脚本\033[0m\n"
printf "======================================================================================================\n\n"

# Check privilege
if [[ $EUID -ne 0 ]]; then
  printf "\033[31m请使用 sudo 权限运行此脚本\033[0m\n\n"
  exceptional_termination
fi

# Input QQ account profile
printf "\033[32m1. 输入 QQ 账号信息\033[0m\n"

while true
do
  read -p "请输入机器人的 QQ 号码: " qq_id
  read -p "请输入机器人的 QQ 密码: " qq_password

  printf "\n****************************************\n"
  printf "%-15s   %-20s\n" " QQ 号码" "   QQ 密码"
  printf "****************************************\n"
  printf "%-15s   %-20s\n" "${qq_id}" "${qq_password}"
  printf "****************************************\n"
  read -r -p "请确认以上信息是否正确？ [Y/N] " is_correct
  printf "\n"

  case $is_correct in
    [yY][eE][sS]|[yY])
      break
      ;;

    *)
      ;;
  esac
done

printf "Done\n\n"

# Install PHP and Swoole
printf "\033[32m2. 安装 PHP 和 Swoole\033[0m\n"
printf "这一步可能需要数分钟时间，请耐心等待……\n"

dnf install -y -q epel-release >> /dev/null
sed -e 's!^metalink=!#metalink=!g' -e 's!^#baseurl=!baseurl=!g' -e 's!//download.fedoraproject.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' -e 's!http://mirrors.tuna!https://mirrors.tuna!g' -i /etc/yum.repos.d/epel*
dnf install -y -q https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-8.rpm >> /dev/null
sed -e 's!^mirrorlist=!#mirrorlist=!g' -e 's!^#baseurl=!baseurl=!g' -e 's!http://rpms.remirepo.net!https://mirrors.tuna.tsinghua.edu.cn/remi!g' -i /etc/yum.repos.d/remi*
dnf makecache -q >> /dev/null
dnf module enable -y -q php:remi-7.4 >> /dev/null
dnf install -y -q php-cli php-json php-zip php-devel php-pear >> /dev/null
printf "yes\nyes\nyes\nno\n" | pecl install https://dl.drsanwujiang.com/dicerobot/swoole.tgz >> /dev/null
echo "extension=swoole.so" > /etc/php.d/20-swoole.ini

printf "\nDone\n\n"

# Deploy Mirai
printf "\033[32m3. 部署 Mirai\033[0m\n"

cat > /etc/yum.repos.d/AdoptOpenJDK.repo << EOF
[AdoptOpenJDK]
name=AdoptOpenJDK
baseurl=https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/rpm/centos\$releasever-\$basearch/
enabled=1
gpgcheck=1
gpgkey=https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
EOF
dnf makecache -q >> /dev/null
dnf install -y -q adoptopenjdk-11-hotspot unzip >> /dev/null
wget -q https://dl.drsanwujiang.com/dicerobot/mirai.zip
mkdir mirai
unzip mirai.zip -d mirai >> /dev/null
cat > mirai/config/Console/AutoLogin.yml << EOF
plainPasswords:
${qq_id}: ${qq_password}
EOF
cat > mirai/config/MiraiApiHttp/setting.yml << EOF
host: 0.0.0.0
port: 8080
authKey: 12345678

report:
enable: true
groupMessage:
report: true
friendMessage:
report: true
tempMessage:
report: true
eventMessage:
report: true
destinations: [
"http://127.0.0.1:9500/report"
]

heartbeat:
enable: true
delay: 1000
period: 300000
destinations: [
"http://127.0.0.1:9500/heartbeat"
]
EOF
rm -rf mirai.zip

printf "\nDone\n\n"

# Deploy DiceRobot
printf "\033[32m4. 部署 DiceRobot\033[0m\n"

php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');"
php composer-setup.php --quiet
rm -f composer-setup.php
mv -f composer.phar /usr/local/bin/composer

if !(composer -V >/dev/null 2>&1); then
  mv -f /usr/local/bin/composer /usr/bin/composer
fi

composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ --no-interaction --quiet
composer create-project drsanwujiang/dicerobot-skeleton dicerobot --no-dev --no-interaction --quiet
sed -i "0,/10000/{s/10000/"${qq_id}"/}" dicerobot/config/custom_config.php

printf "\nDone\n\n"

# Setup services
printf "\033[32m5. 设置服务\033[0m\n"

work_path=$(pwd)
cat > /etc/systemd/system/dicerobot.service << EOF
[Unit]
Description=A TRPG dice robot based on Swoole
After=network.target
After=syslog.target
Before=mirai.service

[Service]
User=$(id -un)
Group=$(id -gn)
Type=simple
ExecStart=/usr/bin/php ${work_path}/dicerobot/dicerobot.php
ExecReload=/bin/kill -12 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/mirai.service << EOF
[Unit]
Description=Mirai Console
After=network.target
After=syslog.target
After=dicerobot.service

[Service]
Type=simple
WorkingDirectory=${work_path}/mirai
ExecStart=/bin/bash ${work_path}/mirai/start-mirai.sh
ExecStop=/bin/bash ${work_path}/mirai/stop-mirai.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

printf "\nDone\n\n"

# Normal termination
printf "======================================================================================================\n\n"
printf "DiceRobot 及其运行环境已经部署完毕，接下来请依照说明文档运行 DiceRobot 及 Mirai 即可\n"
