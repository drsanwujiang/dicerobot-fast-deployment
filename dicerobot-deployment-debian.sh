#!/bin/bash

printf "======================================================================================================\n"
printf "                                         DiceRobot 快速部署脚本\n"
printf "                                    DiceRobot Fast Deployment Script\n"
printf "======================================================================================================\n\n"

function input_info() {
    printf "1) 输入 QQ 账号信息 / Input QQ account information\n"
    printf "此脚本支持同时部署多个机器人，请依次输入机器人的 QQ 和密码。QQ 号为空则结束输入。 / This script\n"
    printf "supports the simultaneous deployment of several robots, please successively input the QQ ID and\n"
    printf "password of the robot. If the QQ ID is empty, the input will end.\n\n"

    while true
    do
        robot_count=0
        current_novnc_port=2333
        current_http_api_port=5700
        qq_id=()
        qq_password=()
        novnc_port=()
        http_api_port=()

        while true
        do
            read -p "请输入第 $(($robot_count+1)) 个机器人的 QQ 号码： / Please input the QQ ID of No.$(($robot_count+1)) robot: " input_qq_id

            if  [ ! -n "$input_qq_id" ]; then
                break
            else
                qq_id[$robot_count]=$input_qq_id
            fi

            read -p "请输入第 $(($robot_count+1)) 个机器人的 QQ 密码： / Please input the QQ password of No.$(($robot_count+1)) robot: " qq_password[robot_count]
            novnc_port[$robot_count]=$current_novnc_port
            http_api_port[$robot_count]=$current_http_api_port
            let robot_count++
            let current_novnc_port++
            let current_http_api_port++
        done

        printf "\n****************************************\n"
        printf "%-15s   %-20s\n" " QQ 号码" "  QQ 密码"
        printf "%-15s   %-20s\n" "QQ Account" "QQ Password"
        printf "****************************************\n"

        for ((i=0; i<$robot_count; i++))
        do
            printf "%-15s   %-20s\n" "${qq_id[$i]}" "${qq_password[$i]}"
        done

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

function install_docker() {
    printf "2) 安装 Docker / Install Docker\n"
    printf "这一步可能需要数分钟时间，请耐心等待…… / This step may take several minutes, please wait...\n"

    sudo apt update >> /dev/null
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release unzip >> /dev/null
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | sudo apt-key add - >> /dev/null
    sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/debian $(lsb_release -cs) stable"
    sudo apt update >> /dev/null
    sudo apt install -y docker-ce >> /dev/null
    systemctl enable docker >> /dev/null
    systemctl start docker >> /dev/null
    sudo cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ]
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sudo docker pull solarkennedy/wine-x11-novnc-docker >> /dev/null
    docker_ip4=$(ip -o -4 addr list docker0 | awk '{print $4}' | cut -d/ -f1)

    printf "\nDone\n\n"
}

function install_apache_and_php() {
    printf "3) 安装 Apache 及 PHP / Install Apache and PHP\n"

    wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://mirror.xtom.com.hk/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    sudo apt update >> /dev/null
    sudo apt install -y apache2 php7.4 php7.4-curl php7.4-json php7.4-mbstring >> /dev/null
    sudo cat > /etc/apache2/sites-available/dicerobot.conf << EOF
<VirtualHost ${docker_ip4}:80>
	ServerName ${docker_ip4}
	DocumentRoot /var/www/dicerobot/

	ErrorLog \${APACHE_LOG_DIR}/dicerobot.error.log
	CustomLog \${APACHE_LOG_DIR}/dicerobot.access.log combined
</VirtualHost>
EOF
    a2ensite dicerobot.conf >> /dev/null
    systemctl restart apache2

    printf "\nDone\n\n"
}

function deploy_mirai() {
    printf "4) 部署 Mirai / Deploy Mirai\n"

    wget -q -O /root/Mirai-Windows.zip https://dl.drsanwujiang.com/dicerobot/Mirai-Windows.zip

    for ((i=0; i<$robot_count; i++))
    do
        sudo mkdir /root/mirai-${qq_id[$i]}
        sudo docker run -d --name mirai-${qq_id[$i]} -v /root/mirai-${qq_id[$i]}:/home/mirai -p ${novnc_port[$i]}:8080 -p ${http_api_port[$i]}:5700 solarkennedy/wine-x11-novnc-docker >> /dev/null
        unzip /root/Mirai-Windows.zip -d /root/mirai-${qq_id[$i]} >> /dev/null
        sudo cat > /root/mirai-${qq_id[$i]}/plugins/CQHTTPMirai/setting.yml << EOF
debug: false
'${qq_id[$i]}':
  cacheImage: false
  heartbeat:
    enable: true
    interval: 300000
  http:
    enable: true
    host: 0.0.0.0
    port: 5700
    accessToken: ""
    postUrl: "http://${docker_ip4}/${qq_id[$i]}/dicerobot.php"
    postMessageFormat: string
EOF
        echo "login ${qq_id[$i]} ${qq_password[$i]}" >> /root/mirai-${qq_id[$i]}/config.txt
    done

    rm /root/Mirai-Windows.zip

    printf "\nDone\n\n"
}

function deploy_dicerobot() {
    printf "5) 部署 DiceRobot / Deploy DiceRobot\n"

    sudo mkdir /var/www/dicerobot

    for ((i=0; i<$robot_count; i++))
    do
        sudo mkdir /var/www/dicerobot/${qq_id[$i]}
        sudo chmod 777 /var/www/dicerobot/${qq_id[$i]}
        git clone -q https://github.com.cnpmjs.org/drsanwujiang/DiceRobot.git /var/www/dicerobot/${qq_id[$i]}
        sed -i "1a\const HTTP_API_PORT = ${http_api_port[$i]};" /var/www/dicerobot/${qq_id[$i]}/custom_settings.php
    done

    printf "\nDone\n\n"
}

function finished_info() {
    printf "======================================================================================================\n\n"
    printf "请记录以下信息： / Please record the following information:\n"
    printf "**************************************************\n"
    printf "%-15s   %-12s   %-15s\n" "  机器人 QQ 号码" "noVNC 端口" "HTTP API 端口"
    printf "%-15s   %-12s   %-15s\n" "Robot's QQ Account" "noVNC Port" "HTTP API Port"
    printf "**************************************************\n"

    for ((i=0; i<$robot_count; i++))
    do
        printf "%-15s   %-12s   %-15s\n" "${qq_id[$i]}" "${novnc_port[$i]}" "${http_api_port[$i]}"
    done

    printf "**************************************************\n\n"
    printf "DiceRobot 及其运行环境已经部署完毕，接下来请依照说明文档运行 Mirai 即可。\n"
    printf "DiceRobot and runtime environment has been deployed. Follow the documentation to run Mirai.\n\n"
}

function start_deployment() {
    input_info
    install_docker
    install_apache_and_php
    deploy_mirai
    deploy_dicerobot
    finished_info
}

# Deployment begin
start_deployment