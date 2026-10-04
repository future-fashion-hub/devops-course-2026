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
