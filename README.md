# Speed up your Unit Tests
Run detached MySQL instance with data folder in RAM (tmpfs), i.e. based completely in memory. The purpose is to increase execution speed of MySQL based application unit tests with minimal efforts.

A common bottleneck that takes up most of the time when running unit tests is loading data into the database.
For example, if we take a look at "Codeception" testing framework guide we can find that it suggests to load test data before each test action in the "Cest" class.
If your database is a large collection of 100+ tables and has many "statuses" and "types" tables that need to be populated, then you might face up with slow loading of your data into MySQL.
Slow unit tests are very annoying during development.

# So:
* Unit tests with MySQL completely in RAM are faster than SSD/HDD MySQL<br>
* No need to modify unit tests code<br>
* Each data dump populate can be noticeably accelerated<br>
* Each quicker populate x many tests = good time savings<br>

# Usage:
<pre>
1) Run as sudo: <i>sudo bash mysql-in-tmpfs.sh</i>
   This will create detached mysqld instance with data folder in RAM (tmpfs)
2) Connect your application unit tests to the created mysqld instance
   See connection params below or in the script output

To verbose each command of the script run:
<i>sudo bash -x mysql-in-tmpfs.sh</i>

If need to autorun on server boot:
<i>sudo crontab -e
    @reboot /bin/bash mysql-in-tmpfs.sh &>> /var/log/mysql-in-tmpfs.log</i>

Defined params:
<i>MYSQL_APPARMOR_FILE="/etc/apparmor.d/usr.sbin.mysqld"
MYSQL_TMP_DATA_DIR="/dev/shm/mysql-in-tmpfs"
MYSQL_TMP_PID_FILE="/dev/shm/mysql-in-tmpfs/mysqld.pid"
MYSQL_TMP_SOCKET="/dev/shm/mysql-in-tmpfs/mysqld.sock"
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

# Notes:
Same behaviour can be also achieved by using Docker with the appropriate configuration.

# Warning:
<b>ALL MYSQL TEMP DATA WILL BE LOST ON SERVER REBOOT / SHUTDOWN OR ACCIDENTAL POWER LOST</b>
