#!/bin/bash

# Dừng script ngay lập tức nếu có bất kỳ lệnh nào bị lỗi
set -e

echo "===================================================="
echo " Bắt đầu cài đặt Docker & Docker Compose (Ubuntu 24.04)"
echo "===================================================="

# 1. Gỡ bỏ các gói xung đột cũ (nếu có)
echo "[1/6] Đang gỡ bỏ các gói Docker cũ (nếu tồn tại)..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

# 2. Cập nhật hệ thống và cài đặt các gói phụ thuộc
echo "[2/6] Cập nhật apt và cài đặt chứng chỉ bảo mật..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 3. Thêm khóa GPG chính thức của Docker
echo "[3/6] Thêm Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 4. Thêm Docker repository vào nguồn Apt
echo "[4/6] Cấu hình Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Cài đặt Docker Engine, Containerd và Docker Compose Plugin
echo "[5/6] Đang tải và cài đặt Docker + Docker Compose..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Cấu hình quyền chạy không cần sudo & khởi động cùng hệ thống
echo "[6/6] Cấu hình quyền user và kích hoạt service..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

echo "===================================================="
echo " CÀI ĐẶT HOÀN TẤT!"
echo "===================================================="
docker --version
docker compose version
echo "----------------------------------------------------"
echo "LƯU Ý QUAN TRỌNG: Hãy chạy lệnh 'newgrp docker' hoặc"
echo "đăng xuất (logout) và đăng nhập lại để dùng lệnh"
echo "docker mà không cần gõ 'sudo'."
echo "===================================================="