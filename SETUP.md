## Important!

- This guide is intended for Arch Linux or its derivative (Manjaro, Endeavour, Garuda, etc). The package name, package manager, and directory structure may vary for other Linux distributions. See [_misc / arch_package](_misc/arch_package/) for details.

- Always double check every path, especially when writing config files! Even if you're on Arch Linux, package maintainers may also change (which may decide to change something), so proceed with caution.

- Update your system first before attempting to do anything in this guide (e.g. `sudo pacman -Syyu`).

- This guide use a single computer to run 2 Hadoop clusters (1 master, 1 worker) in a pseudo-distributed mode. If you need more clusters, you may need to modify something that's not covered in this guide. The current stack version used in this guide are Hadoop v3.3.5, Hive v3.1.3, Spark v3.5.0, OpenJDK v8.382.u05, and PostgreSQL v15.4.

## Step-by-Step Guide

1. Install and configure Apache Spark (see [below](#configuring-apache-spark)).

    If you're following that link until the end, you will also end up installing Apache Hadoop and Apache Hive as prerequisite for Spark.

    However, if you don't care about cluster setup or any of those programs, you can skip this step since `pyspark` can also work on its own.

1. Install and configure Metabase (see [below](#configuring-metabase)).

    Note that if you don't install Hive, you don't need to install Metabase since it (currently) can't connect to Spark SQL without Hive.

1. If you installed everything from the previous steps, make sure to start all the services:

    ``` sh
    # sudo systemctl start sshd postgresql
    sudo systemctl start hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver
    sudo systemctl start metabase
    sudo systemctl start hive-metastore hive-hiveserver2
    ```

    Wait about a minute, then check the services status (some services may not fail immediately):

    ``` sh
    # Single command becase the output is displayed through "less"
    sudo systemctl status hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver metabase hive-metastore hive-hiveserver2
    ```

    Don't check services based on the status (active/inactive) only, but check the actual logs. Hive services may still continue even if they actually encountered an error! To see the full log of a service, use `sudo journalctl -u service_name`. After fixing the problem, use `sudo systemctl restart service_name` to restart it.

    Check used ports by running `sudo netstat -plnt`, make sure some important ports like `9803`, `10000`, and `9000` are listed there. If you run Python before starting these services, there's chance that Python may claim those ports!

1. Create Python virtual environment. You can use `Ctrl + Shift + P` on VS Code, or run `python -m venv .venv` on project folder directly. By using virtual environment, all dependencies will be installed in the project folder.

1. Install all pip requirements (`pip install -r requirements.txt`), which also contains the needed `pyspark` library.

    PySpark may also be bundled within Apache Spark itself, but you will need to set `PYTHONPATH` [manually](https://spark.apache.org/docs/latest/api/python/getting_started/install.html#manually-downloading) (so the Python library can be detected). However, if you're installing from AUR, by default it may not include the `python` folder so `pyspark` will still be needed.

    Note that PySpark is actually a standalone package (but still require Java), it will work without installing Apache Hadoop, Apache Hive, or even Apache Spark itself. However, without installing all the prerequisites, PySpark can't be used to its full potential and most softwares (e.g. Metabase) won't be able to connect to it.

1. Start experimenting using the [notebook](main.ipynb) file and Metabase (`localhost:3000`).

1. If you're done, stop all the services:

    ``` sh
    # sudo systemctl stop sshd postgresql
    sudo systemctl stop hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver
    sudo systemctl stop metabase
    sudo systemctl stop hive-metastore hive-hiveserver2
    ```

## Configuring Apache Spark

Using Apache Spark, we can execute queries and create tables without affecting the real database. This is ideal for production environment. It can also be used for machine learning and streaming data in real-time.

<details>
<summary>Expand</summary>

1. Configure Apache Hadoop first (see [below](#configuring-apache-hadoop)). It's needed because currently Metabase only support Spark SQL connection using Hive.

    However, if you are very lazy, you can just connect to MariaDB (MySQL) or PostgreSQL using Metabase directly, but then most of this guide will be pointless.

1. Install Apache Spark from AUR (`yay -S apache-spark`). Despite its package name, it will use the binary release instead of compiling from source code. If you prefer compiling, use `apache-spark-git` instead.

1. Check whether Spark is registered to `PATH` or not by running `spark-shell --version` or `where spark-shell`. If not, create a new profile file (e.g. `sudo nano /etc/profile.d/apache-spark.sh`) with content similar to this:

    ``` sh
    export SPARK_HOME=/opt/apache-spark
    export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
    ```

    Load the new change by running `source /etc/profile.d/apache-spark.sh` on your shell (e.g. Bash, Zsh).

1. Done, continue to the next step on the main guide.

</details>

## Configuring Metabase

Metabase is a business intelligence, dashboard, and data visualization tool. It has many alternatives such as Power BI, Tableau, Superset, Redash, and Grafana. There are some interesting insights which made me choose Metabase, see [here](https://medium.com/vortechsa/choosing-an-analytics-tool-metabase-vs-superset-vs-redash-afd88e028ba9) and [here](https://community.grafana.com/t/business-operational-dashboards-use-cases-for-grafana/36235). However, please do your own research before deciding!

<details>
<summary>Expand</summary>

1. Install Metabase from AUR (`yay -S metabase`).

1. By default, Metabase config is located at `/etc/metabase.conf`. Edit it as root using nano (`sudo nano /etc/metabase.conf`) or similar tools. You can run Metabase without changing any config, but it will complain if we use the default H2 database (unsafe).

    Metabase example config:

    ``` ini
    # https://www.metabase.com/docs/latest/configuring-metabase/environment-variables

    # Metabase server URL
    MB_JETTY_HOST=127.0.0.1
    MB_JETTY_PORT=3000
    MB_ANON_TRACKING_ENABLED=false
    MB_CHECK_FOR_UPDATES=false
    # Possible values: postgres, mysql, h2
    # Use mysql for MySQL compatible databases (e.g. MariaDB)
    MB_DB_TYPE=postgres
    MB_DB_HOST=127.0.0.1
    # Example values: 5432 (PostgreSQL), 3306 (MariaDB)
    MB_DB_PORT=5432
    # Change it based on your setup
    MB_DB_USER=postgres
    MB_DB_PASS=postgres
    MB_DB_DBNAME=metabase
    ```

    Create the database (`MB_DB_DBNAME`) if not exist yet, and make sure the owner is correct (in this case, `postgres`).

1. After changing the config file, you should not run `metabase` directly. You need to run it as service (`sudo systemctl start metabase`), otherwise it won't detect the config file and may create some stuff directly on your home directory.

    If you want to run it automatically on startup, use `sudo systemctl enable metabase` (will take about 800 MB of RAM on idle). You can also check the service status by using `sudo systemctl status metabase`.

1. Set up Metabase account, data source (SparkSQL), etc by going to `localhost:3000` (you can do this later). Make sure you already set up Hive and Spark correctly, otherwise you won't be able to connect to data source.

    The default database for Hive is `default`, it's different because we are using `hive2` JDBC to connect, not `postgres` or `mysql` JDBC. You can check this from the [notebook](main.ipynb) file. As for the host and port, use `localhost` and `10000`.

1. Done, continue to the next step on the main guide.

</details>

## Configuring Apache Hadoop

Apache Hadoop is a parallel data processing engine where big data can be distributed to several clusters. There are 2 types of cluster, the master (name) node and the worker (data) node.

<details>
<summary>Expand</summary>

1. Install and configure Java environment first (see [below](#configuring-java-environment)).

1. Install Apache Hadoop from AUR (`yay -S hadoop`). Apache Hadoop is required by Apache Hive, which is required by Metabase.

    By default, Hadoop will be compiled from source instead of using the ready-made binary. To use the binary version, don't continue immediately when asked about clean build (on yay), modify `PKGBUILD` file in `~/.cache/yay/hadoop` (see below), then choose "[N]one" on yay to continue again.

    The modified `PKGBUILD` file should (more or less) look like this:

    ``` sh
    # ...

    # Modify the source URL only, leave the rest
    source=("https://dlcdn.apache.org/hadoop/common/hadoop-$pkgver/hadoop-$pkgver.tar.gz"
        "XXXXXXXXXXXXXXXXXXXX"
        "XXXXXXXXXXXXXXXXXXXX"
        "XXXXXXXXXXXXXXXXXXXX")
    
    # Replace the first line with SKIP (no file corruption check!)
    sha256sums=('SKIP'
        'XXXXXXXXXXXXXXXXXXXX'
        'XXXXXXXXXXXXXXXXXXXX'
        'XXXXXXXXXXXXXXXXXXXX')

    # Remove build() function and replace it with prepare()
    prepare() {
        # Use similar folder structure as if we built it from source
        # See the beginning of package() function for folder structure reference
        mkdir -p hadoop-rel-release-$pkgver/hadoop-dist/target
        mv hadoop-$pkgver hadoop-rel-release-$pkgver/hadoop-dist/target/hadoop-$pkgver
    }

    # ...
    ```

1. Check whether Hadoop env vars are already set or not by looking at `/etc/profile.d/hadoop.sh` (file name may vary). If not, create the file with content similar to this:

    ``` sh
    export HADOOP_COMMON_LIB_NATIVE_DIR=/usr/lib
    export HADOOP_CONF_DIR=/etc/hadoop
    export HADOOP_LOG_DIR=/var/log/hadoop
    export HADOOP_USERNAME=hadoop

    # Hive still hasn't support Java 11 yet
    export JAVA_HOME=/usr/lib/jvm/java-8-openjdk
    ```

    Load the new env vars by running `source /etc/profile.d/hadoop.sh` on your shell (e.g. Bash, Zsh).

    :red_circle: **Important:** When running program as root (e.g. by using `sudo`), it will not load user env vars from `/etc/profile.d` by default, so you may need to use `sudo -i` (to invoke the login shell) if Hadoop still complains about missing variables.

    Also, other than `/etc/profile.d/hadoop.sh`, Hadoop env file is also located at `/etc/hadoop/hadoop-env.sh`. The Arch [wiki](https://wiki.archlinux.org/title/Hadoop) recommend editing `JAVA_HOME` in that file instead, but it will be easier for us to just modify one file.

1. After that, you can also modify `/etc/conf.d/hadoop` file with content similar to `/etc/profile.d/hadoop.sh`, but remove the `export` and any shell `$` variable (because it's not a shell file).

    The difference between this file (`/etc/conf.d/hadoop`) and the previous file (`/etc/profile.d/hadoop.sh`) is that this one will be loaded instead if you run Hadoop as service/daemon (which you may want to do at later step). Some of you may prefer this rather than running Hadoop manually on shell every time you need it.

    If you want to run Hadoop directly (as user/root, not as service), then there's no need to modify this file. By default, the service will be running under the `hadoop` user (it's not a normal user, it doesn't have password or home by default).

1. To test Hadoop, try using a single cluster first. In this guide, I will be using the pseudo-distributed mode ([my main reference](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/SingleCluster.html)).

    Modify `/etc/hadoop/core-site.xml`:
    ``` xml
    <configuration>
        <property>
            <name>fs.defaultFS</name>
            <value>hdfs://localhost:9000</value>
        </property>
    </configuration>
    ```

    Modify `/etc/hadoop/hdfs-site.xml`:
    ``` xml
    <configuration>
        <property>
            <name>dfs.replication</name>
            <value>1</value>
        </property>
        <property>
            <name>dfs.namenode.name.dir</name>
            <value>file:///mnt/hadoop/${user.name}/dfs/name</value>
        </property>
        <property>
            <name>dfs.datanode.data.dir</name>
            <value>file:///mnt/hadoop/${user.name}/dfs/data</value>
        </property>
    </configuration>
    ```

    If you want to know more, here are the default configuration for [core-site.xml](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/core-default.xml) and [hdfs-site.xml](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml).
    
    If you take a deeper look at those links, the default location for `dfs.namenode.name.dir` and `dfs.datanode.data.dir` are inside `hadoop.tmp.dir`, which will be cleaned on each startup. That's why we move them to other directories, so the data can be retained. Using `/mnt` seems quite reasonable in this case.

    Also, we should make `/mnt/hadoop` accessible by the user we want to run Hadoop as (e.g. `root`, `hadoop`, or your username) by running these commands:

    ``` sh
    # I think /mnt/hadoop should just be owned by root
    sudo mkdir /mnt/hadoop

    # Create /mnt/hadoop/username (e.g. hadoop), see hdfs-site.xml
    sudo mkdir /mnt/hadoop/hadoop
    # User and group to own the directory (e.g. hadoop:hadoop)
    sudo chown hadoop:hadoop /mnt/hadoop/hadoop
    ```

    :red_circle: **Important:** Make sure you consistently use the same username and group (it will be used again at later step), or just use `hadoop` if you're not sure because the services/daemons also use that by default. The DFS directory config we created previously is also based on username, so changing users may cause path and permission issues.

1. Since we are using the pseudo-distributed mode, we may as well set Hadoop to use YARN in case we want to use (real) multiple clusters in the future. However, if you only want to use single cluster, I think you can skip this step.

    Modify `/etc/hadoop/mapred-site.xml`:

    ``` xml
    <configuration>
        <property>
            <name>mapreduce.framework.name</name>
            <value>yarn</value>
        </property>
    </configuration>
    ```

    Modify `/etc/hadoop/yarn-site.xml`:

    ``` xml
    <configuration>
        <property>
            <name>yarn.nodemanager.aux-services</name>
            <value>mapreduce_shuffle</value>
        </property>
    </configuration> 
    ```

    Default config for reference: [mapred-default.xml](https://hadoop.apache.org/docs/current/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml), [yarn-default.xml](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-common/yarn-default.xml).

1. Format a new Distributed File System (DFS) for the master node by running `sudo -i hdfs namenode -format`. The DFS directory will be made as specified in the `hdfs-site.xml` file.

    :red_circle: **Important:** Note that by running as `sudo` your user will be `root`, not `hadoop` or your original user. This may cause inconsistencies (e.g. DFS directory not created yet) when you force Hadoop to run as other user at later step. However, that is actually the right way because running as root is dangerous and `ssh` (needed by Hadoop) disallow root password login by default.

    :large_blue_circle: **Information:** In this guide, we will try running it as root first because ~~I want you to suffer the same way as I did~~ that's how I troubleshoot what's wrong and came up with solutions. I hope my findings may be useful to some of you.

1. Start the master node and worker node(s) by running `sudo -i start-all.sh` (it's the same as running both `start-dfs.sh` and `start-yarn.sh`). Also note that the user will be `root` if we do it this way.

    If Hadoop complains about `HDFS_NAMENODE_USER`, `HDFS_DATANODE_USER` and some other variables (because you ran it as root), you can add all the complained variables to `/etc/profile.d/hadoop.sh` like this:

    ``` sh
    # Just add these, don't delete other existing variables
    export HDFS_NAMENODE_USER=hadoop
    export HDFS_DATANODE_USER=hadoop
    export HDFS_SECONDARYNAMENODE_USER=hadoop
    export YARN_NODEMANAGER_USER=hadoop
    export YARN_RESOURCEMANAGER_USER=hadoop
    ```

    Also, if you take a look at `start-dfs.sh` file, there are actually other variable called `HDFS_DATANODE_SECURE_USER`. You can also add it to `/etc/profile.d/hadoop.sh` (optional), but with `hdfs` as the value.

    If Hadoop still complains (again) because it can't connect to localhost via `ssh` (port 22), you can either start or enable the SSH service (`sshd`). Then, execute these commands on your shell to enable passwordless connection (otherwise Hadoop won't be able to connect to worker nodes):

    ``` sh
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

    # Equal to: ssh-copy-id -i ~/.ssh/id_rsa.pub username@localhost
    # Don't execute this multiple times, it will append duplicated keys
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

    # To prevent permission denied error for other users
    chmod 0600 ~/.ssh/authorized_keys
    ```

    Notice that when you try to run `start-all.sh` again, it may still complain about `Permission denied (publickey,password)`. This is likely due to your original user home directory (`~` or `/home/username`) is not accessible by SSH when running as `hadoop` or `root`, or SSH is looking for files in the wrong directory. To troubleshoot this issue, try running SSH with debug mode as different user(s):

    ``` sh
    # Connect to hadoop as current user
    #ssh -v hadoop@localhost

    # Connect to hadoop as root
    #sudo ssh -v hadoop@localhost

    # Connect to hadoop as hadoop
    sudo -u hadoop ssh -v hadoop@localhost
    ```

    From the debug log, it turns out that the user `hadoop` actually has a non-standard home directory, which is located at `/var/lib/hadoop`, and SSH is trying to access the key files from that directory instead (`/var/lib/hadoop/.ssh`). In conclusion, we need to make passwordless connection like in the previous step, but this time we will run the SSH tools as `hadoop`:

    ``` sh
    sudo -i -u hadoop

    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys

    exit
    ```

1. If after all that, Hadoop still complain about missing env vars (probably due to SELinux fuckery), you have 2 options (and you can do both):

    - Add all relevant variables from `/etc/profile.d/hadoop.sh` to `/etc/hadoop/hadoop-env.sh` (just append them at the end). Though you may still need to use `sudo -i` initially to load some Hadoop env vars from `/etc/profile.d/hadoop.sh` since our config files are stored in a non-standard directory, or
    - Use the provided Hadoop services/daemons

    You can do option 1 by yourself, as for option 2, check the available service names by running `ls /usr/lib/systemd/system/hadoop*`. The advantage of using services is that you can run it as `hadoop` user by default, and these services don't read env vars from `/etc/profile.d`, but from `/etc/conf.d/hadoop` instead.

    Before running the services, you may want to reformat DFS on master node and delete the old one since we ran it as `root` previously:

    ``` sh
    sudo rm -r /mnt/hadoop/root
    # Will create /mnt/hadoop/hadoop this time
    sudo -i -u hadoop hdfs namenode -format
    ```

    The `start-all.sh` should be equal as running:

    ``` sh
    sudo systemctl start hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver
    ```
    
    In case there are some Hadoop processes that are already running, stop them all by running `sudo -i stop-all.sh` and:

    ``` sh
    sudo systemctl stop hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver
    ```

    Check all services status by running:

    ``` sh
    sudo systemctl status hadoop-namenode hadoop-datanode hadoop-secondarynamenode hadoop-resourcemanager hadoop-historyserver
    ```

1. Now, we can start testing Hadoop. I'm still using this [reference](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/SingleCluster.html).

    Start `sshd` and all Hadoop services if they haven't been started already. Access the master node web UI at `http://localhost:9870` to see whether it can be accessed or not. You can also check how many worker nodes are running from here (if it's zero, I also provided the solution, just continue for now).

    Make the required user directory on Hadoop DFS by running `hdfs dfs -mkdir -p /user/hadoop` (it seems that `sudo` is not required to access the DFS). Then, make a new folder named "input" on that user by running `hdfs dfs -mkdir input`.

    Try copying files from the real system into the DFS `input` folder by running `hdfs dfs -put /etc/hadoop/*.xml input`. If an error occurred, probably no worker node is running, try checking what's wrong by running worker node manually (`sudo -i hdfs datanode`) and see the output. I get an `Incompatible clusterIDs` error, here's what I did:
    - Stop all Hadoop services (`sudo -i stop-all.sh`).
    - Delete master and worker node DFS (`sudo rm -r /mnt/hadoop/hadoop/dfs/*`).
    - Format a new master node DFS by running `sudo -i hdfs namenode -format`. You can also use `sudo -i hdfs namenode -format -clusterId <cluster_id>` to force the cluster id.
    - Run `sudo -i start-all.sh` and repeat all previous steps (making user directory, etc).

    Run the MapReduce example (not sure what's this) by running `sudo -i hadoop jar /usr/share/hadoop/mapreduce/hadoop-mapreduce-examples-X.X.X.jar grep input output 'dfs[a-z.]+'` (where X.X.X is your Hadoop version).

    Try getting `output` files from DFS to our real system (the `Downloads` folder) by running `hdfs dfs -get output ~/Downloads/output`. Now check the output files by running `cat ~/Downloads/output/*`.

    Delete the output files by running `rm -r ~/Downloads/output` (please make sure there's nothing important here).

    :large_blue_circle: **Information:** Other than using CLI, you can also upload and delete files using the web UI, access the "Utilities menu", then choose "Browse the file system" (or simply use this URL: `http://localhost:9870/explorer.html`). There's also the YARN web UI at `http://localhost:8088`, but we can't upload files in here.

1. If everything works correctly, then continue to configure Apache Hive (see [below](#configuring-apache-hive)).

</details>

## Configuring Apache Hive
Apache Hive is a data warehouse system built on top of Hadoop for providing distributed data query and analysis. If used together with Spark, the warehouse data (containing tables and databases) will be saved to Hadoop DFS.

<details>
<summary>Expand</summary>

1. If you haven't installed any database yet, refer to the Arch wiki to set up either [PostgreSQL](https://wiki.archlinux.org/title/PostgreSQL) or [MariaDB](https://wiki.archlinux.org/title/MariaDB) (MySQL). You don't need to create your own database user, because we will create one in the next step.

1. Download the latest version of [Apache Hive](https://dlcdn.apache.org/hive/) (it's not available on AUR yet).

    Alternatively, you can also use my local `PKGBUILD` [config](/_misc/arch_package/apache-hive/). See how to install local package manually from the [Arch wiki](https://wiki.archlinux.org/title/Arch_User_Repository#Installing_and_upgrading_packages). You can skip a few steps ahead if you're using this method.

1. Create a new user called `hive` (or just use `hadoop`, it will also work).

    ``` sh
    sudo -i

    getent group hive || groupadd hive
	getent passwd hive || useradd -g hive -r -d /var/lib/hive hive
    mkdir -p /var/{lib,log}/hive
    chown -R hive:hive /var/{lib,log}/hive

    exit
    ```

    Also create the user on the database. On PostgreSQL, you can do this:

    ``` sh
    # Login as user "postgres"
    sudo -i -u postgres
    # Create a new user on PostgreSQL
    # You should limit the new user privileges
    createuser --interactive

    # Enter name of role to add: hive
    # Shall the new role be a superuser? (y/n) n
    # Shall the new role be allowed to create databases? (y/n) y
    # Shall the new role be allowed to create more new roles? (y/n) n

    # Create a password for the new user "hive"
    psql -c "ALTER USER hive PASSWORD 'hive';"

    exit
    ```

    Also, please create a database named `hive_metastore` (or any other name) to be used by Hive later (I recommend using DBeaver if you prefer using GUI tool). If you don't want to use GUI tool, use this command (for PostgreSQL):

    ``` sh
    # Login as user "hive"
    sudo -i -u hive
    # Create a new database
    createdb hive_metastore
    exit
    ```

1. Go to the download folder (`cd download-folder`). Extract the downloaded archive to `/opt/apache-hive` by using:

    ``` sh
    sudo tar -xvf apache-hive-X.X.X-bin.tar.gz -C /opt/
    # Rename the root folder to "apache-hive"
    sudo mv /opt/apache-hive-X.X.X-bin /opt/apache-hive
    ```

1. Create a new `profile.d` env script (`sudo nano /etc/profile.d/apache-hive.sh`) with content like this:

    ``` sh
    export HIVE_HOME=/opt/apache-hive
    export HIVE_LOG_DIR=/var/log/hive
    export PATH=$PATH:$HIVE_HOME/bin
    ```
    Load the new env vars by running `source /etc/profile.d/apache-hive.sh` on your shell (e.g. Bash, Zsh).

1. Create `hive-site.xml`, either by copying (`cp /opt/apache-hive/conf/hive-default.xml /opt/apache-hive/conf/hive-site.xml`) or directly creating the file (`sudo nano /opt/apache-hive/conf/hive-site.xml`).

1. Modify `hive-site.xml` to use either PostgreSQL or MariaDB (MySQL):

    ``` xml
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

    <configuration>
        <property>
            <name>javax.jdo.option.ConnectionURL</name>
            <value>jdbc:postgresql://localhost:5432/hive_metastore</value>
        </property>
        <property>
            <name>javax.jdo.option.ConnectionDriverName</name>
            <value>org.postgresql.Driver</value>
        </property>
        <property>
            <name>javax.jdo.option.ConnectionUserName</name>
            <value>hive</value>
        </property>
        <property>
            <name>javax.jdo.option.ConnectionPassword</name>
            <value>hive</value>
        </property>
    </configuration>
    ```

    Note that `5432` is the port used by PostgreSQL, while `hive_metastore` is the database name to be used. If you use MariaDB, replace `postgresql` with `mysql` and the port with `3306`.

1. You will need to initialize to database schema first using `schematool -dbType postgres -initSchema` (replace `postgres` with `mysql` for MariaDB user).

1. Start the needed Hive services (check available service by using `hive --service help`):

    ``` sh
    hive --service metastore --hiveconf hive.root.logger=INFO,console
    hive --service hiveserver2 --hiveconf hive.root.logger=INFO,console
    ```

    Run both commands in separate terminal if needed. Alternatively, you can run it as services, create the files below:

    - `/usr/lib/systemd/system/hive-hiveserver2.service`

        ``` ini
        [Unit]
        Description=Hive Server2
        After=network-online.target

        [Service]
        Type=simple
        User=hive
        Group=hive
        EnvironmentFile=/etc/conf.d/apache-hive
        ExecStart=/opt/apache-hive/bin/hive --service hiveserver2 --hiveconf hive.root.logger=INFO,console

        [Install]
        WantedBy=multi-user.target
        ```

    - `/usr/lib/systemd/system/hive-metastore.service`

        ``` ini
        [Unit]
        Description=Hive Metastore
        After=network-online.target

        [Service]
        Type=simple
        User=hive
        Group=hive
        EnvironmentFile=/etc/conf.d/apache-hive
        ExecStart=/opt/apache-hive/bin/hive --service metastore --hiveconf hive.root.logger=INFO,console

        [Install]
        WantedBy=multi-user.target
        ```

    - `/etc/conf.d/apache-hive` (see `/etc/conf.d/hadoop` for reference)

        ``` ini
        HADOOP_COMMON_LIB_NATIVE_DIR=/usr/lib
        HADOOP_CONF_DIR=/etc/hadoop
        HADOOP_LOG_DIR=/var/log/hadoop
        HADOOP_USERNAME=hadoop

        HIVE_HOME=/opt/apache-hive
        HIVE_LOG_DIR=/var/log/hive

        JAVA_HOME=/usr/lib/jvm/java-8-openjdk
        ```

    Then, you can start them by using:

    ``` sh
    sudo systemctl start hive-metastore
    sudo systemctl start hive-hiveserver2
    ```

1. Install `net-tools` and use `sudo netstat -plnt` to see all used ports. This can be used to detect whether Hive/Hadoop/Spark is working correctly or not.

    Hive `metastore` should use port `9083`, while `hiveserver2` should use port `10000`/`10001` by default. You can also access Hive web UI by accessing `localhost:10002`.
    
    In my case, port `10000` is not listening, it turns out `hiveserver2` will not output error directly and will keep running even if an error occurred. Check the log from `/tmp/username/hive.log` and `/var/log/hive`, I got the `AppClassLoader cannot be cast` error. After searching on Google, it seems that Hive is still [not designed for Java 11](https://github.com/apache/hive/blob/da13ee3d39bd825c1c7b86a76b68a0177008456e/pom.xml#L68) yet (per Hive v3.1.3).

1. Try connecting to `hive2` database by using `beeline -u jdbc:hive2://localhost:10000/default -n hive -p hive`.

    If you get `hadoop is not allowed to impersonate hive` error, modify `/opt/apache-hive/conf/hive-site.xml` (don't delete the existing config):

    ``` xml
    <property>
        <name>hive.server2.enable.doAs</name>
        <value>false</value>
    </property>
    ```

    Note that it may be dangerous for production, but other method I tried doesn't work. If no more error occurred when re-running Hive and `beeline`, just `!quit` since we have nothing more to test.

1. Done, go back to configure Apache Spark (see [above](#configuring-apache-spark)).

</details>

## Configuring Java Environment

There are 2 types of Java environment, JDK and JRE. JRE is the lightweight version and only used to run Java application. JDK is the full version of Java which is usually used as `JAVA_HOME` and contains the compiler (`javac`). 

<details>
<summary>Expand</summary>

1. See what Java environments are installed on your machine by using `archlinux-java status`.

1. Check whether JDK exists by running `where javac`. If not, you may need to install one. Use `sudo pacman -S XXX-openjdk`, where `XXX` can be either `jdk` (Java latest), `jdk8` (Java 8), `jdk11` (Java 11), and so on.

    As of Hive v3.1.3, Java 11 is still not fully supported so it's safer to use Java 8.

1. Recheck the Java environments by running `archlinux-java status` (again).

1. Reset the Java environment by running `sudo archlinux-java set XXX` (optional), where `XXX` can be known from the previous command.

</details>

## References
- Apache Hadoop [documentation](https://hadoop.apache.org/docs/stable/).
- Apache Hive [getting started](https://cwiki.apache.org/confluence/display/hive/gettingstarted) (also [here](https://cwiki.apache.org/confluence/display/Hive/AdminManual+Configuration) and [there](https://cwiki.apache.org/confluence/display/Hive/HiveServer2+Clients)).
- Apache Spark [documentation](https://spark.apache.org/docs/latest/).
- PySpark [getting started](https://spark.apache.org/docs/latest/api/python/getting_started/index.html).
- Pier Taranti's Hadoop, Hive, Spark setup on [Medium](https://towardsdatascience.com/assembling-a-personal-data-science-big-data-laboratory-in-a-raspberry-pi-4-or-vms-cluster-e4c5a0473025).