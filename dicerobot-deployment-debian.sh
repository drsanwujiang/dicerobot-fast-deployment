#!/bin/bash

printf "======================================================================================================\n"
printf "                                         DiceRobot 快速部署脚本\n"
printf "                                    DiceRobot Fast Deployment Script\n"
printf "======================================================================================================\n\n"

function input_info() {
    printf "1) 输入 QQ 账号信息 / Input QQ account information\n"
    printf "supports the simultaneous deployment of several robots, please successively input the QQ ID and\n"

    while true
    do
        read -p "请输入机器人的 QQ 号码： / Please input the QQ ID of robot: " qq_id
        read -p "请输入机器人的 QQ 密码： / Please input the QQ password of robot: " qq_password

        printf "\n****************************************\n"
        printf "%-15s   %-20s\n" " QQ 号码" "  QQ 密码"
        printf "%-15s   %-20s\n" "QQ Account" "QQ Password"
        printf "****************************************\n"
        printf "%-15s   %-20s\n" "${qq_id}" "${qq_password}"
        printf "****************************************\n"
        read -r -p "请确认以上信息是否正确？ / Is the input information correct? [Y/N] " is_correct
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
}

function install_php_and_swoole() {
    printf "2) 安装 PHP 和 Swoole / Install PHP and Swoole\n"
    printf "这一步可能需要数分钟时间，请耐心等待…… / This step may take several minutes, please wait...\n"

    apt update >> /dev/null
    apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release unzip >> /dev/null
    wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://mirror.xtom.com.hk/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/PHP.list
    apt update >> /dev/null
    apt install -y php7.4-cli php7.4-json php7.4-dev php-pear >> /dev/null
    printf "yes\nyes\nyes\nno\n" | pecl install https://dl.drsanwujiang.com/dicerobot/swoole.tgz
    echo "extension=swoole.so" > /etc/php/7.4/mods-available/20-swoole.ini
    ln -s /etc/php/7.4/mods-available/20-swoole.ini /etc/php/7.4/cli/conf.d/20-swoole.ini

    printf "\nDone\n\n"
}

function deploy_mirai() {
    printf "4) 部署 Mirai / Deploy Mirai\n"

    wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add - >> /dev/null
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/deb $(lsb_release -sc) main" > /etc/apt/sources.list.d/AdoptOpenJDK.list
    apt update >> /dev/null
    apt install -y adoptopenjdk-11-hotspot >> /dev/null
    wget -q https://dl.drsanwujiang.com/dicerobot/mirai.zip
    mkdir mirai
    unzip mirai.zip -d /root/mirai >> /dev/null
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
    rm mirai.zip

    printf "\nDone\n\n"
}

function deploy_dicerobot() {
    printf "5) 部署 DiceRobot / Deploy DiceRobot\n"

    php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');"
    php composer-setup.php
    mv composer.phar /usr/local/bin/composer
    rm composer-setup.php
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
    composer selfupdate
    composer create-project drsanwujiang/dicerobot:2.0.0-alpha

    printf "\nDone\n\n"
}

function setup_services() {
    printf "6) 设置服务 / Setup services\n"

    work_path=$(pwd)
    cat > /etc/systemd/system/mirai.service << EOF
[Unit]
Description=Mirai Console
After=network.target
After=syslog.target

[Service]
Type=simple
ExecStart=/bin/java -cp "${work_path}/mirai/libs/*" net.mamoe.mirai.console.pure.MiraiConsolePureLoader $*

[Install]
WantedBy=multi-user.target

EOF
    cat > /etc/systemd/system/dicerobot.service << EOF
[Unit]
Description=A TRPG dice robot based on Swoole.
After=network.target
After=syslog.target

[Service]
Type=simple
LimitNOFILE=65535
ExecStart=/usr/bin/php ${work_path}/dicerobot/dicerobot.php

[Install]
WantedBy=multi-user.target

EOF
    systemctl daemon-reload

    printf "\nDone\n\n"
}

function finished_info() {
    printf "======================================================================================================\n\n"
    printf "DiceRobot 及其运行环境已经部署完毕，接下来请依照说明文档运行 DiceRobot 及 Mirai 即可。\n"
    printf "DiceRobot and runtime environment has been deployed. Follow the documentation to run DiceRobot and Mirai.\n\n"
}

function start_deployment() {
    input_info
    install_php_and_swoole
    deploy_mirai
    deploy_dicerobot
    setup_services
    finished_info
}

# Deployment begin
start_deployment