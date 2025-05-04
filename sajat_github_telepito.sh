#!/bin/bash

# Saját GitHub Repository Telepítő
echo "==== Saját GitHub Repository Telepítő ===="

# GitHub adatok bekérése
echo -n "Add meg a GitHub felhasználónevedet: "
read github_user

echo -n "Add meg a repository nevét: "
read github_repo

echo -n "Add meg a repository ágát (alapértelmezett: main): "
read github_branch
if [ -z "$github_branch" ]; then
    github_branch="main"
fi

# GitHub URL összeállítása
GITHUB_URL="https://github.com/$github_user/$github_repo.git"
echo "Repository URL: $GITHUB_URL"

# Telepítési könyvtár létrehozása
INSTALL_DIR=~/my_waveshare_test
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

# Saját repository klónozása
echo "Saját GitHub repository klónozása: $GITHUB_URL"
git clone $GITHUB_URL -b $github_branch my_repo

# Könyvtárstruktúra ellenőrzése
echo "Könyvtárstruktúra ellenőrzése..."
if [ -d "my_repo/RaspberryPi_JetsonNano/python/lib/waveshare_epd" ]; then
    WAVESHARE_DIR="my_repo/RaspberryPi_JetsonNano/python/lib"
    echo "Waveshare könyvtár megtalálva: $WAVESHARE_DIR"
elif [ -d "my_repo/lib/waveshare_epd" ]; then
    WAVESHARE_DIR="my_repo/lib"
    echo "Waveshare könyvtár megtalálva: $WAVESHARE_DIR"
elif [ -d "my_repo/waveshare_epd" ]; then
    WAVESHARE_DIR="my_repo"
    echo "Waveshare könyvtár megtalálva: $WAVESHARE_DIR"
else
    echo "HIBA: Nem található a waveshare_epd könyvtár a repositoryban!"
    echo "Kérlek ellenőrizd a repository struktúráját."
    exit 1
fi

# Teszt program létrehozása
echo "Teszt program létrehozása..."
cat > $INSTALL_DIR/my_test.py << EOL
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
WAVESHARE_DIR = os.path.join(CURRENT_DIR, "$WAVESHARE_DIR")
sys.path.append(WAVESHARE_DIR)
logger.info(f"Könyvtár hozzáadva: {WAVESHARE_DIR}")

try:
    # Könyvtárak listázása ellenőrzésképpen
    logger.info(f"Könyvtár tartalma:")
    for item in os.listdir(WAVESHARE_DIR):
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
    draw.text((120, 80), 'Saját GitHub Repo', font=font, fill='black')
    draw.text((120, 150), 'Waveshare e-Paper', font=font, fill='red')
    draw.text((120, 220), 'Teszt Program', font=font, fill='blue')
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
chmod +x my_test.py

# Tesztprogram futtatása
echo "Tesztprogram futtatása..."
cd $INSTALL_DIR
python3 my_test.py

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
