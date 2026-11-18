#!/bin/bash

# Định nghĩa màu sắc
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Đường dẫn cấu hình
CODE_DIR="/home/atuandev/user-service"
APP_DIR="/opt/quickbite/user-service"
JAR_NAME="user-service-0.0.1.jar"
LOG_FILE="/opt/quickbite/user-service.log"
PORT=8080

echo -e "${YELLOW}=== BẮT ĐẦU QUY TRÌNH DEPLOY ===${NC}"

# ==========================================
# BƯỚC 1: Build & Test (Fail-fast)
# ==========================================
echo -e "\n${YELLOW}[1/5] Đang biên dịch mã nguồn...${NC}"
cd $CODE_DIR || { echo -e "${RED}Lỗi: Không tìm thấy thư mục code!${NC}"; exit 1; }

./gradlew clean bootJar
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}[FAIL-FAST] Lỗi Build! Dừng script ngay lập tức.${NC}"
    exit 1
fi
echo -e "${GREEN}-> Build thành công!${NC}"

# ==========================================
# BƯỚC 2: Chuẩn bị hạ tầng thư mục
# ==========================================
echo -e "\n${YELLOW}[2/5] Chuẩn bị thư mục hạ tầng...${NC}"
if [ ! -d "$APP_DIR" ]; then
    echo "Thư mục chưa tồn tại. Đang tạo mới..."
    sudo mkdir -p $APP_DIR
    sudo chown -R quickbite:quickbite /opt/quickbite
else
    echo "Thư mục đã tồn tại."
fi
echo -e "${GREEN}-> Hạ tầng thư mục sẵn sàng!${NC}"

# ==========================================
# BƯỚC 3: Sao chép ứng dụng
# ==========================================
echo -e "\n${YELLOW}[3/5] Dừng tiến trình cũ và Copy JAR mới...${NC}"
sudo pkill -f "$JAR_NAME" || true
sleep 1

sudo cp "$CODE_DIR/build/libs/$JAR_NAME" "$APP_DIR/$JAR_NAME"
sudo chown quickbite:quickbite "$APP_DIR/$JAR_NAME"
echo -e "${GREEN}-> Copy file JAR thành công!${NC}"

# ==========================================
# BƯỚC 4: Khởi động dịch vụ
# ==========================================
echo -e "\n${YELLOW}[4/5] Khởi động dịch vụ ngầm...${NC}"
sudo -u quickbite nohup java -jar "$APP_DIR/$JAR_NAME" > "$LOG_FILE" 2>&1 &
echo "Đang chờ JVM khởi tạo..."

# ==========================================
# BƯỚC 5: Smoke Test (Kiểm tra cổng)
# ==========================================
echo -e "\n${YELLOW}[5/5] Smoke Test đang kiểm tra cổng $PORT...${NC}"
sleep 5

if sudo ss -tulpn | grep -q ":$PORT "; then
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}   DEPLOY DỊCH VỤ THÀNH CÔNG! (Cổng $PORT đã mở)${NC}"
    echo -e "${GREEN}==========================================${NC}"
else
    echo -e "${RED}==========================================${NC}"
    echo -e "${RED}   DEPLOY THẤT BẠI! Cổng $PORT không phản hồi.${NC}"
    echo -e "${RED}   30 DÒNG LOG CUỐI CÙNG CỦA ỨNG DỤNG:${NC}"
    echo -e "${RED}==========================================${NC}"
    sudo tail -n 30 "$LOG_FILE"
    exit 1
fi
