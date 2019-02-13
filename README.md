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
2. Join all database server (DBS) and 1 Web Administration Server (WAS), and 1 Single Sign On Server (SSOS) into domain
3. Configure all DBS, to support kerberos authentication (pam_gssapi)
4. Configure SSOS, to allow IPA user login via OPENID/Oauth2
5. Install and Configure WAS so that every individual dba have dedicated php-fpm running background

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
7. Your database server is work fine, and you can define which dba can access this database server as grant command at step 5.


Setup Web Administration Server (WAS)
=====================================
1. Setup ubuntu 18.04, update latest, set host as wds.int.mydomain.com (192.168.0.100/24)
2. You may required additional network interface with public ip, so that dba can access via internet (example 100.100.100.100)
3. Join into freeipa
4. define HBAC rules to allow dba1/2... to access this server
5. run script as https://gist.github.com/kstan79/028df3e715cac2b4d63e0b003b1233c7 (may need to tweak according php version or etc)
6. Download adminer https://www.adminer.org
7. ssh dba1 into wds.int.mydomain.com, run `php -S '0.0.0.0:9999' adminer.php`, then using browser to browse http://192.168.0.100:9999
8. From web interface, put driver: mysql, server: 192.168.0.10, user: dba1, pass: <any u wish>. You shall able to access db1 as expected

[Remarks]
* we required dba1 login via ssh, start own php services via port 9999, then web interface able to borrow kerberos credential to access mysql
* if we have 100 dba, we required 100 dba ssh into WAS, and start own php services using different port number
* this allow dba manage all db server under INT.MYDOMAIN.COM, but it is totally not secure, dont stop here, suitable approache to secure web interface is using OPENID/Oauth2 hookup freeipa user database
* when dba1 close ssh, the port 9999 not accessible anymore, we need to make individual session run as background services
* adminer required us to define database server ourself, we wish to define database server list in setting file, then we can pick which server to login easily.



Setup Single Sign On Server (Keycloak)
==================================
1. Setup ubuntu server, set host as keycloak.int.mydomain.com (192.168.0.200/24), update to latest and install ssh and screen (learn how to use ctrl-a = switch session,ctrl-a-c = create new session, ctl-a-d = detash session)
2. You required to setup additional network interface and public ip so that dba can access via internet (example 100.100.100.101)
3. Join into ipa
4. login as admin (from INT.MYDOMAIN.COM) via ssh, install keycloak at /opt using guide: https://www.keycloak.org/docs/latest/getting_started/index.html
5. under screen, start standalone instance, and detach via ctrl-a-d so that terminate ssh the keycloak remain running
6. login to http://192.168.0.200/auth/admin, create any new real: int.mydomain.com. access to new realm
7. Under user federation, add ldap provider, define display name 'int.mydomain.com', override 
```
UUID LDAP attribute = uid
Connection URL = ldap://192.168.0.1 
Users DN = cn=users,cn=accounts,dc=int,dc=myexample,dc=com
Bind DN = uid=admin,cn=users,cn=accounts,dc=int,dc=myexample,dc=com
Bind Credential = your_admin_password
```
8. Try test connection and test authentication, you shall get successful result
9. Save and Syncronize all user, you will notice dba1,2.... all will sync into keycloak
10.Go to 'Clients', add new client id `dba-sso`, Root URL  `https://192.168.0.100`, save
11.Change setting:
```
Enable = On
Consent Required = On
Display Client On Consent Screen = On
Access Type = Confidential
Valid Redirect URIs = https://192.168.0.100/*, https://WAS_public_URL/*
```
12. Save, and switch to 'Credentials', remain client authenticator as 'Client and Secret', copy string `Secret' (xxxxx-xxx-xx-xxx)
[Remark]
* You keycloak have individual user database, in our case it sync from freeipa, and every online authentication it will check via freeipa. in another word, freeipa user/password = mariadb user/password = keycloak user/password
* In real environment, you shall have public ip for this server, install nginx to reverse proxy keycloak web ui, secure by ssl

Configure WAS To Support Keycloak and Run Session as PHP-FPM
==================================
This 
