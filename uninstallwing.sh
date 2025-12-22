#!/bin/bash
clear

BLUE="\e[1;34m"
CYAN="\e[1;36m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
RESET="\e[0m"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}   🦅 PTERODACTYL WINGS UNINSTALLER${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}⚠ WARNING:${RESET} This will remove ALL Wings data"
echo -e "${YELLOW}- Docker containers, images, volumes${RESET}"
echo -e "${YELLOW}- Game servers (PERMANENT)${RESET}"
echo
read -p "$(echo -e ${CYAN}Type 'UNINSTALL' to continue:${RESET} )" CONFIRM

if [[ "$CONFIRM" != "UNINSTALL" ]]; then
    echo -e "\n${GREEN}✔ Uninstall cancelled.${RESET}"
    exit 0
fi

echo -e "\n${BLUE}🚀 Starting Wings uninstall...${RESET}"
sleep 1

# --- Stop Wings ---
echo -e "${CYAN}⛔ Stopping Wings service...${RESET}"
systemctl stop wings 2>/dev/null
systemctl disable wings 2>/dev/null

# --- Remove systemd service ---
echo -e "${CYAN}🗑 Removing Wings service...${RESET}"
rm -f /etc/systemd/system/wings.service
systemctl daemon-reload

# --- Remove Wings binary ---
echo -e "${CYAN}🗑 Removing Wings binary...${RESET}"
rm -f /usr/local/bin/wings

# --- Remove Wings config & data ---
echo -e "${CYAN}🗑 Removing Wings config & data...${RESET}"
rm -rf /etc/pterodactyl
rm -rf /var/lib/pterodactyl
rm -rf /var/log/pterodactyl

# --- Docker cleanup ---
echo
read -p "$(echo -e ${YELLOW}Remove ALL Docker containers & images? (y/n):${RESET} )" REMOVE_DOCKER
if [[ "$REMOVE_DOCKER" == "y" ]]; then
    echo -e "${RED}🧨 Stopping Docker...${RESET}"
    systemctl stop docker docker.socket containerd 2>/dev/null

    echo -e "${CYAN}🗑 Removing containers...${RESET}"
    docker rm -f $(docker ps -aq) 2>/dev/null || true

    echo -e "${CYAN}🗑 Removing images...${RESET}"
    docker rmi -f $(docker images -aq) 2>/dev/null || true

    echo -e "${CYAN}🗑 Removing volumes...${RESET}"
    docker volume rm $(docker volume ls -q) 2>/dev/null || true

    echo -e "${CYAN}🗑 Removing networks...${RESET}"
    docker network rm $(docker network ls -q) 2>/dev/null || true

    echo -e "${CYAN}🗑 Purging Docker packages...${RESET}"
    apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    apt autoremove -y

    rm -rf /var/lib/docker
fi

# --- Optional: Firewall cleanup ---
echo
read -p "$(echo -e ${YELLOW}Reset UFW firewall rules? (y/n):${RESET} )" RESET_UFW
if [[ "$RESET_UFW" == "y" ]]; then
    ufw reset
fi

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✔ PTERODACTYL WINGS UNINSTALLED${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}✔ All containers removed${RESET}"
echo -e "${CYAN}✔ Docker cleaned${RESET}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"