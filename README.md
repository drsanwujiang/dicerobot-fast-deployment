# 快速部署 DiceRobot

快速部署 DiceRobot 3.1.0

* 安装 PHP 及 Swoole
* 部署 Mirai
* 部署 DiceRobot
* 设置服务


## 系统要求

* CentOS 8 **（推荐）**
* Debian 9/10
* Ubuntu 16.04/18.04/20.04


## 用法

1. 运行脚本

    ### CentOS 系统（仅支持 CentOS 8）

    ```shell
    wget https://cdn.jsdelivr.net/gh/drsanwujiang/dicerobot-fast-deployment@3.1/dicerobot-deployment-centos.sh
    sudo bash dicerobot-deployment-centos.sh
    ```

    ### Debian 系统

    ```shell
    wget https://cdn.jsdelivr.net/gh/drsanwujiang/dicerobot-fast-deployment@3.1/dicerobot-deployment-debian.sh
    sudo bash dicerobot-deployment-debian.sh
    ```

    ### Ubuntu 系统

    ```shell
    wget https://cdn.jsdelivr.net/gh/drsanwujiang/dicerobot-fast-deployment@3.1/dicerobot-deployment-ubuntu.sh
    sudo bash dicerobot-deployment-ubuntu.sh
    ```

2. 根据提示输入机器人的 QQ 账号及密码
3. 依照说明文档运行 DiceRobot 及 Mirai。