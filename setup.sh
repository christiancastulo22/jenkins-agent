#!/bin/sh
set -e

# Define variables
HOST_NAME="$1"
JENKINS_API_TOKEN="${2}"
SWARM_VERSION="${3:-3.31}"
JENKINS_HOME="/var/jenkins_home"

# Set environment config
sudo hostname "${HOST_NAME}"
sudo su -c "echo 'JENKINS_HOME=$JENKINS_HOME' >> /etc/environment"

# Install packages
## openjdk ppa repo
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt update --yes
sudo apt install --yes python-software-properties python-pip wget git docker.io curl jq openjdk-11-jdk pkg-config make libsecret-1-dev
sudo apt-get remove unscd --yes
# Configure Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo chmod 666 /var/run/docker.sock
sudo usermod -aG docker $USER

## Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# Allow auto-install extensions
az config set extension.use_dynamic_install=yes_without_prompt

# Swap Space
sudo dd if=/dev/zero of=/myswap count=4096 bs=1MiB
sudo chmod 600 /myswap
sudo mkswap /myswap
sudo swapon /myswap
swapon -s
sudo su -c "echo '/myswap   swap    swap    sw  0   0' >> /etc/fstab"

# Setup workspace
sudo mkdir -p $JENKINS_HOME
sudo chmod 777 -R $JENKINS_HOME

# Cron jobs to clean up filesystem
mycron='/tmp/mycron' && touch $mycron
crontab -l && crontab -l > $mycron
echo "0 2 * * * . rm -rf $JENKINS_HOME/workspace/" >> $mycron
echo '0 0 * * SAT docker system prune --force' >> $mycron
# install new crontab
crontab $mycron
rm $mycron

# Install swarm
echo "Downloading swarm client ..."
curl -o $JENKINS_HOME/swarm-client-${SWARM_VERSION}.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${SWARM_VERSION}/swarm-client-${SWARM_VERSION}.jar

# Copy password file
sudo echo "${JENKINS_API_TOKEN}" > /etc/default/jenkins_swarm.password
sudo chmod 777 /etc/default/jenkins_swarm.password

# Set the filesystem
# sudo mv $HOME/jenkins_swarm_config.yml $JENKINS_HOME/jenkins_swarm_config.yml
# possibility 3:
cat  <<EOT |sudo tee /etc/systemd/system/jenkins_swarm.service
[Unit]
Description=Jenkins Swarm Client
After=network.target
Wants=docker.service

[Service]
WorkingDirectory=${workingDir}
User=${username}
EnvironmentFile=-/etc/default/jenkins_swarm
ExecStart=/usr/bin/java -jar swarm-client-${SWARM_VERSION}.jar -config ./jenkins_swarm_config.yml
KillMode=process
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOT
sudo mv /tmp/jenkins_swarm.service /etc/systemd/system/jenkins_swarm.service
sudo touch /etc/default/jenkins_swarm
sudo chmod 777 /etc/default/jenkins_swarm

# Configure swarm as a service
sudo groupadd -r appmgr
sudo usermod -a -G appmgr $USER
sudo systemctl daemon-reload

sudo systemctl enable jenkins_swarm
sudo systemctl start jenkins_swarm
sudo systemctl status --no-pager jenkins_swarm

# Reboot the machine to reload new setup
sudo reboot