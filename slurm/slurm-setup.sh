#!/bin/bash
if [ "$username" == "" ]; 
then
  echo "Please set username in the env!"
  exit 1
fi

# setup and install repos and rpms from repos
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
rpm -Uvh http://repo.grid.iu.edu/osg/3.3/osg-3.3-el6-release-latest.rpm
yum install -y yum-plugin-priorities
yum install -y MySQL-python readline-devel openssl-devel munge-devel munge-libs pam-devel
yum install -y rpm-build
yum install -y mysql-server mysql-devel

# build and install slurm
wget 'http://www.schedmd.com/download/total/slurm-14.11.7.tar.bz2'
rpmbuild -tb slurm-14.11.7.tar.bz2
cur_dir=`pwd`
cd /root/rpmbuild/RPMS/x86_64/
yum install -y slurm-14.11.7-1.el6.x86_64.rpm slurm-munge-14.11.7-1.el6.x86_64.rpm  slurm-torque-14.11.7-1.el6.x86_64.rpm  slurm-sql-14.11.7-1.el6.x86_64.rpm  slurm-perlapi-14.11.7-1.el6.x86_64.rpm slurm-plugins-14.11.7-1.el6.x86_64.rpm slurm-slurmdbd-14.11.7-1.el6.x86_64.rpm
cd -

# copy config files
cp ./slurm.conf /etc/slurm/slurm.conf
cp ./slurmdbd.conf /etc/slurm/slurmdbd.conf

#setup config files
local_hostname=`hostname -s`
perl -pi -e "s/HOSTNAME/$local_hostname/g" /etc/slurm/slurm.conf


#setup mysql
service mysqld start
echo "create database slurm_acct_db;" | mysql -u root
echo "create user 'slurm'@'localhost';" | mysql -u root mysql
echo "grant usage on *.* to 'slurm'@'localhost';" | mysql -u root mysql 
echo "grant all privileges on slurm_acct_db.* to 'slurm'@'localhost' identified by 'password';" | mysql -u root mysql
echo "flush privileges;" | mysql -u root mysql

# add slurm user
useradd slurm

# setup log files
mkdir /var/spool/slurm
chown -R slurm:slurm /var/spool/slurm
mkdir /var/log/slurm
chown -R slurm:slurm /var/log/slurm
mkdir /var/lib/slurm
chown -R slurm:slurm /var/lib/slurm

#munge setup
create-munge-key
service munge start


service slurmdbd start
service slurm start

#add cluster
sacctmgr -i add cluster itb_test

service slurmdbd restart

# add osg user map
mkdir /var/lib/osg
chmod 755 /var/lib/osg
cp ./user-vo-map /var/lib/osg/user-vo-map
perl -pi -e "s/USERNAME/$username/g" /var/lib/osg/user-vo-map

cd $cur_dir
yum install -y gratia-probe-slurm
echo "password" > /etc/gratia/slurm/pwfile
chmod 600 /etc/gratia/slurm/pwfile
perl -pi -e "s/db.cluster.example.edu/localhost/" /etc/gratia/slurm/ProbeConfig
perl -pi -e "s/mycluster/itb_test/" /etc/gratia/slurm/ProbeConfig
perl -pi -e "s/EnableProbe=\"0\"/EnableProbe=\"1\"/" /etc/gratia/slurm/ProbeConfig
perl -pi -e "s/SiteName=\"Generic site\"/SiteName=\"itb site\"/" /etc/gratia/slurm/ProbeConfig
vim /etc/gratia/slurm/ProbeConfig
service slurm start
service gratia-probes-cron start
scontrol update nodename=$local_hostname state=idle
