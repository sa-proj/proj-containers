export GCP_PROJECT_ID='xxxxxxxxxxxxxx'
export REGION='us-central1'
export ZONE_A='us-central1-a'
export ZONE_B='us-central1-b'
export NETWORK_NAME='network-1'
export PUBLIC_SUBNET='publicnet'
export PUBLIC_SUBNET_RANGE='10.0.1.0/24'
export PRIVATE_SUBNET='privatenet'
export PRIVATE_SUBNET_RANGE='10.0.0.0/24'
export MY_IP='<<YOUR PUBLIC IP HERE>>'
export BASTION_HOST_TAG='bastion-host'
export BASTION_HOST_NAME='bastion-host-1'
export CLOUDSHELL_PUBLIC_IP="$(curl https://ipinfo.io/ip)/32"
export CLUSTERNAME='gke-cluster-1'
export PRIVATE_SERVICE_CONNECT_RANGE_NAME="$NETWORK_NAME-psc-range"
export PRIVATE_SERVICE_CONNECT_ADDRESS="10.0.2.0"
gcloud services enable file.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud compute networks create $NETWORK_NAME \
    --project=$GCP_PROJECT_ID \
    --subnet-mode=custom
gcloud compute networks subnets create $PRIVATE_SUBNET \
    --project=$GCP_PROJECT_ID \
    --range=$PRIVATE_SUBNET_RANGE \
    --network=$NETWORK_NAME \
    --region=$REGION \
    --enable-private-ip-google-access
gcloud compute networks subnets create $PUBLIC_SUBNET \
    --project=$GCP_PROJECT_ID \
    --range=$PUBLIC_SUBNET_RANGE \
    --network=$NETWORK_NAME \
    --region=$REGION \
    --enable-private-ip-google-access
gcloud compute --project=$GCP_PROJECT_ID firewall-rules create allow-rdp-access \
    --direction=INGRESS \
    --priority=1000 \
    --network=$NETWORK_NAME \
    --action=ALLOW \
    --rules=tcp:3389 \
    --source-ranges=$MY_IP \
    --target-tags=$BASTION_HOST_TAG
gcloud compute --project=$GCP_PROJECT_ID firewall-rules create allow-mssql-access \
    --direction=INGRESS \
    --priority=1000 \
    --network=$NETWORK_NAME \
    --action=ALLOW \
    --rules=tcp:1433 \
    --source-ranges=$PUBLIC_SUBNET_RANGE \
    --target-tags=$BASTION_HOST_TAG
gcloud compute addresses create $PRIVATE_SERVICE_CONNECT_RANGE_NAME \
    --global \
    --purpose=VPC_PEERING \
    --addresses=$PRIVATE_SERVICE_CONNECT_ADDRESS \
    --prefix-length=24 \
    --description="PRIVATE SERVICE CONNECTION" \
    --network=$NETWORK_NAME
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=$PRIVATE_SERVICE_CONNECT_RANGE_NAME \
    --network=$NETWORK_NAME \
    --project=$GCP_PROJECT_ID
gcloud beta filestore instances create nfs-server-1 \
    --zone=$ZONE_B \
    --tier=BASIC_HDD \
    --file-share=name="common",capacity=1TB \
    --network=name=$NETWORK_NAME,reserved-ip-range=$PRIVATE_SERVICE_CONNECT_RANGE_NAME,connect-mode=PRIVATE_SERVICE_ACCESS
gcloud beta compute --project=$GCP_PROJECT_ID instances create $BASTION_HOST_NAME \
    --zone=$ZONE_A \
    --machine-type=n2d-standard-2 \
    --subnet=$PUBLIC_SUBNET \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --tags=$BASTION_HOST_TAG \
    --image=sql-2017-express-windows-2019-dc-v20211012 \
    --image-project=windows-sql-cloud \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-balanced \
    --boot-disk-device-name=$BASTION_HOST_NAME
gcloud compute routers create nat-router \
    --network $NETWORK_NAME \
    --region $REGION
gcloud compute routers nats create nat-config \
    --router-region $REGION \
    --router nat-router \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
gcloud beta container --project $GCP_PROJECT_ID clusters create $CLUSTERNAME \
    --zone $ZONE_B \
    --no-enable-basic-auth \
    --cluster-version "1.21.5-gke.1302" \
    --release-channel "regular" \
    --machine-type "e2-medium" \
    --image-type "COS_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --metadata disable-legacy-endpoints=true \
    --max-pods-per-node "110" \
    --num-nodes "3" \
    --enable-private-nodes \
    --master-ipv4-cidr "10.0.3.0/28" \
    --enable-master-global-access \
    --enable-ip-alias \
    --network "projects/$GCP_PROJECT_ID/global/networks/$NETWORK_NAME" \
    --subnetwork "projects/$GCP_PROJECT_ID/regions/$REGION/subnetworks/$PRIVATE_SUBNET" \
    --no-enable-intra-node-visibility \
    --default-max-pods-per-node "110" \
    --enable-master-authorized-networks \
    --master-authorized-networks $CLOUDSHELL_PUBLIC_IP \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-shielded-nodes \
    --node-locations $ZONE_B
gcloud container clusters get-credentials $CLUSTERNAME --zone $ZONE_B --project $GCP_PROJECT_ID
#cd ~/proj-containers/sql2k19-hadr-dh2i-image/
#docker build -t gcr.io/$GCP_PROJECT_ID/sql2k19-hadr-dh2i .
#docker push gcr.io/$GCP_PROJECT_ID/sql2k19-hadr-dh2i
#kubectl create secret generic sql-server-secret --from-literal=MSSQL_SA_PASSWORD="P@ssw0rd"
#kubectl get nodes
#kubectl label node gke-gke-cluster-1-default-pool-391132f9-684s role=ags-primary
#kubectl label node gke-gke-cluster-1-default-pool-391132f9-c9j4 role=ags-secondary-1
#kubectl label node gke-gke-cluster-1-default-pool-391132f9-lsl2 role=ags-secondary-2