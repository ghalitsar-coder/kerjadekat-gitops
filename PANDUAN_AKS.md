# Panduan Lengkap Migrasi KerjaDekat ke Azure AKS Lite

Panduan ini berisi langkah-langkah **Infrastructure as Code (IaC)** ringan dan instruksi *end-to-end* untuk mendeploy KerjaDekat menggunakan **Azure Kubernetes Service (AKS)**, dengan memanfaatkan pola *GitOps*.

**Konfigurasi ini menggunakan mode "AKS Lite":**
- Menggunakan Azure for Students.
- Di Cloud (AKS) hanya menjalankan: Backend, Frontend, dan PostgreSQL.
- Di Lokal (Docker): Jenkins, Redis, RabbitMQ, Kong, Monitoring (demi menghemat credit).
- Tidak menggunakan ACR, menggunakan DockerHub publik (gratis).
- Backend & Frontend otomatis diexpose menggunakan *Azure LoadBalancer* langsung tanpa Kong.

---

## 1. Persiapan Awal
Pastikan Anda sudah login di terminal Anda:
```bash
az login
```

## 2. Membuat AKS Cluster (Via Portal)
Karena Azure for Students memiliki kebijakan ketat mengenai region mana yang boleh membuat Virtual Machine (AKS node), **buatlah klaster melalui Azure Portal** agar portal otomatis men-filter region yang valid untuk Anda.

1. Buka [Azure Portal](https://portal.azure.com)
2. Cari **Kubernetes services** > **Create a Kubernetes cluster**
3. Isi data:
   - **Resource Group:** Buat baru `kerjadekat-aks-rg`
   - **Cluster preset configuration:** Pilih **Dev/Test** (Penting! Agar hemat)
   - **Kubernetes cluster name:** `kerjadekat-aks`
   - **Region:** Pilih yang tersedia untuk akun Anda (biasanya `East US`, `Central US`, atau `Japan East`).
   - **Node size:** Cari `Standard_B2s` atau `Standard_B2ms` (jika B2s tidak ada).
   - **Node count range:** Set Manual ke **1 node** saja.
4. Klik **Review + Create**, lalu **Create**.
5. Tunggu sekitar 5-10 menit.

## 3. Menghubungkan Terminal ke AKS
Setelah AKS "Succeeded" di portal, buka terminal laptop Anda dan hubungkan `kubectl` ke AKS:
```bash
az aks get-credentials --resource-group kerjadekat-aks-rg --name kerjadekat-aks
```
Cek apakah terhubung:
```bash
kubectl get nodes
```

## 4. Persiapan Images (Lokal ke DockerHub)
Karena kita tidak menggunakan ACR berbayar, Anda wajib mem-build dan push *custom image* database ke DockerHub Anda.
```bash
bash infrastructure/scripts/04b-push-images-to-dockerhub.sh
```

## 5. Menjalankan ArgoCD dan GitOps Bootstrap
Sekarang, mari instal ArgoCD ke dalam AKS dan arahkan ke repositori Anda. Script ini sudah dikonfigurasi menunjuk ke *overlay* AKS Lite.
```bash
bash infrastructure/scripts/05-aks-connect-argocd.sh
```
*Tunggu beberapa menit hingga ArgoCD menampilkan Password Admin dan LoadBalancer IP.*

## 6. Uji Coba Aplikasi
Karena Kong ada di lokal, AKS Lite secara otomatis memberikan IP Publik ke service Backend dan Frontend melalui *Azure Load Balancer*.
Jalankan perintah ini untuk melihat IP Publik aplikasi Anda:
```bash
kubectl get svc -n kerjadekat
```
- Cari `frontend-svc` kolom `EXTERNAL-IP`. Buka IP tersebut di browser.
- Cari `backend-svc` kolom `EXTERNAL-IP`. Ini adalah base URL API Anda.

*(Catatan: Pastikan Anda membuka port Redis dan RabbitMQ lokal jika Backend Anda butuh koneksi ke sana, atau ubah env di Kustomize agar menunjuk ke localhost/ngrok).*
