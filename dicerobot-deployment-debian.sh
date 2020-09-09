#!/bin/bash

echo "======================================================================================================"
echo "                                         DiceRobot 快速部署脚本"
echo "                                    DiceRobot Fast Deployment Script"
echo -e "======================================================================================================\n"

function input_info() {
    echo "1) 输入 QQ 账号信息 / Input QQ account information"

    read -p "   请输入机器人的 QQ 号码： / Please input the ID of your robot's QQ: " qq_id
    read -p "   请输入机器人的 QQ 密码： / Please input the password of your robot's QQ: " qq_password

    echo -e "Done\n"
}

function install_docker() {
    echo "2) 安装 Docker / Install Docker"
    echo "   这一步可能需要数分钟时间，请耐心等待…… / This step may take several minutes, please wait……"

    sudo apt update -qq >> /dev/null
    sudo apt install -y -qq apt-transport-https ca-certificates curl software-properties-common lsb-release >> /dev/null
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | sudo apt-key add - >> /dev/null
    sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/debian $(lsb_release -cs) stable"
    sudo apt update -qq >> /dev/null
    sudo apt install -y -qq docker-ce >> /dev/null
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
    sudo systemctl daemon-reload >> /dev/null
    sudo systemctl restart docker >> /dev/null
    sudo docker pull solarkennedy/wine-x11-novnc-docker >> /dev/null
    docker_ip4=$(ip -o -4 addr list docker0 | awk '{print $4}' | cut -d/ -f1)

    echo -e "Done\n"
}

function install_apache_and_php() {
    echo "3) 安装 Apache 及 PHP / Install Apache and PHP"

    wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://mirror.xtom.com.hk/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    sudo apt update -qq >> /dev/null
    sudo apt install -y -qq apache2 php7.4 php7.4-curl php7.4-json php7.4-mbstring >> /dev/null
    sudo cat > /etc/apache2/sites-available/dicerobot.conf << EOF
<VirtualHost ${docker_ip4}:80>
	ServerName ${docker_ip4}
	DocumentRoot /var/www/dicerobot/

	ErrorLog \${APACHE_LOG_DIR}/dicerobot.error.log
	CustomLog \${APACHE_LOG_DIR}/dicerobot.access.log combined
</VirtualHost>
EOF

    echo -e "Done\n"
}

function deploy_mirai() {
    echo "4) 部署 Mirai / Deploy Mirai"

    sudo mkdir /root/mirai
    sudo docker run -d --name mirai -v /root/mirai:/home/mirai -p 2333:8080 -p 5700:5700 solarkennedy/wine-x11-novnc-docker >> /dev/null
    sudo apt install unzip >> /dev/null
    wget -q -O /root/mirai/mirai.zip https://dl.drsanwujiang.com/dicerobot/mirai.zip
    unzip /root/mirai/mirai.zip -d /root/mirai >> /dev/null
    rm /root/mirai/mirai.zip
    sudo cat > /root/mirai/plugins/CQHTTPMirai/setting.yml << EOF
debug: false
'${qq_id}':
  cacheImage: false
  heartbeat:
    enable: true
    interval: 300000
  http:
    enable: true
    host: 0.0.0.0
    port: 5700
    accessToken: ""
    postUrl: "http://${docker_ip4}/dicerobot.php"
    postMessageFormat: string
EOF
    echo "login ${qq_id} ${qq_password}" >> /root/mirai/config.txt

    echo -e "Done\n"
}

function deploy_dicerobot() {
    echo "5) 部署 DiceRobot / DiceRobot"

    sudo mkdir /var/www/dicerobot
    sudo chmod 777 /var/www/dicerobot
    a2ensite dicerobot.conf >> /dev/null
    systemctl restart apache2 >> /dev/null
    git clone https://github.com/drsanwujiang/DiceRobot.git /var/www/dicerobot >> /dev/null

    echo -e "Done\n"
}

function finished_info() {
    echo -e "======================================================================================================\n"
    echo "DiceRobot 及其运行环境已经部署完毕，接下来请依照说明文档运行 MiraiOK 即可。"
    echo "DiceRobot and runtime environment has been deployed. Follow the documentation to run MiraiOK."
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