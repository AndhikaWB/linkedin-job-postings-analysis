## Important

- This guide is intended for Arch Linux only or its derivative (Manjaro, Endeavour, Garuda, etc). The package name, package manager, and directory structure may vary for other Linux distributions. See [_misc / arch_package](_misc/arch_package/) for details.

- Always double check every path, especially when writing config files! Even if you're on Arch Linux, package maintainers may also change (which may break old things), so proceed with caution.

- Update your system first before attempting to do anything in this guide (e.g. `sudo pacman -Syyu`).

## Step-by-Step Guide

1. Install and configure Apache Spark (see [below](#configuring-apache-spark)).

1. Install and configure Metabase (see [below](#configuring-metabase)).

1. Create Python virtual environment. You can use `Ctrl + Shift + P` on VS Code, or run `python -m venv .venv` on project folder directly. By using virtual environment, all dependencies will be installed in the project folder.

1. Install all pip requirements (`pip install -r requirements.txt`), which also contains the needed `pyspark` library.

    PySpark may also be bundled within Apache Spark itself, but you will need to set `PYTHONPATH` [manually](https://spark.apache.org/docs/latest/api/python/getting_started/install.html#manually-downloading) (so the Python library can be detected). However, if you're installing from AUR, by default it doesn't include the Python folder/library so `pyspark` will still be needed.

1. Start experimenting using the [notebook](main.ipynb) file.

## Configuring Apache Spark

Using Apache Spark, we can execute queries and create tables without affecting the real database. This is ideal for production environment.

<details>
<summary>Expand</summary>

1. [Configure Apache Hadoop](#configuring-apache-hadoop) first. It's needed because currently Metabase only support Spark SQL connection using Hive.

    However, if you are very lazy, you can just connect to MariaDB or PostgreSQL using Metabase directly, but then most of this guide will be pointless.

1. Install Apache Spark from AUR (`yay -S apache-spark`). Despite its package name, it will use the binary release instead of compiling from source code. If you prefer compiling, use `apache-spark-git` instead.

1. Check whether Spark is registered to `PATH` or not by running `spark-shell --version` or `where spark-shell`. If not, create a new profile file (e.g. `sudo nano /etc/profile.d/apache-spark.sh`) with content similar to this:

    ``` sh
    export PATH=$PATH:/opt/apache-spark/bin:/opt/apache-spark/sbin
    ```

    Load the new change by running `source /etc/profile.d/apache-spark.sh` on your shell (e.g. Bash, Zsh).

1. It's done! See the [notebook](main.ipynb) file to connect to existing database using `pyspark` (finish all setup in the guide first).

</details>

## Configuring Metabase

Metabase is a business intelligence, dashboard, and data visualization tool. It has many alternatives such as Power BI, Tableau, Superset, Redash, and Grafana. There are some interesting insights which made me choose Metabase, see [here](https://medium.com/vortechsa/choosing-an-analytics-tool-metabase-vs-superset-vs-redash-afd88e028ba9) and [here](https://community.grafana.com/t/business-operational-dashboards-use-cases-for-grafana/36235). However, please do your own research before deciding!

<details>
<summary>Expand</summary>

1. If you haven't installed any database yet, refer to the Arch wiki to set up either [PostgreSQL](https://wiki.archlinux.org/title/PostgreSQL) or [MariaDB](https://wiki.archlinux.org/title/MariaDB). This step is optional but very recommended.

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
    # These may be different based on your database setup
    MB_DB_PORT=5432
    MB_DB_USER=root
    MB_DB_PASS=root
    MB_DB_DBNAME=metabase
    ```

1. After changing the config file, you should not run `metabase` directly. You need to run it as service (`sudo systemctl start metabase`), otherwise it won't detect the config file and may create some stuff directly on your home directory.

    If you want to run it automatically on startup, use `sudo systemctl enable metabase` (will take about 800 MB of RAM on idle). You can also check the service status by using `sudo systemctl status metabase`.

1. Set up Metabase account, data source (SparkSQL), etc by going to `localhost:3000` (you can do this later). Make sure you already set up Apache Spark (and PySpark) correctly, otherwise you won't be able to connect to data source.

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

    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    ```

    Load the new env vars by running `source /etc/profile.d/hadoop.sh` on your shell (e.g. Bash, Zsh).

    :red_circle: **Important:** When running program as root (e.g. by using `sudo`), it will not load user env vars from `/etc/profile.d` by default, so you may need to use `sudo -i` (to invoke the login shell) if Hadoop still complains about missing variables.

    Also, other than `/etc/profile.d/hadoop.sh`, Hadoop env file is also located at `/etc/hadoop/hadoop-env.sh`. The Arch [wiki](https://wiki.archlinux.org/title/Hadoop) recommend editing `JAVA_HOME` in that file instead, but it will be easier for us to just modify one file.

1. After that, you can also modify `/etc/conf.d/hadoop` file with content similar to `/etc/profile.d/hadoop.sh`, but remove the `export` and any shell variable (because it's not a shell file).

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

    # Create /mnt/hadoop/username (e.g. hadoop)
    sudo mkdir /mnt/hadoop/hadoop
    # User and group to own the directory (e.g. hadoop:hadoop)
    sudo chown hadoop:hadoop /mnt/hadoop/hadoop
    ```

    :red_circle: **Important:** Make sure you consistently use the same username and group (it will be used again at later step), or just use `hadoop` if you're not sure because the services/daemons also use that by default. The DFS directory config we created previously is also based on username, so changing users may cause path and permission issues.

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
    sudo -u hadoop /bin/bash

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

1. If everything works correctly, then continue to configure Apache Hive (see [below](#configuring-apache-hive)).

</details>

## Configuring Java Environment

There are 2 types of Java environment, JDK and JRE. JRE is the lightweight version and only used to run Java application. JDK is the full version of Java which can be used as `JAVA_HOME` and contains the compiler (`javac`). 

<details>
<summary>Expand</summary>

1. See what Java environments are installed on your machine by using `archlinux-java status`.

1. Check whether JDK exists by running `where javac`. If not, you may need to install one. Use `sudo pacman -S XXX-openjdk`, where `XXX` can be either `jdk` (Java latest), `jdk11` (Java 11), `jdk17` (Java 17), and so on.

    However, it's recommended to use the widely supported Java version, which is currently `jdk11` (Java 11). Not all Java apps are compatible to be run using the latest Java version.

1. Recheck the Java environments by running `archlinux-java status` (again).

1. Reset the Java environment by running `sudo archlinux-java set XXX` if needed, where `XXX` can be known from the previous command.

</details>

## Configuring Apache Hive
Apache Hive is a data warehouse system built on top of Hadoop for providing data query and analysis.

<details>
<summary>Expand</summary>

1. TODO (it doesn't exist yet on AUR, lol)

</details>

## Dataset Source
- [LinkedIn Job Postings - 2023](https://www.kaggle.com/datasets/arshkon/linkedin-job-postings) by Arsh Kon on Kaggle