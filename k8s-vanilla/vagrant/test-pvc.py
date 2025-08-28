cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: c
    image: busybox
    command: ["sh","-c","echo 'storage OK' > /data/ok && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# Verificar que el PVC se haya ligado y que el pod esté Running
kubectl get pvc,pod
