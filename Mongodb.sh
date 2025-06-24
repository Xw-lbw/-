#!/bin/bash
MONGODB_VERSION="4.4.1"

# 准备系统环境检测（根据环境需要自行修改或注释）
# 同一时间最多开启的文件数
ulimit -n 25000
# 同一时间最多开启的进程数
ulimit -u 25000

# 设置内核参数，当某个节点内存不足时，可以借用其他节点的内存
echo 0 >/proc/sys/vm/zone_reclaim_mode
#禁用内存区域回收，减少内存回收带来的性能抖动。
sysctl -w vm.zone_reclaim_mode=0   
#禁用透明大页，避免 THP 的自动分配和回收导致的性能问题。
echo never >/sys/kernel/mm/transparent_hugepage/enabled  
#禁用透明大页的碎片整理，减少内存管理的开销。
echo never >/sys/kernel/mm/transparent_hugepage/defrag


# Redis 6.2.4 是用 C 语言编写的，因此它依赖于 glibc 来提供标准 C 库的功能。最低建议版本为 glibc 2.12，推荐版本glibc 2.17或更高版本
# 查看自己的版本 'ldd --version'
# 如果 glibc 低于 2.12，则需要安装 glibc 库
if [ $(ldd --version | grep -c "2.12") -eq 0 ]; then
    echo "正在安装 glibc 库..."
    wget http://ftp.gnu.org/gnu/glibc/glibc-2.18.tar.gz
    tar -zxvf glibc-2.18.tar.gz -C /usr/local/
    mv /usr/local/glibc-2.18 /usr/local/glibc
    cd /usr/local/glibc
    # 创建构建目录
    mkdir build
    cd build
    ./configure --prefix=/usr/local/glibc --disable-profile --enable-add-ons --with-headers=/usr/local/glibc/include --with-binutils=/usr/local/bin
    make -j $(nproc)
    make install
fi


# 安装 MongoDB 软件
# 下载 MongoDB 软件
echo "正在下载 MongoDB ${MONGODB_VERSION}..."
wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-"$MONGODB_VERSION".tgz
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连通性"
    exit 1
fi
echo "下载完成"

# 解压 MongoDB 软件
echo "正在解压 MongoDB ${MONGODB_VERSION}..."
tar -zxvf mongodb-linux-x86_64-rhel70-"$MONGODB_VERSION".tgz  -C /usr/local/
if [ $? -ne 0 ]; then  
    echo "解压失败，请检查文件是否存在"
    exit 1
fi
echo "解压完成"

# 重命名解压后的目录
mv /usr/local/mongodb-linux-x86_64-rhel70-4.4.1/ /usr/local/mongodb

# 添加环境变量
echo "正在添加环境变量..."
echo "export PATH=\$PATH:/usr/local/mongodb/bin" >> /etc/profile
source /etc/profile
echo "环境变量添加完成"

# 创建 MongoDB 用户
echo "正在创建 MongoDB 用户..."
useradd -r -s /bin/bash mongodb
echo "MongoDB 用户创建完成"

# 创建 MongoDB 组
echo "正在创建 MongoDB 组..."
groupadd -r mongodb
echo "MongoDB 组创建完成"

# 创建 MongoDB 配置文件目录
echo "正在创建 MongoDB 配置文件目录..."
mkdir /usr/local/mongodb/conf/
echo "目录创建完成"

# 创建 MongoDB 存储目录
echo "正在创建 MongoDB 存储目录..."
mkdir /usr/local/mongodb/data
echo "目录创建完成"

# 创建 MongoDB 日志目录
echo "正在创建 MongoDB 日志目录..."
mkdir /usr/local/mongodb/logs
echo "目录创建完成"

# 修改 MongoDB 数据目录和日志文件的权限：
echo "正在修改 MongoDB 数据目录和日志文件的权限..."
chown -R mongodb:mongodb /usr/local/mongodb/data
chown -R mongodb:mongodb /usr/local/mongodb/logs
echo "权限修改完成"

# 修改MongoDB 配置文件
# 获取机器的 IP 地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# 检查是否成功获取 IP 地址
if [ -z "$IP_ADDRESS" ]; then
    echo "无法获取机器的 IP 地址，请检查网络配置。"
    exit 1
fi

cat <<END >>/usr/local/mongodb/conf/mongodb.conf
# 数据存储配置
storage:
  dbPath: /usr/local/mongodb/data/

# 日志配置
systemLog:
  destination: file
  path: /usr/local/mongodb/logs/mongodb.log
  logAppend: true

# 网络配置
net:
  port: 27017
  bindIp: "$IP_ADDRESS"

# 安全配置（如果启用身份验证）
# security:
#   authorization: enabled

# 进程管理
processManagement:
  fork: true
  timeZoneInfo: /usr/share/zoneinfo
END


# 编写服务启动服务
echo "正在编写服务启动脚本..."
cat <<END >>/etc/init.d/mongodb
#!/bin/bash
# chkconfig: 2345 80 90
# description: MongoDB is a high-performance, open source, document-oriented database.
case "\$1" in
'start')
/usr/local/mongodb/bin/mongod -f /usr/local/mongodb/conf/mongodb.conf;;
'stop')
/usr/local/mongodb/bin/mongod -f /usr/local/mongodb/conf/mongodb.conf --shutdown;;
'restart')
/usr/local/mongodb/bin/mongod -f /usr/local/mongodb/conf/mongodb.conf --shutdown
/usr/local/mongodb/bin/mongod -f /usr/local/mongodb/conf/mongodb.conf;;

esac
END
chmod +x /etc/init.d/mongodb

# 启动 MongoDB 服务
echo "正在启动 MongoDB 服务..."
/etc/init.d/mongodb start
echo "MongoDB 服务启动完成"
echo "Usage: /etc/init.d/mongodb {start|stop|restart|force-reload}" 

# 设置 MongoDB 为开机自启动
echo "正在设置 MongoDB 为开机自启动..."
chkconfig --add mongodb
chkconfig --level 35 mongodb on
echo "MongoDB 开机自启动设置完成"

# 查看 MongoDB 服务状态
echo "正在查看 MongoDB 服务状态..."
netstat -anpt | grep 27017
echo "MongoDB 服务状态查看完成"

# 连接 MongoDB 服务
echo "正在连接 MongoDB 服务..."
mongo --host "$IP_ADDRESS" --port 27017
echo "MongoDB 服务连接完成"