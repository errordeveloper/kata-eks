#!/bin/bash

kubectl exec -ti deployment/test-cluster-master bash -- -c "
cat > id_rsa << EOF
$(cat ~/.ssh/id_rsa)
EOF
chmod 0600 id_rsa
"
