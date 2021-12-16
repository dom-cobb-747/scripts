############################################################
#OS: CentOS, Amazon Linux
#Datadog agent version: 7.x.y
#Params:
# - env: (lle, prod)
# - onekey-region: (na, emea, anz)
# - aws-region:  (us-east-1, eu-central-1, ap-southeast-2)
# - key
#Place this script inside the instance and run it with sudo. For example:
#chmod +x configure_logs_amazon_linux.sh
# #NA + prod
# sudo ./configure_logs_amazon_linux.sh prod na us-east-1 <%DATADOG_KEY%>
# complete...
# #NA
#sudo ./configure_logs_amazon_linux.sh lle na us-east-1 <%DATADOG_KEY%>
# #EMEA
#sudo ./configure_logs_amazon_linux.sh prod emea eu-central-1 <%DATADOG_KEY%>
# #ANZ + prod
#sudo ./configure_logs_amazon_linux.sh prod anz ap-southeast-2 <%DATADOG_KEY%>
#Finally look for the Log section after cheking DD status:
#sudo datadog-agent status
############################################################

#0. Setting tags' values
echo "Setting tags values.."
export TAG_ENVIRONMENT=$1 && echo $TAG_ENVIRONMENT
export TAG_OK_REGION=$2 && echo $TAG_OK_REGION
export TAG_REGION=$3 && echo $TAG_REGION

#install Datadog agent
export DD_AGENT_MAJOR_VERSION=7
export DD_API_KEY=$4
export DD_SITE="datadoghq.com"
bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

#Setting config. location
export DDOG_PARENT_CONFIG_DIR=/etc/datadog-agent && echo $DDOG_PARENT_CONFIG_DIR
export DDOG_CONFIG_DIR=$DDOG_PARENT_CONFIG_DIR/conf.d/hbase.d && echo $DDOG_CONFIG_DIR

mkdir -p  $DDOG_CONFIG_DIR
touch $DDOG_CONFIG_DIR/config.yaml
chmod +wrx $DDOG_CONFIG_DIR/config.yaml

cat <<EOF > $DDOG_CONFIG_DIR/config.yaml
logs:
  - type: file
    path: "/usr/lib/hbase/logs/*.log"
    source: "hbase"
    service: "hbase"
    tags: ["env:$TAG_ENVIRONMENT", "onekey_region:$TAG_OK_REGION", "region:$TAG_REGION"]
EOF

#Enabling logs
export OLD_VALUE="# logs_enabled: false"
export NEW_VALUE="logs_enabled: true"
sed -i "s/$OLD_VALUE/$NEW_VALUE/g" $DDOG_PARENT_CONFIG_DIR/datadog.yaml

systemctl stop datadog-agent

systemctl start datadog-agent


