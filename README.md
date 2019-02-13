Introduction
============
Manage many mariadb/mysql server is kind of hassle, and there is no high efficient web management tools to manage multiple mysql/mariadb server effectively. Especially DBA required to access all database servers via different cloud platform. This Repository introduce some database administration philosophy and provide some toolkit/guidance. It take lot of effort but it should working well.

Goal
====
1. DBA can centralize access all DB server via web interface
2. DBA user centralized managed by LDAP
3. Web session secure by single sign on technology


Requirements
============
1. It run on Linux environment (here, we use ubuntu)
2. It required to run FreeIPA (AD may work well with some tweak, but why we need AD?)
3. Single Sign On Server (Keycloak)
4. PHP-FPM7+/Nginx/Adminer
5. Of course, working Domain and SSL

Todo
========
1. Setup 1 Freeipa (Kerberos and Ldap) as identify server (IPA), assume domain int.example.com (Realm INT.EXAMPLE.COM)
2. Join all database server (DBS) and 1 Web Administration Server (WDS), and 1 Single Sign On Server (SSOS) into domain
3. Configure all DBS, to support kerberos authentication (pam_gssapi)
4. Configure SSOS, to allow IPA user login via OPENID/Oauth2
5. Install and Configure WDS so that every individual dba have dedicated php-fpm running background

Setup IPA Server
================
1. Setup Fresh Ubuntu Server 18.04, update to latest.
2. configure your ip as 192.168.0.1/24, hostname ipa.int.mydomain.com (of course, you shall configure firewall/router to allow access remotely via web interface)
3. Refer this link to continue the rest. https://www.server-world.info/en/note?os=Ubuntu_18.04&p=freeipa&f=1
4. Now, you shall able to access https://192.168.0.1 and with 1 admin user.
5. Create more user example dba1, dba2

Setup Database Server
=====================
1. Setup fresh ubuntu server (hostname db1.int.mydomain.com, ip 192.168.0.10/24), install ssh.
2. Join to freeipa realm as https://computingforgeeks.com/how-to-configure-freeipa-client-on-ubuntu-18-04-ubuntu-16-04-centos-7/
3. Allow dba1 and dba2 ssh into db1.int.mydomain.com via Host Base Access Control (HBAC), refer https://www.freeipa.org/page/Main_Page to find suitable article.
3. Install mariadb 10.3 as https://computingforgeeks.com/install-mariadb-10-on-ubuntu-18-04-and-centos-7/
4. Install gssapi plugin into mariadb, https://mariadb.com/kb/en/library/authentication-plugin-gssapi/, but define configuration at `/etc/mysql/config.d/mariadb.cnf` as 
```
[mariadb]
gssapi_keytab_path=/etc/krb5.keytab
gssapi_principal_name=host/db1.int.mydomain.com@INT.MYDOMAIN.COM
```
5. if gssapi plugin installed, and activated correctly run following sql command:
```
INSTALL SONAME 'auth_gssapi';
create database mydb1;
create database mydb2;
grant all on *.* to dba1@'%' identified via gssapi using 'dba1@INT.MYDOMAIN.COM';
flush privileges;
```
6. under terminal, run below command `mysql -u dba1 `, you shall able to see mydb1 and mydb2, without supply password cause it using kerberos session to authenticate.


