#!/bin/bash
set -e

echo -e "\033[32mDown app! \033[0m"
docker compose -f app.compose.yml down

echo -e "\033[32mDown efk stack! \033[0m"
docker compose -f efk.compose.yml down 