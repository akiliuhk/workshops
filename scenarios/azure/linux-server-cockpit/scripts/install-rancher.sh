#! /bin/bash -e

# Install Kubernetes tools
echo "Installing Kubernetes Client Tools - kubectl and helm ..."

curl -sLS https://get.arkade.dev | sudo sh

sudo ark get helm
sudo mv /root/.arkade/bin/helm /usr/local/bin/

sudo ark get kubectl
sudo mv /root/.arkade/bin/kubectl /usr/local/bin/


#! /bin/bash -e

# install rancher server
echo "Install Rancher Server using helm chart on RKE2 ..."

echo "Install RKE2 v1.25 ..."
sudo bash -c 'curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL="v1.25" sh -'
sudo mkdir -p /etc/rancher/rke2
sudo bash -c 'echo "write-kubeconfig-mode: \"0644\"" > /etc/rancher/rke2/config.yaml'
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

mkdir -p $HOME/.kube
ln -s /etc/rancher/rke2/rke2.yaml $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# Wait until the RKE2 is ready
echo "Initializing RKE2 cluster ..."
while [ `kubectl get deploy -n kube-system | grep 1/1 | wc -l` -ne 3 ]
do
  sleep 5
  kubectl get po -n kube-system
done
echo "Your RKE2 cluster is ready!"
kubectl get node

echo "Install Cert Manager v1.11.4 ..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.11.4/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.11.4 \
  --create-namespace
  
kubectl -n cert-manager rollout status deploy/cert-manager

# Wait until cert-manager deployment complete
echo "Wait until cert-manager deployment finish ..."
while [ `kubectl get deploy -n cert-manager | grep 1/1 | wc -l` -ne 3 ]
do
  sleep 5
  kubectl get po -n cert-manager
done


# Install Rancher with helm chart
echo "Install Rancher ${RANCHER_VERSION} ..."
RANCHER_IP=`curl -qs http://checkip.amazonaws.com`
RANCHER_FQDN=rancher.$RANCHER_IP.sslip.io
RANCHER_VERSION=v2.7.5-ent

helm repo add rancher-prime https://pandaria-releases.oss-cn-beijing.aliyuncs.com/2.7-prime/latest
helm repo update

helm upgrade --install rancher rancher-prime/rancher \
  --namespace cattle-system \
  --set hostname=$RANCHER_FQDN \
  --set replicas=1 \
  --set global.cattle.psp.enabled=false \
  --set rancherImage=harbor.suse.sstech.cloud/prime/rancher \
  --set systemDefaultRegistry=harbor.suse.sstech.cloud/ \
  --version ${RANCHER_VERSION} \
  --create-namespace

echo "Wait until cattle-system deployment finish ..."
while [ `kubectl get deploy -n cattle-system | grep 1/1 | wc -l` -ne 1 ]
do
  sleep 5
  kubectl get po -n cattle-system
done

RANCHER_BOOTSTRAP_PWD=`kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'`


echo
echo "---------------------------------------------------------"
echo "Your Rancher Server is ready."
echo
echo "Your Rancher Server URL: https://${RANCHER_FQDN}" > rancher-url.txt
echo "Bootstrap Password: ${RANCHER_BOOTSTRAP_PWD}" >> rancher-url.txt
cat rancher-url.txt
echo "---------------------------------------------------------"
