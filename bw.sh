#!/bin/bash

# Comprehensive Web Server Management Tool with Advanced Features

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a service is installed
check_service() {
    if command -v $1 &> /dev/null
    then
        return 0
    fi
    return 1
}

# Function to get service status
get_service_status() {
    local service=$1
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
}

# Function to detect installed services
detect_services() {
    services=()
    if check_service apache2; then
        services+=("apache2")
    fi
    if check_service nginx; then
        services+=("nginx")
    fi
    if check_service php-fpm7.4 || check_service php-fpm8.0; then
        services+=("php-fpm")
    fi
    if check_service mysql; then
        services+=("mysql")
    fi
    if check_service postgresql; then
        services+=("postgresql")
    fi
}

# Function to generate system info
generate_system_info() {
    echo -e "${YELLOW}=== System Information ===${NC}"
    echo -e "Hostname: $(hostname)"
    echo -e "OS: $(lsb_release -d | cut -f2)"
    echo -e "Kernel: $(uname -r)"
    echo -e "CPU: $(lscpu | grep 'Model name' | cut -f2 -d ":" | awk '{$1=$1}1')"
    echo -e "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "Disk Usage: $(df -h / | awk '/\// {print $(NF-1)}')"
}

# Function to generate MOTD
generate_motd() {
    detect_services
    echo -e "${YELLOW}=== Web Server Status ===${NC}"
    for service in "${services[@]}"
    do
        status=$(get_service_status $service)
        printf "%-15s %s\n" "$service:" "$status"
    done
    echo
}

# Function to manage services
manage_service() {
    local service=$1
    local action=$2
    
    if check_service $service; then
        sudo systemctl $action $service
        echo "$service $action"
    else
        echo "$service is not installed."
    fi
}

# Function to manage Apache
manage_apache() {
    local action=$1
    case $action in
        start|stop|restart|status)
            manage_service apache2 $action
            ;;
        createvhost)
            create_apache_vhost
            ;;
        deletevhost)
            delete_apache_vhost
            ;;
        viewlog)
            view_apache_log
            ;;
        *)
            echo "Invalid action for Apache. Use start, stop, restart, status, createvhost, deletevhost, or viewlog."
            ;;
    esac
}

# Function to manage Nginx
manage_nginx() {
    local action=$1
    case $action in
        start|stop|restart|status)
            manage_service nginx $action
            ;;
        createvhost)
            create_nginx_vhost
            ;;
        deletevhost)
            delete_nginx_vhost
            ;;
        viewlog)
            view_nginx_log
            ;;
        *)
            echo "Invalid action for Nginx. Use start, stop, restart, status, createvhost, deletevhost, or viewlog."
            ;;
    esac
}

# Function to manage PHP-FPM
manage_php() {
    local action=$1
    case $action in
        start|stop|restart|status)
            manage_service php-fpm $action
            ;;
        viewlog)
            view_php_log
            ;;
        *)
            echo "Invalid action for PHP. Use start, stop, restart, status, or viewlog."
            ;;
    esac
}

# Function to manage MySQL
manage_mysql() {
    local action=$1
    case $action in
        start|stop|restart|status)
            manage_service mysql $action
            ;;
        createdb)
            create_mysql_db
            ;;
        deletedb)
            delete_mysql_db
            ;;
        backup)
            backup_mysql_db
            ;;
        restore)
            restore_mysql_db
            ;;
        *)
            echo "Invalid action for MySQL. Use start, stop, restart, status, createdb, deletedb, backup, or restore."
            ;;
    esac
}

# Function to manage PostgreSQL
manage_postgresql() {
    local action=$1
    case $action in
        start|stop|restart|status)
            manage_service postgresql $action
            ;;
        createdb)
            create_postgresql_db
            ;;
        deletedb)
            delete_postgresql_db
            ;;
        backup)
            backup_postgresql_db
            ;;
        restore)
            restore_postgresql_db
            ;;
        *)
            echo "Invalid action for PostgreSQL. Use start, stop, restart, status, createdb, deletedb, backup, or restore."
            ;;
    esac
}

# Function to create Apache virtual host
create_apache_vhost() {
    read -p "Enter domain name: " domain
    read -p "Enter document root: " docroot

    sudo mkdir -p $docroot
    sudo chown www-data:www-data $docroot

    config="<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $docroot
    ErrorLog \${APACHE_LOG_DIR}/$domain-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain-access.log combined
</VirtualHost>"

    echo "$config" | sudo tee /etc/apache2/sites-available/$domain.conf > /dev/null
    sudo a2ensite $domain.conf
    sudo systemctl reload apache2

    echo "Apache virtual host created for $domain"
}

# Function to delete Apache virtual host
delete_apache_vhost() {
    read -p "Enter domain name to delete: " domain

    sudo a2dissite $domain.conf
    sudo rm /etc/apache2/sites-available/$domain.conf
    sudo systemctl reload apache2

    echo "Apache virtual host deleted for $domain"
}

# Function to create Nginx virtual host
create_nginx_vhost() {
    read -p "Enter domain name: " domain
    read -p "Enter document root: " docroot

    sudo mkdir -p $docroot
    sudo chown www-data:www-data $docroot

    config="server {
    listen 80;
    server_name $domain www.$domain;
    root $docroot;
    index index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }
}"

    echo "$config" | sudo tee /etc/nginx/sites-available/$domain > /dev/null
    sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx

    echo "Nginx virtual host created for $domain"
}

# Function to delete Nginx virtual host
delete_nginx_vhost() {
    read -p "Enter domain name to delete: " domain

    sudo rm /etc/nginx/sites-available/$domain
    sudo rm /etc/nginx/sites-enabled/$domain
    sudo nginx -t && sudo systemctl reload nginx

    echo "Nginx virtual host deleted for $domain"
}

# Function to create MySQL database
create_mysql_db() {
    read -p "Enter database name: " dbname
    read -p "Enter database user: " dbuser
    read -s -p "Enter database password: " dbpass
    echo

    sudo mysql -e "CREATE DATABASE $dbname;"
    sudo mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    echo "MySQL database $dbname created with user $dbuser"
}

# Function to delete MySQL database
delete_mysql_db() {
    read -p "Enter database name to delete: " dbname

    sudo mysql -e "DROP DATABASE $dbname;"

    echo "MySQL database $dbname deleted"
}

# Function to create PostgreSQL database
create_postgresql_db() {
    read -p "Enter database name: " dbname
    read -p "Enter database user: " dbuser
    read -s -p "Enter database password: " dbpass
    echo

    sudo -u postgres psql -c "CREATE DATABASE $dbname;"
    sudo -u postgres psql -c "CREATE USER $dbuser WITH ENCRYPTED PASSWORD '$dbpass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $dbname TO $dbuser;"

    echo "PostgreSQL database $dbname created with user $dbuser"
}

# Function to delete PostgreSQL database
delete_postgresql_db() {
    read -p "Enter database name to delete: " dbname

    sudo -u postgres psql -c "DROP DATABASE $dbname;"

    echo "PostgreSQL database $dbname deleted"
}

# Function to view Apache log
view_apache_log() {
    sudo tail -n 50 /var/log/apache2/error.log
}

# Function to view Nginx log
view_nginx_log() {
    sudo tail -n 50 /var/log/nginx/error.log
}

# Function to view PHP-FPM log
view_php_log() {
    sudo tail -n 50 /var/log/php7.4-fpm.log
}

# Function to backup MySQL database
backup_mysql_db() {
    read -p "Enter database name to backup: " dbname
    backup_file="/tmp/$dbname-$(date +%Y%m%d%H%M%S).sql"
    sudo mysqldump $dbname > $backup_file
    echo "Database $dbname backed up to $backup_file"
}

# Function to restore MySQL database
restore_mysql_db() {
    read -p "Enter database name to restore: " dbname
    read -p "Enter path to backup file: " backup_file
    sudo mysql $dbname < $backup_file
    echo "Database $dbname restored from $backup_file"
}

# Function to backup PostgreSQL database
backup_postgresql_db() {
    read -p "Enter database name to backup: " dbname
    backup_file="/tmp/$dbname-$(date +%Y%m%d%H%M%S).sql"
    sudo -u postgres pg_dump $dbname > $backup_file
    echo "Database $dbname backed up to $backup_file"
}

# Function to restore PostgreSQL database
restore_postgresql_db() {
    read -p "Enter database name to restore: " dbname
    read -p "Enter path to backup file: " backup_file
    sudo -u postgres psql $dbname < $backup_file
    echo "Database $dbname restored from $backup_file"
}

# Function to manage SSL certificates
manage_ssl() {
    echo -e "${BLUE}=== SSL Certificate Management ===${NC}"
    echo "1) Generate self-signed certificate"
    echo "2) Install Let's Encrypt certificate"
    echo "3) Back to main menu"
    read -p "Enter your choice: " choice

    case $choice in
        1) generate_self_signed_cert ;;
        2) install_letsencrypt_cert ;;
        3) return ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

# Function to generate self-signed SSL certificate
generate_self_signed_cert() {
    read -p "Enter domain name: " domain
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$domain.key -out /etc/ssl/certs/$domain.crt
    echo "Self-signed certificate generated for $domain"
}

# Function to install Let's Encrypt certificate
install_letsencrypt_cert() {
    read -p "Enter domain name: " domain
    sudo certbot --apache -d $domain -d www.$domain
    echo "Let's Encrypt certificate installed for $domain"
}

# Function to perform basic security checks
perform_security_checks() {
    echo -e "${YELLOW}=== Basic Security Checks ===${NC}"
    echo "Checking for open ports:"
    sudo netstat -tuln

    echo -e "\nChecking for failed login attempts:"
    sudo grep "Failed password" /var/log/auth.log | tail -n 5

    echo -e "\nChecking for available system updates:"
    sudo apt update
    sudo apt list --upgradable
}

# Main menu function
main_menu() {
    while true; do
        clear
        generate_system_info
        echo
        generate_motd
        echo
        echo -e "${BLUE}=== BWSMT Main Menu ===${NC}"
        echo "1) Manage Web Servers"
        echo "2) Manage Databases"
        echo "3) Manage PHP"
        echo "4) SSL Certificate Management"
        echo "5) Security Checks"
        echo "6) Show Full System Information"
        echo "7) Exit"
        read -p "Enter your choice: " choice

        case $choice in
            1) web_server_menu ;;
            2) database_menu ;;
            3) php_menu ;;
            4) manage_ssl ;;
            5) perform_security_checks ;;
            6) show_full_system_info ;;
            7) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# Web server submenu
web_server_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Web Server Management ===${NC}"
        echo "1) Manage Apache"
        echo "2) Manage Nginx"
        echo "3) Back to Main Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) apache_menu ;;
            2) nginx_menu ;;
            3) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Apache submenu
apache_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Apache Management ===${NC}"
        echo "1) Start Apache"
        echo "2) Stop Apache"
        echo "3) Restart Apache"
        echo "4) Check Apache Status"
        echo "5) Create Virtual Host"
        echo "6) Delete Virtual Host"
        echo "7) View Apache Error Log"
        echo "8) Back to Web Server Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) manage_apache start ;;
            2) manage_apache stop ;;
            3) manage_apache restart ;;
            4) manage_apache status ;;
            5) create_apache_vhost ;;
            6) delete_apache_vhost ;;
            7) view_apache_log ;;
            8) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# Nginx submenu

# Nginx submenu
nginx_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Nginx Management ===${NC}"
        echo "1) Start Nginx"
        echo "2) Stop Nginx"
        echo "3) Restart Nginx"
        echo "4) Check Nginx Status"
        echo "5) Create Virtual Host"
        echo "6) Delete Virtual Host"
        echo "7) View Nginx Error Log"
        echo "8) Back to Web Server Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) manage_nginx start ;;
            2) manage_nginx stop ;;
            3) manage_nginx restart ;;
            4) manage_nginx status ;;
            5) create_nginx_vhost ;;
            6) delete_nginx_vhost ;;
            7) view_nginx_log ;;
            8) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# Database submenu
database_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Database Management ===${NC}"
        echo "1) Manage MySQL"
        echo "2) Manage PostgreSQL"
        echo "3) Back to Main Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) mysql_menu ;;
            2) postgresql_menu ;;
            3) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# MySQL submenu
mysql_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== MySQL Management ===${NC}"
        echo "1) Start MySQL"
        echo "2) Stop MySQL"
        echo "3) Restart MySQL"
        echo "4) Check MySQL Status"
        echo "5) Create Database"
        echo "6) Delete Database"
        echo "7) Backup Database"
        echo "8) Restore Database"
        echo "9) Back to Database Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) manage_mysql start ;;
            2) manage_mysql stop ;;
            3) manage_mysql restart ;;
            4) manage_mysql status ;;
            5) create_mysql_db ;;
            6) delete_mysql_db ;;
            7) backup_mysql_db ;;
            8) restore_mysql_db ;;
            9) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# PostgreSQL submenu
postgresql_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== PostgreSQL Management ===${NC}"
        echo "1) Start PostgreSQL"
        echo "2) Stop PostgreSQL"
        echo "3) Restart PostgreSQL"
        echo "4) Check PostgreSQL Status"
        echo "5) Create Database"
        echo "6) Delete Database"
        echo "7) Backup Database"
        echo "8) Restore Database"
        echo "9) Back to Database Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) manage_postgresql start ;;
            2) manage_postgresql stop ;;
            3) manage_postgresql restart ;;
            4) manage_postgresql status ;;
            5) create_postgresql_db ;;
            6) delete_postgresql_db ;;
            7) backup_postgresql_db ;;
            8) restore_postgresql_db ;;
            9) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# PHP submenu
php_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== PHP Management ===${NC}"
        echo "1) Start PHP-FPM"
        echo "2) Stop PHP-FPM"
        echo "3) Restart PHP-FPM"
        echo "4) Check PHP-FPM Status"
        echo "5) View PHP-FPM Error Log"
        echo "6) Back to Main Menu"
        read -p "Enter your choice: " choice

        case $choice in
            1) manage_php start ;;
            2) manage_php stop ;;
            3) manage_php restart ;;
            4) manage_php status ;;
            5) view_php_log ;;
            6) return ;;
            *) echo "Invalid option. Please try again." ;;
        esac

        read -p "Press enter to continue..."
    done
}

# Function to show full system information
show_full_system_info() {
    clear
    generate_system_info
    echo
    echo -e "${YELLOW}=== Detailed System Information ===${NC}"
    echo -e "CPU Info:"
    lscpu | grep -E "Model name|Socket|Core|Thread"
    echo
    echo -e "Memory Info:"
    free -h
    echo
    echo -e "Disk Info:"
    df -h
    echo
    echo -e "Network Info:"
    ip -br addr show
}

# Function to display help
show_help() {
    echo "Usage: $0 [service] [action]"
    echo "Services: apache, nginx, php, mysql, postgresql"
    echo "Actions:"
    echo "  - For Apache/Nginx: start, stop, restart, status, createvhost, deletevhost, viewlog"
    echo "  - For PHP: start, stop, restart, status, viewlog"
    echo "  - For MySQL/PostgreSQL: start, stop, restart, status, createdb, deletedb, backup, restore"
    echo "Special commands:"
    echo "  - motd: Display Message of the Day with service status"
    echo "  - detect: Detect installed services"
    echo "  - ssl: Manage SSL certificates"
    echo "  - security: Perform basic security checks"
    echo "Example: $0 apache start"
}

# Main script
if [ $# -eq 0 ]; then
    main_menu
elif [ $# -eq 1 ]; then
    case $1 in
        motd)
            generate_motd
            exit 0
            ;;
        detect)
            detect_services
            echo "Detected services: ${services[*]}"
            exit 0
            ;;
        ssl)
            manage_ssl
            exit 0
            ;;
        security)
            perform_security_checks
            exit 0
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
elif [ $# -ne 2 ]; then
    show_help
    exit 1
fi

service=$1
action=$2

case $service in
    apache)
        manage_apache $action
        ;;
    nginx)
        manage_nginx $action
        ;;
    php)
        manage_php $action
        ;;
    mysql)
        manage_mysql $action
        ;;
    postgresql)
        manage_postgresql $action
        ;;
    *)
        echo "Invalid service. Use apache, nginx, php, mysql, or postgresql."
        show_help
        exit 1
        ;;
esac

generate_motd
exit 0