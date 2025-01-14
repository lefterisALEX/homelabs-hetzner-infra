# homelabs-hetzner-infra
Deployes the infra needed in hetzner for the homelabs. This includes a private network, a NAT gateway and a k3s cluster.

# Mount Hetznerbox

```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storagebox-pv #REPLACE with the name of the PV
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 1000Gi
  csi:
    driver: smb.csi.k8s.io
    nodeStageSecretRef:
      name: storagebox
      namespace: kube-system
    volumeHandle: storagebox
    volumeAttributes:
      source: "//u399852-sub3.your-storagebox.de/u399852-sub3/1" #REPLACE with a valid path for your container 
  persistentVolumeReclaimPolicy: Retain
  storageClassName: storagebox
  volumeMode: Filesystem

---
# Define the PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storagebox-pvc #REPLACE with the name of PVC
  namespace: kube-system
spec:
  storageClassName: storagebox
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1000Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: kube-system
spec:
  containers:
    - name: test-container
      image: busybox
      command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
      volumeMounts:
        - mountPath: /mnt/storagebox
          name: my-volume
  volumes:
    - name: my-volume
      persistentVolumeClaim:
        claimName: storagebox-pvc

```
