# MySQL 5.7.44 二进制安装教程

## 1. 准备工作

### 1.1 下载MySQL二进制包
访问MySQL官方下载页面：https://dev.mysql.com/downloads/mysql/5.7.html
选择以下版本：
- 操作系统：Linux - Generic
- 版本：5.7.44
- 下载文件：`mysql-5.7.44-linux-glibc2.12-x86_64.tar.gz`

### 1.2 系统要求
- 操作系统：Linux
- 内存：至少2GB
- 磁盘空间：至少5GB可用空间

## 2. 安装步骤

### 2.1 创建MySQL用户和组
```bash
# 创建mysql用户组
groupadd mysql

# 创建mysql用户并加入mysql组
useradd -r -g mysql -s /bin/false mysql
```

### 2.2 解压MySQL二进制包
```bash
# 创建安装目录
mkdir -p /usr/local/mysql

# 解压下载的二进制包
tar -xzvf mysql-5.7.44-linux-glibc2.12-x86_64.tar.gz -C /usr/local/

# 创建软链接
ln -s /usr/local/mysql-5.7.44-linux-glibc2.12-x86_64 /usr/local/mysql
```

### 2.3 创建必要的目录
```bash
# 创建数据目录
mkdir -p /usr/local/mysql/data

# 创建日志目录
mkdir -p /usr/local/mysql/logs

# 设置目录权限
chown -R mysql:mysql /usr/local/mysql
```

### 2.4 初始化MySQL
```bash
# 进入MySQL目录
cd /usr/local/mysql

# 初始化MySQL
bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
```

### 2.5 配置MySQL服务

创建MySQL配置文件：
```bash
cat > /etc/my.cnf << EOF
[mysqld]
basedir=/usr/local/mysql
datadir=/usr/local/mysql/data
socket=/tmp/mysql.sock
user=mysql
port=3306
character-set-server=utf8mb4
default_authentication_plugin=mysql_native_password

[client]
socket=/tmp/mysql.sock
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF
```

### 2.6 创建系统服务
```bash
cat > /etc/systemd/system/mysql.service << EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
User=mysql
Group=mysql
ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf
LimitNOFILE=65535
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 2.7 启动MySQL服务
```bash
# 重新加载systemd配置
systemctl daemon-reload

# 启动MySQL服务
systemctl start mysql

# 设置开机自启
systemctl enable mysql
```

### 2.8 设置root密码
```bash
# 获取临时密码
grep 'temporary password' /usr/local/mysql/logs/error.log

# 使用临时密码登录并修改密码
mysql -uroot -p
ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_new_password';
```

## 3. 验证安装

### 3.1 检查MySQL状态
```bash
systemctl status mysql
```

### 3.2 测试连接
```bash
mysql -uroot -p
```

## 4. 常见问题解决

### 4.1 权限问题
如果遇到权限相关错误，请检查：
```bash
chown -R mysql:mysql /usr/local/mysql
chmod -R 755 /usr/local/mysql
```

### 4.2 端口占用
如果3306端口被占用：
```bash
# 查看端口占用
netstat -tlnp | grep 3306

# 修改配置文件中的端口号
vim /etc/my.cnf
```

## 5. 安全建议

1. 定期更改root密码
2. 限制远程访问
3. 删除测试数据库
4. 设置适当的文件权限
5. 定期备份数据

## 6. 卸载MySQL

如果需要卸载MySQL：
```bash
# 停止服务
systemctl stop mysql

# 删除服务文件
rm /etc/systemd/system/mysql.service

# 删除配置文件
rm /etc/my.cnf

# 删除安装目录
rm -rf /usr/local/mysql
rm -rf /usr/local/mysql-5.7.44-linux-glibc2.12-x86_64

# 删除用户和组
userdel mysql
groupdel mysql
```