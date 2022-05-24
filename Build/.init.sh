#!/bin/bash

# TODO: добавить проверку на запущенность AMIGO перед запуском

set -eu

# Остановка AMIGO
sudo systemctl stop amigo@Maze.service

# Копируем конфигурационные файлы для инициализации
cp ./.scenarios/init/AmigoConfig.xml AmigoConfig.xml
cp ./.scenarios/init/AMIGOMAIN.xml AMIGOMAIN.xml

# Удаление БД
echo "Dropping database"
mongo mongodb://127.0.0.1/AMIGO_DB_Maze --eval "db.dropDatabase()"

# Запуск AMIGO в режиме инициализации
echo "Starting AMIGO up"
sudo systemctl start amigo@Maze.service

echo "Waiting for AMIGO REST API"
AMIGO_STATUS=$(curl -o /dev/null -Isw '%{http_code}\n' http://127.0.0.1/api)
while [ $AMIGO_STATUS -ne 200 ]
do
  sleep 5
  AMIGO_STATUS=$(curl -o /dev/null -Isw '%{http_code}\n' http://127.0.0.1/api)
done
echo "AMIGO REST API available"

echo "Writing initial values to database"

# Запись константы 0 в БД
echo "0 -> constants.zero"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"path":"SystemValue:constants.zero","value":0}' \
  http://localhost/api/values
echo ""

sleep 1

# Запись константы 1 в БД
echo  "1 -> constants.one"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"path":"SystemValue:constants.one","value":1}' \
  http://localhost/api/values
echo ""

sleep 1

# Запись стандартного значения допустимого перетока мощности в сеть
echo "0 -> cfg.maxPOUT"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"path":"SystemValue:cfg.maxPOUT","value":0}' \
  http://localhost/api/values
echo ""

sleep 1

# Запись стандартного значения цены на ЭЭ из сети
echo "3 -> cfg.gridEnergyPrice"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"path":"SystemValue:cfg.gridEnergyPrice","value":3}' \
  http://localhost/api/values
echo ""

sleep 1

# Установка флага init.success - сигнал об успешной инициализации системы, не первый старт, можно запускать модули
echo "Loading data from CSV files"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"path":"SystemValue:init.success","value":1, "event":"LD01"}' \
  http://localhost/api/values
echo ""

sleep 1

# Запуск расчета ошибки прогнозирования на модуле IHTC-01 - необходимо для записи в БД информации о первом старте задачи
echo "Starting load forecast error calculation task"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"moduleType": "IHTC", "instanceNumber": 1, "operation": "CLFE", "action": "start"}' \
  http://localhost/api/moduleCommands
echo ""

sleep 1

# Запуск расчета ошибки прогнозирования на модуле IHTC-11 - необходимо для записи в БД информации о первом старте задачи
echo "Starting solar forecast error calculation task"
echo ""
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"moduleType": "IHTC", "instanceNumber": 11, "operation": "CLFE", "action": "start"}' \
  http://localhost/api/moduleCommands
echo ""

sleep 1

# Копируем конфигурационные файлы для работы
cp ./.scenarios/stage/AmigoConfig.xml AmigoConfig.xml
cp ./.scenarios/stage/AMIGOMAIN.xml AMIGOMAIN.xml

# Создаем файл с информацией об успешной инициализации системы
touch .initsuccess

echo "Init complete, wait until all CSV data being imported"