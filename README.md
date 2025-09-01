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

## Langkah Selanjutnya

Dengan image yang sudah ada di registry dan cluster K3s yang sudah siap, langkah selanjutnya adalah membuat file manifes Kubernetes (misalnya, `deployment.yaml` dan `service.yaml`) untuk mendeploy aplikasi Anda ke dalam cluster.
