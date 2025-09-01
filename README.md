# Panduan Deployment Aplikasi Node.js ke K3s

Repositori ini berisi aplikasi Node.js sederhana dan panduan langkah demi langkah untuk melakukan containerisasi dengan Docker, mengunggahnya ke GitHub Container Registry, dan mempersiapkan server K3s untuk deployment.

## Langkah 1: Aplikasi Node.js

Aplikasi ini adalah server Express sederhana yang berjalan di port 3000.

**`index.js`**
```javascript
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hi There');
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
```

**`package.json`**
```json
{
  "name": "guide-to-k8",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo "Error: no test specified" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "express": "^4.19.2"
  }
}
```

## Langkah 2: Membuat Dockerfile

`Dockerfile` ini digunakan untuk membangun image aplikasi Node.js yang efisien untuk produksi.

```dockerfile
FROM node:18-alpine

# Membuat direktori aplikasi
WORKDIR /usr/src/app

# Menyalin package.json dan package-lock.json
COPY package*.json ./

# Menginstal dependensi untuk produksi
RUN npm ci --omit=dev

# Menyalin sisa source code aplikasi
COPY . .

# Mengekspos port 3000
EXPOSE 3000

# Perintah untuk menjalankan aplikasi
CMD [ "node", "index.js" ]
```

## Langkah 3: Build & Push Image ke GitHub Registry

1.  **Login ke GitHub Container Registry (`ghcr.io`)**
    Buat [Personal Access Token (PAT)](https://github.com/settings/tokens/new) dengan scope `write:packages`. Kemudian login menggunakan perintah berikut, ganti `[NAMA_USER_GITHUB]` dengan username Anda.
    ```bash
    export CR_PAT=[TOKEN_ANDA]
    echo $CR_PAT | docker login ghcr.io -u [NAMA_USER_GITHUB] --password-stdin
    ```

2.  **Build Image**
    ```bash
    docker build -t guide-to-k8 .
    ```

3.  **Tag Image**
    Ganti `[nama_user_github]` dengan username GitHub Anda (huruf kecil).
    ```bash
    docker tag guide-to-k8:latest ghcr.io/[nama_user_github]/guide-to-k8:latest
    ```

4.  **Push Image**
    ```bash
    docker push ghcr.io/[nama_user_github]/guide-to-k8:latest
    ```

## Langkah 4: Instalasi & Konfigurasi K3s

Langkah-langkah ini dilakukan di server/VPS Anda.

1.  **Instal K3s**
    Perintah ini akan menginstal K3s, `kubectl`, dan menjalankannya sebagai service.
    ```bash
    curl -sfL https://get.k3s.io | sh -
    ```

2.  **Konfigurasi `kubectl` (Best Practice)**
    Langkah ini membuat `kubectl` dapat digunakan oleh user biasa tanpa `sudo` dan kompatibel dengan tools lain.
    ```bash
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    ```

3.  **Troubleshooting: Mengatasi `kubectl` Non-Standar**
    Jika `kubectl` masih gagal, paksa ia menggunakan file config yang benar dengan membuat alias permanen.
    ```bash
    # Tambahkan alias ke file startup shell Anda
    echo "alias kubectl='kubectl --kubeconfig ~/.kube/config'" >> ~/.bashrc

    # Muat ulang konfigurasi shell
    source ~/.bashrc
    ```

4.  **Verifikasi Instalasi**
    Setelah semua langkah di atas, verifikasi bahwa `kubectl` dapat terhubung ke cluster.
    ```bash
    kubectl get nodes
    ```
    Anda akan melihat node server Anda dengan status `Ready`.

## Langkah 5: Menyiapkan VPS Kedua (Node Agent)

Untuk membuat cluster multi-node, kita perlu satu **Node Server** (master, sudah kita siapkan di Langkah 4) dan satu atau lebih **Node Agent** (worker).

1.  **Reset Node Calon Agent**
    Jika Anda sudah terlanjur menginstal K3s di VPS kedua, hapus instalasi tersebut. Jika VPS masih baru, lewati langkah ini.
    ```bash
    # Dijalankan di VPS yang akan menjadi agent
    /usr/local/bin/k3s-uninstall.sh
    ```

2.  **Dapatkan Token & IP dari Node Server**
    Di VPS pertama (server), dapatkan token rahasia untuk bergabung.
    ```bash
    # Dijalankan di VPS Server
    sudo cat /var/lib/rancher/k3s/server/node-token
    ```
    Catat juga alamat IP dari VPS server ini.

3.  **Instal K3s sebagai Agent**
    Di VPS kedua, jalankan skrip instalasi dengan variabel `K3S_URL` dan `K3S_TOKEN`.
    ```bash
    # Dijalankan di VPS yang akan menjadi agent
    curl -sfL https://get.k3s.io | K3S_URL=https://[IP_ADDRESS_VPS_SERVER]:6443 K3S_TOKEN=[TOKEN_DARI_SERVER] sh -
    ```

4.  **Verifikasi Cluster**
    Kembali ke VPS Server dan periksa daftar node. Anda sekarang akan melihat dua node.
    ```bash
    # Dijalankan di VPS Server
    kubectl get nodes
    ```

## Langkah 6: Konfigurasi Firewall

Buka port-port berikut di firewall masing-masing VPS.

#### Di VPS Server (Master):
*   **Port `6443/tcp`**: Dari IP semua node agent (untuk Kubernetes API).
*   **Port `8472/udp`**: Dari IP semua node lain di cluster (untuk jaringan Pod).
*   **Port `10250/tcp`**: Dari IP semua node lain di cluster (untuk Kubelet).

#### Di VPS Agent (Worker):
*   **Port `8472/udp`**: Dari IP semua node lain di cluster.
*   **Port `10250/tcp`**: Dari IP semua node lain di cluster.

#### Di SEMUA Node (Server dan Agent):
*   **Port `30000-32767/tcp`**: Dari mana saja/internet. Ini adalah rentang port untuk `NodePort` yang akan mengekspos aplikasi Anda.

## Langkah 7: Deploy Aplikasi ke Kubernetes

Buat dua file manifes berikut di direktori Anda.

1.  **`deployment.yaml`**
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nodejs-app-deployment
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: nodejs-app
      template:
        metadata:
          labels:
            app: nodejs-app
        spec:
          containers:
          - name: guide-to-k8-container
            image: ghcr.io/[nama_user_github]/guide-to-k8:latest # Ganti dengan username Anda
            ports:
            - containerPort: 3000
    ```

2.  **`service.yaml`**
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: nodejs-app-service
    spec:
      type: NodePort
      selector:
        app: nodejs-app
      ports:
        - protocol: TCP
          port: 80
          targetPort: 3000
          nodePort: 30100 # Port eksternal yang akan diakses
    ```

## Langkah 8: Troubleshooting - `ErrImagePull` (Private Registry)

Error ini terjadi karena cluster K3s tidak memiliki izin untuk mengunduh image dari `ghcr.io` yang mewajibkan autentikasi.

1.  **Buat `ImagePullSecret`**
    Buat sebuah "rahasia" di Kubernetes yang berisi kredensial Anda. **Gunakan Personal Access Token (PAT)**, bukan password GitHub Anda.
    ```bash
    kubectl create secret docker-registry ghcr-secret \
      --docker-server=ghcr.io \
      --docker-username=[NAMA_USER_GITHUB] \
      --docker-password=[PERSONAL_ACCESS_TOKEN] \
      --docker-email=[EMAIL_ANDA]
    ```

2.  **Perbarui `deployment.yaml`**
    Edit `deployment.yaml` dan tambahkan `imagePullSecrets`.
    ```yaml
    # ... (bagian atas file sama)
    spec:
      template:
        # ... (metadata sama)
        spec:
          containers:
          - name: guide-to-k8-container
            image: ghcr.io/[nama_user_github]/guide-to-k8:latest
            ports:
            - containerPort: 3000
          imagePullSecrets:      # <--- TAMBAHKAN BAGIAN INI
          - name: ghcr-secret   # <--- DAN INI
    ```

3.  **Terapkan Konfigurasi**
    Jalankan perintah ini dari node server untuk membuat dan memperbarui aplikasi Anda.
    ```bash
    kubectl apply -f deployment.yaml -f service.yaml
    ```

## Langkah 9: Verifikasi Akhir

1.  **Periksa Status Pods**
    Pastikan semua pods berstatus `Running`. Opsi `-o wide` akan menunjukkan penyebaran pods di kedua node Anda.
    ```bash
    kubectl get pods -o wide
    ```

2.  **Akses Aplikasi Anda**
    Buka browser dan akses aplikasi melalui **salah satu IP VPS** Anda di port `30100`.
    *   `http://[IP_VPS_SERVER]:30100`
    *   atau `http://[IP_VPS_AGENT]:30100`

Keduanya akan menampilkan pesan "Hi There" dari aplikasi Anda.