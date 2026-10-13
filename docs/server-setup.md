# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- Операционная система: Ubuntu Server 24.04.5 LTS
- Оперативная память: 2048 МБ
- Количество ядер: 2
- Объём диска: 25 ГБ, динамически расширяемый

## 2. Сетевые интерфейсы

- Адаптер 1: NAT
- IP-адрес NAT: 10.0.2.15
- Назначение: доступ виртуальной машины в Интернет

- Адаптер 2: Host-only
- IP-адрес Host-only: 192.168.56.101
- Назначение: взаимодействие хостовой системы Windows с виртуальной машиной

## 3. Правило проброса портов

- Имя: ssh
- Протокол: TCP
- IP хоста: 127.0.0.1
- Порт хоста: 2222
- IP гостевой системы: не задан
- Порт гостевой системы: 2222

## 4. Учётные записи

### student
- Создан при установке Ubuntu Server
- Использовался для первоначальной настройки

### devops
- Включён в группу sudo
- Используется для администрирования сервера
- Аутентификация выполняется по SSH-ключу devops_vm
- Парольная SSH-аутентификация отключена

## 5. Служба SSH

Порт: 2222

Файл конфигурации:

/etc/ssh/sshd_config.d/99-hardening.conf

Параметры:

Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2

Служба ssh.socket отключена.
Используется ssh.service.

## 6. Правила межсетевого экрана

UFW активен.

Политики по умолчанию:

- incoming: deny
- outgoing: allow

Правила:

- 2222/tcp - LIMIT - SSH
- 80/tcp - ALLOW - HTTP
- 443/tcp - ALLOW - HTTPS

Логирование UFW: medium.

## 7. Снимки состояния

1. 01-clean-install - чистая установка Ubuntu Server.
2. 02-keys-configured - настроена ключевая SSH-аутентификация.
3. 03-ssh-hardened - выполнено усиление защиты SSH.


## 9. Контейнеризация

Docker Engine установлен из официального APT-репозитория Docker для Ubuntu Noble.

```bash
sudo apt update
sudo apt install -y ca-certificates curl nginx rsync
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable' | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker devops
```

Завершить SSH-сессию и подключиться повторно. devops уже входит в sudo;
членство в docker также фактически даёт административный доступ к хосту.
На хосте исходники находятся в app/. Доставка выполняется через rsync сначала
с --dry-run, затем с теми же параметрами без него. Обязательное исключение .env
сохраняет серверный секрет при повторной доставке.

```bash
rsync -avz --delete --exclude=.env --dry-run app/ devops:app/
rsync -avz --delete --exclude=.env app/ devops:app/
```

При отсутствии rsync на Windows исходники передаются SFTP в ~/staging на VM,
после чего выполняются rsync -av --delete --exclude=.env --dry-run ~/staging/ ~/app/
и rsync -av --delete --exclude=.env ~/staging/ ~/app/. Секрет на хост не копируется.

Файл .env создаётся только на VM при первом развёртывании:

```bash
cd ~/app
umask 077
cp .env.example .env
chmod 600 .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/" .env
docker compose up -d --build --wait
docker compose ps
```

При повторном развёртывании существующий .env сохраняется: смена пароля только
в .env не меняет пароль пользователя в уже инициализированном PostgreSQL.
.env исключён из Git и контекста Docker. В репозитории хранится только .env.example.

Оба сервиса подключены к bridge-сети app_backend. DB_HOST=db разрешается встроенным
DNS Docker. Том app_db_data хранит /var/lib/postgresql/data независимо от контейнера.
Порт приложения привязан к 127.0.0.1:5000, порт PostgreSQL на хост не публикуется.
Зависимость service_healthy ждёт pg_isready перед запуском приложения.

В HTTPS-блок Nginx /etc/nginx/sites-available/devops-site добавлен фрагмент:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
curl --cacert ~/devops.crt https://devops.local/app/
curl --cacert ~/devops.crt https://devops.local/app/health
scripts/audit.sh
```

При 502 проверить docker compose ps, docker compose logs app, curl localhost:5000/health
и /var/log/nginx/devops-site.error.log. После docker compose start app повторить HTTPS-запрос.
docker compose down сохраняет том; down -v удаляет учебные данные и используется
только в отдельном тесте сброса счётчика. Итоговые контейнеры, том и снимки 04-nginx-https,
05-docker-compose сохранены.
