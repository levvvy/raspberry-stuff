#!/bin/bash

main() {
    menu() {
        clear
        echo -e "Raspberry Pi Jellyfin Player Auto-Start Setup\n--------------------------------------------"
        echo -e "1. Auto-Install All (Non-Interactive)"
        echo -e "2. Install Required Packages"
        echo -e "3. Install Jellyfin Player (Flatpak)"
        echo -e "4. Create Systemd Service"
        echo -e "5. Enable Auto Login to Console"
        echo -e "6. Manual Launch on HDMI Port"
        echo -e "7. Reboot System"
        echo -e "8. Exit"
        echo -e ""
        read -p "Select (1-8): " opt
    }

    display_progress() {
        local step=$1 total_steps=$2 desc=$3 task_progress=$4 task_total=$5
        local width=60 spinner="/-\\|" spin_index=0 spin_delay=0.1
        local gradient_chars=("░" "▒" "▓")
        local progress=$((step * 100 / total_steps))
        local pb_len=$((width - 16))
        local tb_len=$((width - 10))
        
        grad_char() { local pct=$1; echo "${gradient_chars[$((pct * (${#gradient_chars[@]} - 1) / 100))]}"; }

        local progress_bar=$(printf "%-${pb_len}s" "$(printf "%${pb_len}s" | sed "s/./$(grad_char $progress)/g")")
        local task_bar=$(printf "%-${tb_len}s" "$(printf "%${tb_len}s" | sed "s/./$(grad_char $((task_progress * 100 / task_total)))/g")")
        
        while [ $progress -lt 100 ]; do
            printf "\033[0;0HOverall Progress: [${progress_bar// /░}] %d%%\n" "$progress"
            printf "Task: %s\n" "$desc"
            printf "Task Progress: [${task_bar// /░}] %d%% %c" "$task_progress" "${spinner:spin_index:1}"
            
            sleep $spin_delay
            spin_index=$(( (spin_index + 1) % ${#spinner} ))
            printf "\033[A\033[A"
            
            progress=$((progress + 1))
        done

        printf "\033[0;0HOverall Progress: [${progress_bar// /░}] %d%% Done!\n" "$progress"
        printf "Task: %s\n" "$desc"
        printf "Task Progress: [${task_bar// /░}] %d%% Done!\n" "$task_progress"
    }

    auto_install() {
        echo "Auto-installing all components..."
        local total_steps=4 step=1 task_total=4 task_step=1

        display_progress $step $total_steps "Installing packages..." $task_step $task_total
        sudo apt-get update -y > /dev/null
        sudo apt-get install --no-install-recommends xserver-xorg xinit openbox flatpak python3-xdg -y > /dev/null
        task_step=$((task_step + 1)) step=$((step + 1))

        display_progress $step $total_steps "Installing Jellyfin Player..." $task_step $task_total
        flatpak install flathub com.github.iwalton3.jellyfin-media-player -y > /dev/null
        task_step=$((task_step + 1)) step=$((step + 1))

        display_progress $step $total_steps "Creating systemd service..." $task_step $task_total
        sudo bash -c 'cat <<EOF > /usr/local/bin/start-jellyfin-x.sh
#!/bin/bash
export DISPLAY=:0
Xorg :0 &
sleep 2
openbox-session &
sudo -u '$USER' flatpak run com.github.iwalton3.jellyfin-media-player
EOF'
        sudo bash -c 'cat <<EOF > /etc/systemd/system/jellyfin-player.service
[Unit]
Description=Autostart Jellyfin Player on boot
After=network.target
[Service]
Type=simple
User='$USER'
ExecStart=/usr/local/bin/start-jellyfin-x.sh
Restart=on-failure
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF'
        sudo systemctl enable jellyfin-player.service > /dev/null
        task_step=$((task_step + 1)) step=$((step + 1))

        display_progress $step $total_steps "Enabling auto-login..." $task_step $task_total
        sudo raspi-config nonint do_boot_behaviour B2 > /dev/null

        echo "All components installed!"
        read -p "Run Jellyfin Player now? (y/n): " run_now
        [ "$run_now" == "y" ] && sudo -u $USER /usr/local/bin/start-jellyfin-x.sh
    }

    manual_launch() {
        [ ! -f /usr/local/bin/start-jellyfin-x.sh ] && sudo bash -c 'cat <<EOF > /usr/local/bin/start-jellyfin-x.sh
#!/bin/bash
export DISPLAY=:0
Xorg :0 &
sleep 2
openbox-session &
sudo -u '$USER' flatpak run com.github.iwalton3.jellyfin-media-player
EOF'
        sudo chmod +x /usr/local/bin/start-jellyfin-x.sh
        sudo -u $USER /usr/local/bin/start-jellyfin-x.sh
        echo "Jellyfin Player launched on HDMI port!"
        read -p "Press Enter to return to menu..."
    }

    reboot_system() {
        read -p "Reboot now? (y/n): " confirm
        [ "$confirm" == "y" ] && sudo reboot || echo "Reboot canceled."
    }

    while true; do
        menu
        case $opt in
            1) auto_install ;;
            2) sudo apt-get update -y > /dev/null; sudo apt-get install --no-install-recommends xserver-xorg xinit openbox flatpak python3-xdg -y > /dev/null ;;
            3) flatpak install flathub com.github.iwalton3.jellyfin-media-player -y > /dev/null ;;
            4) sudo bash -c 'cat <<EOF > /usr/local/bin/start-jellyfin-x.sh
#!/bin/bash
export DISPLAY=:0
Xorg :0 &
sleep 2
openbox-session &
sudo -u '$USER' flatpak run com.github.iwalton3.jellyfin-media-player
EOF'
        sudo bash -c 'cat <<EOF > /etc/systemd/system/jellyfin-player.service
[Unit]
Description=Autostart Jellyfin Player on boot
After=network.target
[Service]
Type=simple
User='$USER'
ExecStart=/usr/local/bin/start-jellyfin-x.sh
Restart=on-failure
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF'
        sudo systemctl enable jellyfin-player.service > /dev/null ;;
            5) sudo raspi-config nonint do_boot_behaviour B2 > /dev/null ;;
            6) manual_launch ;;
            7) reboot_system ;;
            8) exit ;;
            *) echo "Invalid option." ;;
        esac
    done
}

main
