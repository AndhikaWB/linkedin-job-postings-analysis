export HADOOP_COMMON_LIB_NATIVE_DIR=/usr/lib
export HADOOP_CONF_DIR=/etc/hadoop
export HADOOP_LOG_DIR=/var/log/hadoop
export HADOOP_USERNAME=hadoop

# These variables below were personally added by me
# They don't exist if you download directly from AUR

export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop
export HDFS_SECONDARYNAMENODE_USER=hadoop
export YARN_NODEMANAGER_USER=hadoop
export YARN_RESOURCEMANAGER_USER=hadoop

JAVA_HOME=/usr/lib/jvm/java-8-openjdk
