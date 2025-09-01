#!/bin/bash

# Hentikan script jika ada error
set -e

echo "=== Memulai Instalasi K3s ==="

# 1. Mengunduh dan menginstal K3s
if ! command -v k3s &> /dev/null
then
    curl -sfL https://get.k3s.io | sh -
    echo "K3s berhasil diinstal."
else
    echo "K3s sudah terinstal, melewati instalasi."
fi

echo ""
echo "=== Instalasi Selesai ==="
echo ""
echo "Server K3s Anda sudah berjalan."
echo "Untuk mengkonfigurasi 'kubectl' bagi pengguna Anda, login sebagai pengguna tersebut dan jalankan perintah berikut:"
echo ""
echo "----------------------------------------------------------------"
echo "mkdir -p ~/.kube"
echo "sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config"
echo "sudo chown $(id -u):$(id -g) ~/.kube/config"
echo ""
echo "# (Opsional tapi direkomendasikan) Buat alias permanen"
echo "echo \"alias kubectl='kubectl --kubeconfig ~/.kube/config'\" >> ~/.bashrc"
echo "source ~/.bashrc"
echo "----------------------------------------------------------------"
echo ""
echo "Setelah itu, verifikasi dengan 'kubectl get nodes'"
