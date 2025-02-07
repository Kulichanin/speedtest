#!/bin/bash
set -e

echo -e "\033[32mStart efk stack before app! \033[0m"
docker compose -f efk.compose.yml up -d 

echo -e "\033[32mStart app! \033[0m"
docker compose -f app.compose.yml up -d --build