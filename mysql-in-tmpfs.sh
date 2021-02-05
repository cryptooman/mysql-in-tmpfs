#!/bin/bash
# ====================================
# Run detached MySQL instance based completely in RAM (tmpfs)
# The purpose is to increase execution speed of MySQL based application unit tests with minimal efforts
#
# WARNING: ALL MYSQL TEMP DATA WILL BE LOST ON SERVER SHUTDOWN OR ACCIDENTAL POWER LOST
#
# Usage:
# sudo bash mysql-in-tmpfs.sh
#
# To verbose script each command run:
# sudo bash -x mysql-in-tmpfs.sh
#
# If need to autorun on server boot:
# sudo crontab -e
#     @reboot /bin/bash mysql-in-tmpfs.sh &>> /var/log/mysql-in-tmpfs.log</i>
#
# Compatibility:
# The script was tested on Ubuntu 20.04.1 LTS, MySQL version 8.0.*
# ====================================

readonly MYSQL_APPARMOR_FILE="/etc/apparmor.d/usr.sbin.mysqld"
readonly MYSQL_TMP_DATA_DIR="/dev/shm/mysql-in-tmpfs"
readonly MYSQL_TMP_PID_FILE="/dev/shm/mysql-in-tmpfs/mysqld.pid"
readonly MYSQL_TMP_SOCKET="/dev/shm/mysql-in-tmpfs/mysqld.sock"
readonly MYSQL_TMP_ERR_LOG="/var/log/mysql/mysql-in-tmpfs-error.log"
readonly MYSQL_TMP_HOST="127.0.0.1"
readonly MYSQL_TMP_PORT=33069
readonly MYSQL_TMP_OWNER="mysql:mysql"
readonly MYSQL_TMP_USER="tmpDatabase"
readonly MYSQL_TMP_PASSWORD="tmpDatabase"
readonly MYSQL_TMP_DATABASE="tmpDatabase"

readonly SCRIPT_NAME=$(basename $0)
readonly SCRIPT_USAGE="/bin/bash $0"
readonly SCRIPT_TIME_START=$(date +%s)

function _err () {
    local errmsg=$1
    local errcode=${2:-1}
    echo "ERROR: [$errcode] $errmsg"
    exit $errcode
} >&2

set -o pipefail
function _iferr () {
    local errcode=$?
    (( $errcode != 0 )) && _err "" $errcode
}

function _echo () {
    echo -e "`date '+%Y-%m-%d %H:%M:%S'`\t$@"
}

_echo "*** Going to run detached mysql instance based completely in RAM (tmpfs) ***"

# Must be run as root
[[ $(whoami) != "root" ]] && _err "Must be run as root"

# Check compatibility
[[ $(which mysql) ]] || _err "Not found required binary: mysql"
[[ $(which mysqld) ]] || _err "Not found required binary: mysqld"
[[ $(which mysqladmin) ]] || _err "Not found required binary: mysqladmin"
[[ $( mysql --version | grep -P '\s+Ver\s+8\.' ) ]] || _err "Required mysql version: 8.*"

# Patch mysql apparmor if need
[[ -e $MYSQL_APPARMOR_FILE ]] || _err "Mysql apparmor file not exists: $MYSQL_APPARMOR_FILE"
if [[ ! $( cat $MYSQL_APPARMOR_FILE | grep "$MYSQL_TMP_DATA_DIR" ) ]]; then
    _echo "Patching mysql apparmor file: $MYSQL_APPARMOR_FILE"
    apparmOrigFile="/etc/apparmor/$(basename $MYSQL_APPARMOR_FILE).orig"
    cp -p $MYSQL_APPARMOR_FILE $apparmOrigFile
    _echo "Original file saved to: $apparmOrigFile"
    patch="\n"
    patch+="  # Mysql in tmpfs\n"
    patch+="  $MYSQL_TMP_DATA_DIR/ r,\n"
    patch+="  $MYSQL_TMP_DATA_DIR/** rwk,\n"
    patch+="  $MYSQL_TMP_ERR_LOG rw,\n"
    patch+="}"
    sed -r -i "s~^\s*\}\s*$~$patch~" $MYSQL_APPARMOR_FILE; _iferr
    systemctl reload apparmor.service; _iferr
fi

# Stop previous mysqld instance if exists
[[ -e $MYSQL_TMP_PID_FILE ]] && pidMysqlSaved=$(cat $MYSQL_TMP_PID_FILE)
if (( $pidMysqlSaved )); then
    _echo "Found running mysqld temp instance ($pidMysqlSaved): stopping it"
    kill -SIGTERM $pidMysqlSaved; _iferr
    terminated=0
    attempts=60
    for i in $(eval echo "{1..$attempts}"); do
        if [[ ! $( ps -u --pid "$pidMysqlSaved" | grep "$pidMysqlSaved" ) ]]; then
            terminated=1
            break
        fi
        sleep 1
        _echo "Waiting mysqld to stop [$((attempts-i))] ..."
    done
    (( $terminated )) || _err "Failed to stop running mysqld temp instance (pid:$pidMysqlSaved)"
fi

_echo "Creating mysql temp data dir"
rm -rf $MYSQL_TMP_DATA_DIR; _iferr
mkdir $MYSQL_TMP_DATA_DIR; _iferr
chown $MYSQL_TMP_OWNER $MYSQL_TMP_DATA_DIR; _iferr

_echo "Initializing mysql temp data"
mysqld --initialize --datadir=$MYSQL_TMP_DATA_DIR --disable-log-bin --log-error=$MYSQL_TMP_ERR_LOG; _iferr

_echo "Running mysqld temp instance (host:$MYSQL_TMP_HOST port:$MYSQL_TMP_PORT)"
mysqld \
--port=$MYSQL_TMP_PORT \
--socket=$MYSQL_TMP_SOCKET \
--pid-file=$MYSQL_TMP_PID_FILE \
--innodb_data_home_dir=$MYSQL_TMP_DATA_DIR \
--innodb_doublewrite_dir=$MYSQL_TMP_DATA_DIR \
--innodb_log_group_home_dir=$MYSQL_TMP_DATA_DIR \
--innodb-undo-directory=$MYSQL_TMP_DATA_DIR \
--datadir=$MYSQL_TMP_DATA_DIR \
--tmpdir=$MYSQL_TMP_DATA_DIR \
--log-error=$MYSQL_TMP_ERR_LOG \
--disable-log-bin \
--general_log=0 \
--slow_query_log=0 \
--bind-address=$MYSQL_TMP_HOST \
--mysqlx=0 \
--innodb_flush_log_at_trx_commit=0 \
--innodb_buffer_pool_size=1G \
--innodb_buffer_pool_instances=4 \
--innodb_io_capacity=2000 \
--daemonize=ON; _iferr

_echo "Removing mysql temp generated root password"
password=$(cat $MYSQL_TMP_ERR_LOG | grep -P 'A temporary password is generated for root@localhost' | tail -1 | awk '{ print $NF }')
[[ $password ]] || _err "Failed to get mysql temp generated root password"
mysqladmin --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT -u root -p"$password" password ''; _iferr

_echo "Creating mysql temp database and user"
mysql --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT -e "CREATE DATABASE $MYSQL_TMP_DATABASE;"; _iferr
mysql --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT -e "CREATE USER '$MYSQL_TMP_USER'@'%' IDENTIFIED BY '$MYSQL_TMP_PASSWORD';"; _iferr
mysql --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT -e "GRANT ALL PRIVILEGES ON $MYSQL_TMP_DATABASE.* TO '$MYSQL_TMP_DATABASE'@'%';"; _iferr
mysql --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT -e "FLUSH PRIVILEGES;"; _iferr

_echo "Time taken: $(( $(date +%s) - $SCRIPT_TIME_START )) sec"

_echo ""
_echo "Created mysql temp instance in tmpfs"
_echo "Connect: mysql --host=$MYSQL_TMP_HOST --port=$MYSQL_TMP_PORT --database=$MYSQL_TMP_DATABASE --user=$MYSQL_TMP_USER --password='$MYSQL_TMP_PASSWORD'"
_echo "mysql_tmp_data_dir: $MYSQL_TMP_DATA_DIR"
_echo "mysql_tmp_err_log: $MYSQL_TMP_ERR_LOG"
_echo ""
_echo "WARNING: ALL MYSQL TEMP DATA WILL BE LOST ON SERVER SHUTDOWN OR ACCIDENTAL POWER LOST"
_echo ""
