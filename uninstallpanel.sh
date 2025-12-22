#!/bin/bash
clear

# === Colors ===
BLUE="\e[1;34m"
CYAN="\e[1;36m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
RESET="\e[0m"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}   🦕 PTERODACTYL PANEL UNINSTALLER${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}⚠ WARNING:${RESET} This will REMOVE the panel completely"
echo -e "${YELLOW}- Panel files${RESET}"
echo -e "${YELLOW}- Database & DB user (optional)${RESET}"
echo -e "${YELLOW}- Nginx config & SSL${RESET}"
echo -e "${YELLOW}- Queue worker & cron${RESET}"
echo
read -p "$(echo -e ${CYAN}Type 'UNINSTALL' to continue:${RESET} )" CONFIRM

if [[ "$CONFIRM" != "UNINSTALL" ]]; then
    echo -e "\n${GREEN}✔ Uninstall cancelled.${RESET}"
    exit 0
fi

echo -e "\n${BLUE}🚀 Starting Panel uninstall...${RESET}"
sleep 1

# --- Stop Queue Worker ---
echo -e "${CYAN}⛔ Stopping queue worker...${RESET}"
systemctl stop pteroq.service 2>/dev/null
systemctl disable pteroq.service 2>/dev/null

# --- Remove systemd service ---
echo -e "${CYAN}🗑 Removing queue worker service...${RESET}"
rm -f /etc/systemd/system/pteroq.service
systemctl daemon-reload

# --- Remove cron ---
echo -e "${CYAN}🗑 Removing cron jobs...${RESET}"
crontab -u www-data -r 2>/dev/null || true

# --- Remove Nginx config ---
echo -e "${CYAN}🗑 Removing Nginx config...${RESET}"
rm -f /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-available/pterodactyl.conf
nginx -t && systemctl reload nginx

# --- Remove SSL certs ---
echo -e "${CYAN}🗑 Removing SSL certificates...${RESET}"
rm -rf /etc/certs/panel

# --- Remove panel files ---
echo -e "${CYAN}🗑 Removing panel files...${RESET}"
rm -rf /var/www/pterodactyl

# --- Database cleanup ---
echo
read -p "$(echo -e ${YELLOW}Remove database & DB user? (y/n):${RESET} )" REMOVE_DB
if [[ "$REMOVE_DB" == "y" ]]; then
    read -p "$(echo -e ${CYAN}Enter DB name [panel]:${RESET} )" DB_NAME
    DB_NAME=${DB_NAME:-panel}

    read -p "$(echo -e ${CYAN}Enter DB user [pterodactyl]:${RESET} )" DB_USER
    DB_USER=${DB_USER:-pterodactyl}

    echo -e "${CYAN}🗑 Removing database & user...${RESET}"
    mariadb -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
    mariadb -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';"
    mariadb -e "FLUSH PRIVILEGES;"
fi

# --- Optional: Redis ---
echo
read -p "$(echo -e ${YELLOW}Remove Redis server? (y/n):${RESET} )" REMOVE_REDIS
if [[ "$REMOVE_REDIS" == "y" ]]; then
    apt purge -y redis-server
    apt autoremove -y
fi

# --- Optional: PHP ---
echo
read -p "$(echo -e ${YELLOW}Remove PHP 8.3 packages? (y/n):${RESET} )" REMOVE_PHP
if [[ "$REMOVE_PHP" == "y" ]]; then
    apt purge -y php8.3*
    apt autoremove -y
fi

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✔ PTERODACTYL PANEL UNINSTALLED${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}✔ Panel removed successfully${RESET}"
echo -e "${CYAN}✔ System cleaned${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"