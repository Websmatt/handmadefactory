#!/bin/bash
# Instalacja Dockera na Ubuntu 22.04

set -e  # Zatrzymaj skrypt przy błędzie

echo "🔄 Aktualizacja systemu..."
sudo apt update && sudo apt upgrade -y

echo "📦 Instalacja zależności..."
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "🔑 Tworzenie katalogu dla kluczy..."
sudo mkdir -p /etc/apt/keyrings

echo "⬇️ Pobieranie klucza GPG Dockera..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "➕ Dodawanie repozytorium Dockera..."
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Odświeżenie repozytoriów..."
sudo apt update

echo "🐳 Instalacja Dockera i dodatków..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "✅ Instalacja zakończona! Możesz teraz uruchomić: sudo docker run hello-world"
