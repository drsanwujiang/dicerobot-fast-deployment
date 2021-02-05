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
printf "这一步可能需要数分钟时间，请耐心等待……\n"

apt-get -qq update > /dev/null 2>&1
apt-get -y -qq install apt-transport-https ca-certificates curl software-properties-common lsb-release > /dev/null 2>&1
wget -q -O /etc/apt/trusted.gpg.d/PHP.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://mirror.xtom.com.hk/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/PHP.list
apt-get -qq update > /dev/null 2>&1
apt-get -y -qq install php7.4-cli php7.4-json php7.4-mbstring php7.4-zip php7.4-dev php-pear > /dev/null 2>&1

if ! (php -v > /dev/null 2>&1); then
  process_failed "PHP 安装失败"
fi

apt-get -y -qq install libcurl4-openssl-dev > /dev/null 2>&1
printf "yes\nyes\nyes\nyes\nyes\nyes\n" | pecl install https://dl.drsanwujiang.com/dicerobot/swoole.tgz > /dev/null 2>&1
echo "extension=swoole.so" > /etc/php/7.4/mods-available/swoole.ini
ln -s /etc/php/7.4/mods-available/swoole.ini /etc/php/7.4/cli/conf.d/20-swoole.ini

if ! (php --ri swoole > /dev/null 2>&1); then
  process_failed "Swoole 安装失败"
fi

printf "\nDone\n\n"

# Deploy Mirai
printf "\033[32m3. 部署 Mirai\033[0m\n"

wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key --quiet add - > /dev/null 2>&1
echo "deb https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/deb $(lsb_release -sc) main" > /etc/apt/sources.list.d/AdoptOpenJDK.list
apt-get -qq update > /dev/null 2>&1
apt-get -y -qq install adoptopenjdk-11-hotspot unzip > /dev/null 2>&1

if ! (java --version > /dev/null 2>&1); then
  process_failed "Java 安装失败"
fi

wget -q https://dl.drsanwujiang.com/dicerobot/dicerobot3-mirai.zip
mkdir mirai
unzip -qq dicerobot3-mirai.zip -d mirai
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
cors:
  - '*'
host: 0.0.0.0
port: 8080
authKey: 12345678
cacheSize: 4096
enableWebsocket: false
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
  extraHeaders: {}

heartbeat:
  enable: true
  delay: 1000
  period: 300000
  destinations: [
    "http://127.0.0.1:9500/heartbeat"
  ]
  extraBody: {}
  extraHeaders: {}
EOF
rm -f dicerobot3-mirai.zip

printf "\nDone\n\n"

# Deploy DiceRobot
printf "\033[32m4. 部署 DiceRobot\033[0m\n"

php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');"
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
composer --no-interaction --quiet create-project drsanwujiang/dicerobot-skeleton:3.0.0-alpha dicerobot --no-dev
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
