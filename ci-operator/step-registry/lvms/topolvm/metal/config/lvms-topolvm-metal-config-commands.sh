#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
export PS4='+ $(date "+%T.%N") \011'

SSHOPTS=(-o 'ConnectTimeout=5'
  -o 'StrictHostKeyChecking=no'
  -o 'UserKnownHostsFile=/dev/null'
  -o 'ServerAliveInterval=90'
  -o LogLevel=ERROR
  -i "${CLUSTER_PROFILE_DIR}/ssh-privatekey")

instance_ip=$(cat ${SHARED_DIR}/public_address)
host=$(cat ${SHARED_DIR}/ssh_user)

ssh_host_ip="$host@$instance_ip"

if ! test -f "${SHARED_DIR}/remote_workdir"; then
  workdir="/home/${host}/workdir-$(date +%Y%m%d)"

  echo "${workdir}" >> "${SHARED_DIR}/remote_workdir"
fi

remote_workdir=$(cat "${SHARED_DIR}/remote_workdir")

ssh "${SSHOPTS[@]}" "${ssh_host_ip}" "mkdir -p ${remote_workdir}"

cat <<EOF > ${SHARED_DIR}/install.sh
#!/bin/bash
set -euo pipefail

cd ${remote_workdir}

curl -LO https://go.dev/dl/${GO_VERSION}.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf ${GO_VERSION}.tar.gz
rm ${GO_VERSION}.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile && source ~/.profile

apt install \
    docker.io \
    lvm2 \
    util-linux \
    -y



git clone https://github.com/topolvm/topolvm.git

EOF

chmod +x ${SHARED_DIR}/install.sh
scp "${SSHOPTS[@]}" ${SHARED_DIR}/install.sh $ssh_host_ip:$remote_workdir

ssh "${SSHOPTS[@]}" $ssh_host_ip "${remote_workdir}/install.sh"