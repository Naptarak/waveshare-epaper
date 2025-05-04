#!/bin/bash

# Tiszta telepítés a Waveshare GitHub-ról
echo "==== Waveshare Tiszta Teszt ===="

# Tiszta telepítési könyvtár létrehozása
INSTALL_DIR=~/waveshare_test
echo "Telepítési könyvtár: $INSTALL_DIR"
rm -rf $INSTALL_DIR
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Csomagok telepítése
echo "Szükséges csomagok telepítése..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-pil python3-numpy git python3-rpi.gpio python3-spidev

# SPI engedélyezése
echo "SPI ellenőrzése..."
if ! grep -q "^dtparam=spi=on" /boot/config.txt; then
    echo "SPI engedélyezése..."
    sudo sh -c "echo 'dtparam=spi=on' >> /boot/config.txt"
    echo "!!! Újraindítás szükséges az SPI használatához !!!"
    REBOOT_NEEDED=true
fi

# Waveshare könyvtár letöltése
echo "Waveshare GitHub könyvtár letöltése..."
git clone https://github.com/waveshare/e-Paper.git

# Teszt program létrehozása
echo "Teszt program létrehozása..."
cat > $INSTALL_DIR/clean_test.py << 'EOL'
#!/usr/bin/env python3
import os
import sys
import time
import logging
from PIL import Image, ImageDraw, ImageFont

# Logging beállítása
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger()

# Aktuális könyvtár
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
logger.info(f"Aktuális könyvtár: {CURRENT_DIR}")

# Elérési út hozzáadása
LIB_DIR = os.path.join(CURRENT_DIR, "e-Paper/RaspberryPi_JetsonNano/python/lib")
sys.path.append(LIB_DIR)
logger.info(f"Könyvtár hozzáadva: {LIB_DIR}")

try:
    # Könyvtárak listázása ellenőrzésképpen
    logger.info(f"Könyvtár tartalma ({LIB_DIR}):")
    for item in os.listdir(LIB_DIR):
        logger.info(f"  - {item}")
    
    # Waveshare_epd könyvtár ellenőrzése
    waveshare_dir = os.path.join(LIB_DIR, "waveshare_epd")
    logger.info(f"Waveshare könyvtár tartalma ({waveshare_dir}):")
    for item in os.listdir(waveshare_dir):
        logger.info(f"  - {item}")
    
    # Waveshare könyvtár betöltése
    logger.info("Waveshare e-Paper könyvtár betöltése...")
    from waveshare_epd import epd4in01f
    logger.info("Könyvtár sikeresen betöltve!")
    
    # E-Paper inicializálása
    logger.info("E-Paper kijelző inicializálása...")
    epd = epd4in01f.EPD()
    epd.init()
    
    # Képernyő törlése
    logger.info("Képernyő törlése...")
    epd.Clear()
    
    # Teszt kép létrehozása
    logger.info("Teszt kép létrehozása...")
    image = Image.new('RGB', (epd.width, epd.height), 'white')
    draw = ImageDraw.Draw(image)
    
    # Keretek rajzolása
    draw.rectangle((0, 0, epd.width, epd.height), outline='black')
    draw.rectangle((10, 10, epd.width-10, epd.height-10), outline='red')
    
    # Betűtípus beállítása
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 36)
    except:
        font = ImageFont.load_default()
    
    # Szöveg kiírása
    draw.text((120, 80), 'Tiszta Teszt', font=font, fill='black')
    draw.text((120, 150), 'Waveshare e-Paper', font=font, fill='red')
    draw.text((120, 220), 'GitHub Telepítés', font=font, fill='blue')
    draw.text((120, 290), f'Idő: {time.strftime("%H:%M:%S")}', font=font, fill='green')
    
    # Kép megjelenítése
    logger.info("Kép megjelenítése...")
    epd.display(epd.getbuffer(image))
    logger.info("SIKER! A teszt sikeresen lefutott!")
    
except Exception as e:
    logger.error(f"HIBA: {e}")
    import traceback
    logger.error(traceback.format_exc())
EOL

# Jogosultságok beállítása
chmod +x clean_test.py

# Tesztprogram futtatása
echo "Tesztprogram futtatása..."
cd $INSTALL_DIR
python3 clean_test.py

echo "==== Teszt befejezve ===="
if [ "$REBOOT_NEEDED" = "true" ]; then
    echo ""
    echo "!!! FONTOS: Újra kell indítani a rendszert az SPI használatához !!!"
    echo "Gépeld be: sudo reboot"
    echo ""
else
    echo "Ellenőrizd, megjelent-e valami a kijelzőn."
    echo "Ha nem, nézd meg a hibaüzeneteket fentebb."
fi
