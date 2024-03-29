#!/bin/bash

function exceptional_termination() {
  printf "======================================================================================================\n\n"
  printf "脚本意外终止\n"
  exit 1
}

function process_failed() {
  printf "\033[31m%s\033[0m\n\n" "$1"
  exceptional_termination
}

printf "======================================================================================================\n"
printf "\033[32m                                         DiceRobot 快速部署脚本\033[0m\n"
printf "======================================================================================================\n\n"

# Check privilege
if [[ $EUID -ne 0 ]]; then
  process_failed "请使用 sudo 权限运行此脚本"
fi

# Input QQ account profile
printf "\033[32m1. 输入 QQ 账号信息\033[0m\n"

while true
do
  read -r -p "请输入机器人的 QQ 号码: " qq_id
  read -r -p "请输入机器人的 QQ 密码: " qq_password

  printf "\n****************************************\n"
  printf "%-15s   %-20s\n" " QQ 号码" "   QQ 密码"
  printf "****************************************\n"
  printf "%-15s   %-20s\n" "${qq_id}" "${qq_password}"
  printf "****************************************\n"
  printf "\033[33m请确认以上信息是否正确？\033[0m [Y/N] "
  read -r is_correct
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
printf "这一步可能需要数分钟，取决于你的网络，请耐心等待……\n"

dnf -y -q install epel-release > /dev/null 2>&1
sed -e 's!^metalink=!#metalink=!g' -e 's!^#baseurl=!baseurl=!g' -e 's!//download.fedoraproject.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' -e 's!http://mirrors.tuna!https://mirrors.tuna!g' -i /etc/yum.repos.d/epel*
dnf -y -q install https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-8.rpm > /dev/null 2>&1
sed -e 's!^mirrorlist=!#mirrorlist=!g' -e 's!^#baseurl=!baseurl=!g' -e 's!http://rpms.remirepo.net!https://mirrors.tuna.tsinghua.edu.cn/remi!g' -i /etc/yum.repos.d/remi*
dnf -q makecache > /dev/null 2>&1
dnf -y -q module enable php:remi-7.4 > /dev/null 2>&1
dnf -y -q install php-cli php-curl php-json php-mbstring php-zip php-devel php-pear > /dev/null 2>&1

if ! (php -v > /dev/null 2>&1); then
  process_failed "PHP 安装失败"
fi

dnf -y -q install curl-devel
printf "yes\nyes\nyes\nno\nyes\nyes\n" | pecl install https://dl.drsanwujiang.com/dicerobot/swoole/swoole-4.7.1.tgz > /dev/null 2>&1
echo "extension=swoole.so" > /etc/php.d/20-swoole.ini

if ! (php --ri swoole > /dev/null 2>&1); then
  process_failed "Swoole 安装失败"
fi

printf "\nDone\n\n"

# Deploy Mirai
printf "\033[32m3. 部署 Mirai\033[0m\n"
printf "这一步可能需要数分钟，取决于你的网络，请耐心等待……\n"

cat > /etc/yum.repos.d/AdoptOpenJDK.repo <<EOF
[AdoptOpenJDK]
name=AdoptOpenJDK
baseurl=https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/rpm/centos\$releasever-\$basearch/
enabled=1
gpgcheck=1
gpgkey=https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
EOF
dnf -q makecache > /dev/null 2>&1
dnf -y -q install adoptopenjdk-11-hotspot unzip > /dev/null 2>&1

if ! (java --version > /dev/null 2>&1); then
  process_failed "Java 安装失败"
fi

wget -qO mirai.zip https://dl.drsanwujiang.com/dicerobot/mirai/mirai-mcl-2.3.1.zip

if [ $? -ne 0 ]; then
  process_failed "下载 Mirai 失败"
fi

mkdir -p mirai
unzip -qq -o mirai.zip -d mirai
rm -f mirai.zip

cat > mirai/config/Console/AutoLogin.yml <<EOF
accounts:
  -
    account: ${qq_id}
    password:
      kind: PLAIN
      value: ${qq_password}
    configuration:
      protocol: ANDROID_PHONE
EOF

cat > mirai/config/net.mamoe.mirai-api-http/setting.yml <<EOF
adapters:
  - http
  - webhook

enableVerify: false
verifyKey: 12345678

singleMode: true

cacheSize: 4096

adapterSettings:
  http:
    host: 127.0.0.1
    port: 8080
    cors:
      - *

  webhook:
    destinations:
      - "http://127.0.0.1:9500/report"
EOF

printf "\nDone\n\n"

# Deploy DiceRobot
printf "\033[32m4. 部署 DiceRobot\033[0m\n"

wget -qO composer-setup.php https://install.phpcomposer.com/installer
php composer-setup.php --quiet
rm -f composer-setup.php
mv -f composer.phar /usr/local/bin/composer

if ! (composer --no-interaction --version > /dev/null 2>&1); then
  mv -f /usr/local/bin/composer /usr/bin/composer
fi

if ! (composer --no-interaction --version > /dev/null 2>&1); then
  process_failed "Composer 安装失败"
fi

composer --no-interaction --quiet config -g repo.packagist composer https://mirrors.aliyun.com/composer/
mkdir -p dicerobot

if [ "$(ls -A dicerobot)" = "" ]; then
  composer --no-interaction --quiet create-project drsanwujiang/dicerobot-skeleton:3.1.0 dicerobot --no-dev

  if [ $? -ne 0 ]; then
    process_failed "部署 DiceRobot 失败"
  fi
else
  printf "\033[33m检测到 DiceRobot 目录不为空，更新 DiceRobot……\033[0m\n"

  wget -qO dicerobot-update.zip https://dl.drsanwujiang.com/dicerobot/skeleton-update/skeleton-update-3.1.0.zip

  if [ $? -ne 0 ]; then
    process_failed "下载 DiceRobot 更新包失败"
  fi

  unzip -qq -o dicerobot-update.zip -d dicerobot
  composer --no-interaction --quiet update --working-dir dicerobot --no-dev

  if [ $? -ne 0 ]; then
    process_failed "更新 DiceRobot 失败"
  fi
fi

sed -i "0,/10000/{s/10000/${qq_id}/}" dicerobot/config/custom_config.php

printf "\nDone\n\n"

# Setup services
printf "\033[32m5. 设置服务\033[0m\n"

work_path=$(pwd)
cat > /etc/systemd/system/dicerobot.service <<EOF
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
RestartSec=1s
RestartForceExitStatus=99

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/mirai.service <<EOF
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
