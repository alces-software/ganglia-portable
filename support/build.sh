#!/bin/bash -ex

yum groupinstall -y "Development Tools"
yum install -y rrdtool rrdtool-devel expat-devel expat-static pcre pcre-devel pcre-static zlib-devel zlib-static glibc-static wget

mkdir -p /tmp/build
cd /tmp/build

wget https://github.com/martinh/libconfuse/releases/download/v3.2.2/confuse-3.2.2.tar.gz
wget http://www.mirrorservice.org/sites/ftp.apache.org//apr/apr-1.7.0.tar.gz
wget https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/3.7.2/ganglia-3.7.2.tar.gz

tar -zxvf confuse-3.2.2.tar.gz
tar -zxvf apr-1.7.0.tar.gz
tar -zxvf ganglia-3.7.2.tar.gz

cd confuse-3.2.2
./configure --prefix=/tmp/build/confuse
make
make install
cd ..

cd apr-1.7.0
./configure --prefix=/tmp/build/apr
make
make install
cd ..

cd ganglia-3.7.2
sed -i 's/LIB_SUFFIX=lib64/LIB_SUFFIX=lib/' configure
./configure --with-gmetad --prefix=/tmp/build/ganglia --with-libapr=/tmp/build/apr/bin/apr-1-config --with-libconfuse=/tmp/build/confuse
make
cd gmond
/bin/sh ../libtool --tag=CC   --mode=link gcc -std=gnu99 -I../lib -I../include/ -I../libmetrics -D_LARGEFILE64_SOURCE -DSFLOW -g -O2 -I/tmp/build/confuse/include -fno-strict-aliasing -Wall -D_REENTRANT -export-dynamic -L/tmp/build/apr/lib -L/tmp/build/confuse/lib -o gmond gmond.o cmdline.o g25_config.o core_metrics.o sflow.o ../libmetrics/libmetrics.la ../lib/libganglia.la ../lib/libgetopthelper.a  -ldl /usr/lib64/libnsl.a /usr/lib64/libz.a /usr/lib64/libpcre.a /usr/lib64/libexpat.a /tmp/build/confuse/lib/libconfuse.a /tmp/build/apr/lib/libapr-1.a -lpthread
gcc -std=gnu99 -I../lib -I../include/ -I../libmetrics -D_LARGEFILE64_SOURCE -DSFLOW -g -O2 -fno-strict-aliasing -Wall -D_REENTRANT -fPIE -o gmond gmond.o cmdline.o g25_config.o core_metrics.o sflow.o modules/disk/.libs/mod_disk.o modules/cpu/.libs/mod_cpu.o modules/cpu/.libs/mod_load.o modules/memory/.libs/mod_mem.o modules/network/.libs/mod_net.o modules/system/.libs/mod_proc.o modules/system/.libs/mod_sys.o modules/cpu/.libs/mod_multicpu.o -Wl,--export-dynamic  ../libmetrics/.libs/libmetrics.a /usr/lib64/libresolv.a ../lib/.libs/libganglia.a /tmp/build/apr/lib/libapr-1.a /tmp/build/confuse/lib/libconfuse.a ../lib/libgetopthelper.a -L/tmp/build/confuse/lib -ldl /usr/lib64/libnsl.a /usr/lib64/libz.a /usr/lib64/libpcre.a /usr/lib64/libexpat.a -lpthread -pthread -Wl,-rpath -Wl,/usr/lib64 -Wl,-rpath -Wl,/usr/lib64
cd ..
make install

cp -Rv /tmp/build/confuse/lib/* /tmp/build/ganglia/lib64/.
cp -Rv /tmp/build/apr/lib/* /tmp/build/ganglia/lib64/.

mkdir -p /var/lib/ganglia/rrds
chown nobody /var/lib/ganglia/rrds

cat << 'EOF' > /tmp/build/ganglia/sbin/gmetad_wrapper.sh
#!/bin/bash

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SOURCEDIR/../lib64

exec $SOURCEDIR/gmetad $@
EOF

cat << 'EOF' > /tmp/build/ganglia/sbin/gmond_wrapper.sh
#!/bin/bash

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SOURCEDIR/../lib64

exec $SOURCEDIR/gmond --conf=${SOURCEDIR}/../etc/gmond.conf $@
EOF

cat << 'EOF' > /tmp/build/ganglia/sbin/gmond_monhost_wrapper.sh
#!/bin/bash

SOURCEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SOURCEDIR/../lib64

exec $SOURCEDIR/gmond --conf=${SOURCEDIR}/../etc/gmond_monhost.conf $@
EOF

cat << 'EOF' > /tmp/build/ganglia/etc/gmetad.conf
data_source 'mycluster' localhost:8659
gridname 'mycluster'
case_sensitive_hostnames 0
setuid_username nobody
EOF

cat << EOF > /tmp/build/ganglia/etc/gmond_monhost.conf

globals {
  daemonize = yes
  setuid = yes
  user = nobody
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  allow_extra_data = yes
  host_dmax = 86400 /* Remove host from UI after it hasn't report for a day */
  host_tmax = 20
  cleanup_threshold = 300 /*secs */
  gexec = no
  send_metadata_interval = 30 /*secs */
}

cluster {
  name = "mycluster"
}

udp_send_channel {
  host = 10.100.0.90
  port = 8649
  ttl = 1
}

udp_recv_channel {
  port = 8649
}

tcp_accept_channel {
  port = 8659
  gzip_output = no
}

collection_group {
  collect_once = yes
  time_threshold = 20
  metric {
    name = "heartbeat"
  }
}

modules {
  module {
    name = "core_metrics"
  }
  module {
    name = "cpu_module"
    path = "modcpu.so"
  }
  module {
    name = "disk_module"
    path = "moddisk.so"
  }
  module {
    name = "load_module"
    path = "modload.so"
  }
  module {
    name = "mem_module"
    path = "modmem.so"
  }
  module {
    name = "net_module"
    path = "modnet.so"
  }
  module {
    name = "proc_module"
    path = "modproc.so"
  }
  module {
    name = "sys_module"
    path = "modsys.so"
  }
}

collection_group {
  collect_every = 60
  time_threshold = 60
  metric {
    name = "cpu_num"
    title = "CPU Count"
  }
  metric {
    name = "cpu_speed"
    title = "CPU Speed"
  }
  metric {
    name = "mem_total"
    title = "Memory Total"
  }
  metric {
    name = "swap_total"
    title = "Swap Space Total"
  }
  metric {
    name = "boottime"
    title = "Last Boot Time"
  }
  metric {
    name = "machine_type"
    title = "Machine Type"
  }
  metric {
    name = "os_name"
    title = "Operating System"
  }
  metric {
    name = "os_release"
    title = "Operating System Release"
  }
  metric {
    name = "location"
    title = "Location"
  }
}
collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
    title = "Gexec Status"
  }
}
collection_group {
  collect_every = 20
  time_threshold = 90
  metric {
    name = "cpu_user"
    value_threshold = "1.0"
    title = "CPU User"
  }
  metric {
    name = "cpu_system"
    value_threshold = "1.0"
    title = "CPU System"
  }
  metric {
    name = "cpu_idle"
    value_threshold = "5.0"
    title = "CPU Idle"
  }
  metric {
    name = "cpu_nice"
    value_threshold = "1.0"
    title = "CPU Nice"
  }
  metric {
    name = "cpu_aidle"
    value_threshold = "5.0"
    title = "CPU aidle"
  }
  metric {
    name = "cpu_wio"
    value_threshold = "1.0"
    title = "CPU wio"
  }
  metric {
    name = "cpu_steal"
    value_threshold = "1.0"
    title = "CPU steal"
  }
}
collection_group {
  collect_every = 20
  time_threshold = 90
  metric {
    name = "load_one"
    value_threshold = "1.0"
    title = "One Minute Load Average"
  }
  metric {
    name = "load_five"
    value_threshold = "1.0"
    title = "Five Minute Load Average"
  }
  metric {
    name = "load_fifteen"
    value_threshold = "1.0"
    title = "Fifteen Minute Load Average"
  }
}
collection_group {
  collect_every = 80
  time_threshold = 950
  metric {
    name = "proc_run"
    value_threshold = "1.0"
    title = "Total Running Processes"
  }
  metric {
    name = "proc_total"
    value_threshold = "1.0"
    title = "Total Processes"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "mem_free"
    value_threshold = "1024.0"
    title = "Free Memory"
  }
  metric {
    name = "mem_shared"
    value_threshold = "1024.0"
    title = "Shared Memory"
  }
  metric {
    name = "mem_buffers"
    value_threshold = "1024.0"
    title = "Memory Buffers"
  }
  metric {
    name = "mem_cached"
    value_threshold = "1024.0"
    title = "Cached Memory"
  }
  metric {
    name = "swap_free"
    value_threshold = "1024.0"
    title = "Free Swap Space"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 300
  metric {
    name = "bytes_out"
    value_threshold = 4096
    title = "Bytes Sent"
  }
  metric {
    name = "bytes_in"
    value_threshold = 4096
    title = "Bytes Received"
  }
  metric {
    name = "pkts_in"
    value_threshold = 256
    title = "Packets Received"
  }
  metric {
    name = "pkts_out"
    value_threshold = 256
    title = "Packets Sent"
  }
}
collection_group {
  collect_every = 1800
  time_threshold = 3600
  metric {
    name = "disk_total"
    value_threshold = 1.0
    title = "Total Disk Space"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "disk_free"
    value_threshold = 1.0
    title = "Disk Space Available"
  }
  metric {
    name = "part_max_used"
    value_threshold = 1.0
    title = "Maximum Disk Space Used"
  }
}
EOF

cat << EOF > /tmp/build/ganglia/etc/gmond.conf

globals {
  daemonize = yes
  setuid = yes
  user = nobody
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  allow_extra_data = yes
  host_dmax = 86400 /* Remove host from UI after it hasn't report for a day */
  host_tmax = 20
  cleanup_threshold = 300 /*secs */
  gexec = no
  send_metadata_interval = 30 /*secs */
}

cluster {
  name = "mycluster"
}

udp_send_channel {
  host = 10.100.0.90
  port = 8649
  ttl = 1
}

collection_group {
  collect_once = yes
  time_threshold = 20
  metric {
    name = "heartbeat"
  }
}

modules {
  module {
    name = "core_metrics"
  }
  module {
    name = "cpu_module"
    path = "/tmp/ganglia/lib64/ganglia/modcpu.so"
  }
  module {
    name = "disk_module"
    path = "/tmp/ganglia/lib64/ganglia/moddisk.so"
  }
  module {
    name = "load_module"
    path = "/tmp/ganglia/lib64/ganglia/modload.so"
  }
  module {
    name = "mem_module"
    path = "/tmp/ganglia/lib64/ganglia/modmem.so"
  }
  module {
    name = "net_module"
    path = "/tmp/ganglia/lib64/ganglia/modnet.so"
  }
  module {
    name = "proc_module"
    path = "/tmp/ganglia/lib64/ganglia/modproc.so"
  }
  module {
    name = "sys_module"
    path = "/tmp/ganglia/lib64/ganglia/modsys.so"
  }
}

collection_group {
  collect_every = 60
  time_threshold = 60
  metric {
    name = "cpu_num"
    title = "CPU Count"
  }
  metric {
    name = "cpu_speed"
    title = "CPU Speed"
  }
  metric {
    name = "mem_total"
    title = "Memory Total"
  }
  metric {
    name = "swap_total"
    title = "Swap Space Total"
  }
  metric {
    name = "boottime"
    title = "Last Boot Time"
  }
  metric {
    name = "machine_type"
    title = "Machine Type"
  }
  metric {
    name = "os_name"
    title = "Operating System"
  }
  metric {
    name = "os_release"
    title = "Operating System Release"
  }
  metric {
    name = "location"
    title = "Location"
  }
}
collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
    title = "Gexec Status"
  }
}
collection_group {
  collect_every = 20
  time_threshold = 90
  metric {
    name = "cpu_user"
    value_threshold = "1.0"
    title = "CPU User"
  }
  metric {
    name = "cpu_system"
    value_threshold = "1.0"
    title = "CPU System"
  }
  metric {
    name = "cpu_idle"
    value_threshold = "5.0"
    title = "CPU Idle"
  }
  metric {
    name = "cpu_nice"
    value_threshold = "1.0"
    title = "CPU Nice"
  }
  metric {
    name = "cpu_aidle"
    value_threshold = "5.0"
    title = "CPU aidle"
  }
  metric {
    name = "cpu_wio"
    value_threshold = "1.0"
    title = "CPU wio"
  }
  metric {
    name = "cpu_steal"
    value_threshold = "1.0"
    title = "CPU steal"
  }
}
collection_group {
  collect_every = 20
  time_threshold = 90
  metric {
    name = "load_one"
    value_threshold = "1.0"
    title = "One Minute Load Average"
  }
  metric {
    name = "load_five"
    value_threshold = "1.0"
    title = "Five Minute Load Average"
  }
  metric {
    name = "load_fifteen"
    value_threshold = "1.0"
    title = "Fifteen Minute Load Average"
  }
}
collection_group {
  collect_every = 80
  time_threshold = 950
  metric {
    name = "proc_run"
    value_threshold = "1.0"
    title = "Total Running Processes"
  }
  metric {
    name = "proc_total"
    value_threshold = "1.0"
    title = "Total Processes"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "mem_free"
    value_threshold = "1024.0"
    title = "Free Memory"
  }
  metric {
    name = "mem_shared"
    value_threshold = "1024.0"
    title = "Shared Memory"
  }
  metric {
    name = "mem_buffers"
    value_threshold = "1024.0"
    title = "Memory Buffers"
  }
  metric {
    name = "mem_cached"
    value_threshold = "1024.0"
    title = "Cached Memory"
  }
  metric {
    name = "swap_free"
    value_threshold = "1024.0"
    title = "Free Swap Space"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 300
  metric {
    name = "bytes_out"
    value_threshold = 4096
    title = "Bytes Sent"
  }
  metric {
    name = "bytes_in"
    value_threshold = 4096
    title = "Bytes Received"
  }
  metric {
    name = "pkts_in"
    value_threshold = 256
    title = "Packets Received"
  }
  metric {
    name = "pkts_out"
    value_threshold = 256
    title = "Packets Sent"
  }
}
collection_group {
  collect_every = 1800
  time_threshold = 3600
  metric {
    name = "disk_total"
    value_threshold = 1.0
    title = "Total Disk Space"
  }
}
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "disk_free"
    value_threshold = 1.0
    title = "Disk Space Available"
  }
  metric {
    name = "part_max_used"
    value_threshold = 1.0
    title = "Maximum Disk Space Used"
  }
}
EOF

chmod +x /tmp/build/ganglia/sbin/*

cd /tmp/build
tar -zcvf /tmp/ganglia.tar.gz ganglia
