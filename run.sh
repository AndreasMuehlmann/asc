$(dirname "$0")/build.sh
$(dirname "$0")/deploy_raspi.sh
source client/venv/bin/activate
python $(dirname "$0")/client/main.py
