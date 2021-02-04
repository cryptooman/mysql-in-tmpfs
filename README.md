# mysql-in-tmpfs
Run detached MySQL instance based completely in RAM (tmpfs).

The purpose is to increase execution speed of MySQL based application unit tests with minimal efforts.

A common bottleneck that takes up most of the time when running unit tests is loading data into the database.
For example, if we take a look at "Codeception" testing framework guide we can find that it suggests to load test data before each test action in the "Cest" class.
If your database is a large collection of 100+ tables and has many "statuses" and "types" tables that need to be populated, then you might face up with slow loading of your data into MySQL.
Slow unit tests are very annoying during development.

# So:
<pre>
Unit tests with MySQL completely in RAM are twice or more faster than SSD MySQL
Much faster compared to HDD
No need for manipulation of running tests in parallel
Each data dump populate can be fasten from minutes to seconds
Each populate x many tests = noticeable time savings
</pre>

# Usage:
<pre>
Run as sudo:
<i>sudo bash mysql-in-tmpfs.sh</i>

To verbose script each command run:
<i>sudo bash -x mysql-in-tmpfs.sh</i>

If need to autorun on server boot:
<i>sudo crontab -e
    @reboot /bin/bash mysql-in-tmpfs.sh &>> /var/log/mysql-in-tmpfs.log</i>

Defined params:
<i>MYSQL_APPARMOR_FILE="/etc/apparmor.d/usr.sbin.mysqld"
MYSQL_TMP_DATA_DIR="/dev/shm/mysql-in-tmpfs"
MYSQL_TMP_PID_FILE="/dev/shm/mysql-in-tmpfs/mysql.pid"
MYSQL_TMP_SOCKET="/dev/shm/mysql-in-tmpfs/mysql.sock"
MYSQL_TMP_ERR_LOG="/var/log/mysql/mysql-in-tmpfs-error.log"
MYSQL_TMP_HOST="127.0.0.1"
MYSQL_TMP_PORT=33069
MYSQL_TMP_OWNER="mysql:mysql"
MYSQL_TMP_USER="tmpDatabase"
MYSQL_TMP_PASSWORD="tmpDatabase"
MYSQL_TMP_DATABASE="tmpDatabase"</i>
</pre>

# Compatibility:
The script was tested on Ubuntu 20.04.1 LTS, MySQL version 8.0.*

# Warning:
<b>ALL MYSQL TEMP DATA WILL BE LOST ON SERVER SHUTDOWN OR ACCIDENTAL POWER LOST</b>