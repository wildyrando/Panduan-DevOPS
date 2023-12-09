#!/bin/bash
#
# Panduan installasi LAMP [ MariaDB ]
# Debian 12
#

# >> Silakan masuk ke root user dulu, anda bisa cek root atau tidak menggunakan command ini
if [[ $(whoami) == 'root' ]]; then
  clear && echo "Anda menggunakan user root"
else
  clear && echo "Anda tidak menggunakan user root, silakan ketikan 'sudo su' untuk masuk root"
fi

# >> Langkah 1 [ update repository dan install requirements ]
apt update -y
apt upgrade -y
apt install zip unzip socat curl wget lsb-release ca-certificates -y

# >> Langkah 2 [ install webserver apache2 ]
sudo apt install apache2 -y

# >> Langkah 3 [ issue sertifikat ssl untuk https ] [ opsional ]
curl https://get.acme.sh | sh -s email=emailkamu@gmail.com # email harus valid di karenkan untuk notif saat ssl sudah mau expired

# Setting ssl certificate vendor menjadi letsencrypt
cd /root/.acme.sh # Masuk ke directory acme
./acme.sh --set-default-ca --server letsencrypt

# Lakukan issue certificate [ harus mempunyai domain terpointing A Record ke servernya ]
systemctl stop apache2 # stop apache2 terlebih dahulu supaya tidak bentrok dengan socat
./acme.sh --issue --standalone -d domainkamu.com

# Jika pembuatan sertifikat ssl berhasil maka akan ada text hijau dan copy text 
# Silakan copy text yang ijau seperti bawah ini ke notepad atau mana aja di karenakan akan di gunakan untuk konfigurasi apache2 virtualhost
#
# Example:
# [Sat  9 Dec 18:29:51 CET 2023] Your cert is in:
# [Sat  9 Dec 18:29:51 CET 2023] Your cert key is in:
# [Sat  9 Dec 18:29:51 CET 2023] The intermediate CA cert is in:
# [Sat  9 Dec 18:29:51 CET 2023] And the full chain certs is there:

# >> Langkah 4 [ konfigurasi apache2 virtualhost ]
# Silakan masuk directory config apache
cd /etc/apache2/sites-available

# Buat file konfigurasi
# Contohnya di sini saya akan beri nama konfignya default
nano default.conf

# Anda bisa copy paste config di bawah ini dan edit
<VirtualHost *:443>
    ServerAdmin emailkamu@gmail.com
    ServerName domainkamu.com
    DocumentRoot /var/www/domainkamu.com/

    SSLEngine on
    SSLCertificateFile [pastekan value dari 'Your cert is in:' yang dicopy dari result acme.sh tadi]
    SSLCertificateKeyFile [pastekan value dari 'Your cert key is in:' yang dicopy dari result acme.sh tadi]
    SSLCertificateChainFile [pastekan value dari 'full chain certs' yang dicopy dari result acme.sh tadi]

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/domainkamu.com/>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    Alias /phpmyadmin "/usr/share/phpmyadmin"
    <Directory "/usr/share/phpmyadmin">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:80>
    ServerName domainkamu.com
    Redirect permanent / https://domainkamu.com
</VirtualHost>

# Jika sudah selesai silakan gunakan ctrl + x dan tekan y lalu enter untuk save
# Kemudian silakan buat folder untuk documentroot apachenya
mkdir -p /var/www/domainkamu.com
chown -R www-data:www-data /var/www/domainkamu.com
chmod -R 755 /var/www/domainkamu.com

# Buat file web untuk mengecekan nantinya apakah berhasil install
echo '<h1>Installasi apache telah berhasil</h1>' > /var/www/domainkamu.com/index.html

# Enable ssl-modules dan rewrite modules di apache2
a2enmod ssl
a2enmod rewrite

# Enablekan config yang telah dibuat di virtualhost
a2ensite default # di sini karna tadi saya buat nama dengan default

# Sekarang restart apache2
systemctl restart apache2

# Sekarang coba buka web anda di browser, jika berhasil maka akan muncul text
# Installasi apache telah berhasil dan sudah memiliki SSL [ gembok ] / https

# >> Langkah 5 [ Installasi mariadb ]
apt install mariadb-server -y

# setelah terinstall silakan ketik
mariadb -u root

# Pastekan query berikut untuk konfigurasi user root di apache2
ALTER USER 'root'@'localhost' IDENTIFIED BY 'PASSWORD ROOT KAMU';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;

# Sekarang kita akan install php 8.3
# Menambahkan repository php
curl -o /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

# Update repository
apt update -y
apt upgrade -y

# Install modules php untuk apache
apt install libapache2-mod-php8.3 -y

# Install php 8.3 dan install twig ma pear php untuk phpmyadmin
apt install php8.3 php8.3-mysql php8.3-cli php8.3-opcache php8.3-gd \
php8.3-curl php8.3-cli php8.3-imap php8.3-mbstring php8.3-intl php8.3-soap \
php8.3-ldap php8.3-imagick php8.3-xml php8.3-zip -y
apt install php-twig php-pear -y

# Installasi PhpMyAdmin
wget -O phpmyadmin.zip 'https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip'
unzip -o phpmyadmin.zip
mv phpMyAdmin-5.2.1-all-languages /usr/share/phpmyadmin
rm -rf phpmyadmin.zip
mkdir -p /var/lib/phpmyadmin/tmp
chmod -R 775 /var/lib/phpmyadmin/tmp
chown -R www-data:www-data /var/lib/phpmyadmin/tmp

# Edit konfigurasi phpmyadmin
nano /usr/share/phpmyadmin/config.inc.php

# Pastekan konfigurasi berikut
<?php
    $cfg['Servers'][1]['host'] = 'localhost';
    $cfg['Servers'][1]['user'] = 'root';
    $cfg['Servers'][1]['password'] = 'PASSWORD ROOT KAMU';
    $cfg['Servers'][1]['pmadb'] = 'phpmyadmin';
    $cfg['Servers'][1]['controluser'] = 'phpmyadmin';
    $cfg['Servers'][1]['controlpass'] = 'PASSWORD PHPMYADMIN KAMU';
    $cfg['Servers'][1]['table_info'] = 'pma__table_info';
    $cfg['Servers'][1]['pmadb'] = 'phpmyadmin';
    $cfg['Servers'][1]['bookmarktable'] = 'pma__bookmark';
    $cfg['Servers'][1]['relation'] = 'pma__relation';
    $cfg['Servers'][1]['table_coords'] = 'pma__table_coords';
    $cfg['Servers'][1]['pdf_pages'] = 'pma__pdf_pages';
    $cfg['Servers'][1]['column_info'] = 'pma__column_info';
    $cfg['Servers'][1]['history'] = 'pma__history';
    $cfg['Servers'][1]['table_uiprefs'] = 'pma__table_uiprefs';
    $cfg['Servers'][1]['tracking'] = 'pma__tracking';
    $cfg['Servers'][1]['userconfig'] = 'pma__userconfig';
    $cfg['Servers'][1]['recent'] = 'pma__recent';
    $cfg['Servers'][1]['favorite'] = 'pma__favorite';
    $cfg['Servers'][1]['users'] = 'pma__users';
    $cfg['Servers'][1]['usergroups'] = 'pma__usergroups';
    $cfg['Servers'][1]['navigationhiding'] = 'pma__navigationhiding';
    $cfg['Servers'][1]['savedsearches'] = 'pma__savedsearches';
    $cfg['Servers'][1]['central_columns'] = 'pma__central_columns';
    $cfg['Servers'][1]['designer_settings'] = 'pma__designer_settings';
    $cfg['Servers'][1]['export_templates'] = 'pma__export_templates';
    $cfg['blowfish_secret'] = 'UNTUK BLOW FISH ANDA BISA CARI BLOWFISH GENERATOR SEPERTI https://standingtech.com/blowfish-salt-generator-online/';
    $cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';
    $cfg['UploadDir'] = '';
    $cfg['SaveDir'] = '';
?>

# Sekarang mari buat user untuk phpmyadmin
mysql -u root -p # kemudian silakan isi password root yang tadi buat kemudian enter

# Selanjutnya kita paste query berikut untuk buat user phpmyadmin
CREATE USER 'phpmyadmin'@'localhost' IDENTIFIED BY 'PASSWORD PHPMYADMIN KAMU';
GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
SOURCE /usr/share/phpmyadmin/sql/create_tables.sql;
FLUSH PRIVILEGES;
EXIT;

# >> Langkah 6 [ Testing ]
# Sekarang kamu bisa coba akses ke phpmyadmin dengan cara
# https://domainkamu.com/phpmyadmin
# dan login pake user root yang telah dibuat tadi
# Jika semuanya jalan berarti setup telah berhasil
# Anda tinggal masukin web kamu ke folder /var/www/domainkamu.com/

# Write: Wildy Sheverando
