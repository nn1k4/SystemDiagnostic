# SystemDiagnostic.ps1 v26 - Enhanced SMART & Performance Monitoring

> **Комплексный диагностический скрипт PowerShell для анализа Windows систем в enterprise окружении**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-Server%202016%2B%20%7C%20Windows%2010%2B-green.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Maintained](https://img.shields.io/badge/Maintained-Yes-brightgreen.svg)](https://github.com/user/repo)

## 📋 Описание

SystemDiagnostic.ps1 v26 - это продвинутый инструмент системной диагностики, разработанный для комплексного анализа Windows систем. Скрипт выполняет глубокую проверку 22 ключевых компонентов системы и создает детальный отчет о состоянии оборудования, производительности и конфигурации.

### 🎯 Основные возможности

- **🔍 Комплексная диагностика**: 22 модуля анализа системы
- **🌡️ SMART мониторинг**: Диагностика дисков с анализом температуры и износа
- **🖥️ Температурный контроль**: CPU, GPU, материнская плата (LibreHardwareMonitor)
- **📊 Анализ производительности**: CPU, память, диски, сеть
- **🛡️ Проверка безопасности**: BitLocker, службы, события
- **💾 Анализ дампов памяти**: Выявление системных сбоев
- **🔧 Целостность системы**: SFC проверка файлов
- **📁 Оптимизация для RDP**: Отчеты <500KB для удаленной работы

## 🖥️ Системные требования

### Минимальные требования
- **ОС**: Windows Server 2016, Windows 10 (версия 1607) или выше
- **PowerShell**: 5.1 или выше
- **Права**: Администратор (обязательно)
- **RAM**: 512 MB свободной памяти
- **Место на диске**: 100 MB для временных файлов

### Рекомендуемые требования
- **ОС**: Windows Server 2019/2022, Windows 11
- **PowerShell**: 7.x
- **.NET Framework**: 4.7.2+ (для температурного мониторинга)
- **Сеть**: Интернет (для загрузки LibreHardwareMonitor)

## 🚀 Быстрый старт

### ⚠️ **ПЕРВЫЙ ЗАПУСК: Решение проблемы Execution Policy**

Если вы получаете ошибку "cannot be loaded. The file is not digitally signed":

```powershell
# ВАРИАНТ 1: Временное разрешение (РЕКОМЕНДУЕТСЯ)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\SystemDiagnostic.ps1

# ВАРИАНТ 2: Одноразовый bypass
powershell.exe -ExecutionPolicy Bypass -File ".\SystemDiagnostic.ps1"

# ВАРИАНТ 3: Если файл скачан из интернета
Unblock-File -Path ".\SystemDiagnostic.ps1"
.\SystemDiagnostic.ps1
```

### Базовое использование
```powershell
# Скачать и запустить от имени администратора
.\SystemDiagnostic.ps1
```

### Расширенная диагностика
```powershell
# Полная диагностика с детальными проверками
.\SystemDiagnostic.ps1 -Extended
```

### Автоматический режим (для скриптов)
```powershell
# Тихий режим без интерактивных элементов
.\SystemDiagnostic.ps1 -ExportOnly
```

### Кастомная папка для отчета
```powershell
# Сохранение отчета в указанную папку
.\SystemDiagnostic.ps1 -OutputPath "C:\Reports"
```

## 📊 Модули диагностики

### 🖥️ Системная информация (Модули 1-6)
| Модуль | Описание | Проверяет |
|--------|----------|-----------|
| **System Info** | Основная информация о системе | ОС, архитектура, домен, пользователь |
| **Motherboard & BIOS** | Материнская плата и BIOS | Производитель, модель, версии, SMBIOS |
| **CPU** | Процессор и загрузка | Модель, частота, ядра, температура, нагрузка (5s avg) |
| **Memory** | Оперативная память | Планки, объем, тип (DDR3/4/5), использование |
| **Video Controllers** | Видеокарты | GPU, VRAM, драйверы, разрешение |
| **Monitors** | Мониторы | Модели, производители, разрешения |

### 💾 Хранилище и диски (Модули 7-8)
| Модуль | Описание | Проверяет |
|--------|----------|-----------|
| **Disks & Storage** | Логические и физические диски | Размер, свободное место, файловые системы |
| **SMART Health** | Диагностика здоровья дисков | Температура, износ, ошибки чтения, время работы |

### 🌐 Сеть и подключения (Модули 9-13)
| Модуль | Описание | Проверяет |
|--------|----------|-----------|
| **Network Adapters** | Сетевые адаптеры | Ethernet, WiFi, скорость, MAC-адреса |
| **Network Config** | IP конфигурация | IP адреса, маски, шлюзы, DNS |
| **Connectivity** | Сетевое подключение | Интернет, DNS, локальная сеть |
| **Languages** | Языки и раскладки | Системная локаль, языковые пакеты |
| **Printers** | Принтеры | Установленные принтеры, статус, драйверы |

### 🌡️ Мониторинг и производительность (Модули 11-17)
| Модуль | Описание | Проверяет |
|--------|----------|-----------|
| **Temperature** | Температурный мониторинг | CPU, GPU, системная плата (LibreHardwareMonitor) |
| **Event Logs** | Системные события | Критические ошибки, предупреждения |
| **Services** | Службы Windows | Критические службы, статус, автозагрузка |
| **Startup Items** | Автозагрузка | Реестр, папки автозагрузки |
| **Processes** | Системные процессы | Топ процессы по CPU/RAM, счетчики производительности |
| **Memory Dumps** | Анализ дампов памяти | Minidumps, MEMORY.DMP, сбои системы |

### 🛡️ Безопасность и целостность (Модули 18-22)
| Модуль | Описание | Проверяет |
|--------|----------|-----------|
| **System Files** | Целостность файлов | SFC проверка, DISM, критические файлы |
| **Windows License** | Лицензирование | Статус активации, тип лицензии |
| **Windows Updates** | Обновления | Последние обновления, Windows Update служба |
| **BitLocker** | Шифрование дисков | Статус защиты томов, методы шифрования |
| **Final Report** | Итоговый отчет | Сводка, рекомендации, статистика |

## 📝 Параметры командной строки

### Основные параметры

| Параметр | Тип | Описание | Пример |
|----------|-----|----------|--------|
| `-Extended` | Switch | Включает расширенные проверки (SFC, детальные логи) | `.\SystemDiagnostic.ps1 -Extended` |
| `-ExportOnly` | Switch | Тихий режим без интерактивных элементов | `.\SystemDiagnostic.ps1 -ExportOnly` |
| `-OutputPath` | String | Папка для сохранения отчета | `.\SystemDiagnostic.ps1 -OutputPath "C:\Reports"` |

### Комбинирование параметров
```powershell
# Полная тихая диагностика в кастомную папку
.\SystemDiagnostic.ps1 -Extended -ExportOnly -OutputPath "\\Server\Reports"

# Расширенная интерактивная диагностика
.\SystemDiagnostic.ps1 -Extended
```

## 📋 Формат отчета

### Структура файла отчета
```
SystemDiagnostic_v26_YYYYMMDD_HHMMSS.txt
└── Заголовок с метаданными
└── 22 секции диагностики
└── Итоговая сводка
└── Рекомендации
```

### Пример имени файла
```
SystemDiagnostic_v26_Extended_20250103_143022.txt
```

### Система оценки состояния
| Статус | Диапазон проблем | Описание |
|--------|------------------|----------|
| **EXCELLENT** | 0 проблем | Система в идеальном состоянии |
| **GOOD** | 1-2 проблемы | Незначительные замечания |
| **FAIR** | 3-5 проблем | Требует внимания |
| **NEEDS ATTENTION** | 6+ проблем | Критические проблемы |

## 🛡️ Безопасность и предупреждения

### ⚠️ Важные предупреждения

#### PowerShell Execution Policy
- **По умолчанию** Windows блокирует выполнение неподписанных скриптов
- **Рекомендуется** использовать временный Bypass (-Scope Process)
- **ИЗБЕГАЙТЕ** постоянного изменения политики без необходимости
- **Альтернатива**: Запуск через `powershell.exe -ExecutionPolicy Bypass`

#### Права администратора
- Скрипт **ТРЕБУЕТ** запуска от имени администратора
- Доступ к системным компонентам и реестру
- Возможность установки .NET Framework

#### Сетевые подключения
- Загрузка LibreHardwareMonitor с GitHub (~2MB)
- Возможна загрузка .NET Framework 4.8 (~120MB)
- Проверка интернет-подключения

#### Производительность системы
- Время выполнения: 2-5 минут (зависит от режима)
- Использование CPU: временные пики при диагностике
- Дисковые операции: чтение системной информации

### 🔒 Обработка данных

#### Конфиденциальность
- **НЕ собирает** личные данные пользователей
- **НЕ отправляет** информацию во внешние системы
- Все данные остаются локально

#### Собираемая информация
- ✅ Системная конфигурация и характеристики
- ✅ Статус служб и процессов
- ✅ Информация об оборудовании
- ❌ Персональные файлы или документы
- ❌ Пароли или учетные данные

## 🔧 Устранение неполадок

### Частые проблемы и решения

#### 🚨 "File cannot be loaded. Not digitally signed" ошибка
**Причина**: PowerShell Execution Policy блокирует неподписанные скрипты

**Решения по приоритету:**
```powershell
# 1. Проверить текущую политику
Get-ExecutionPolicy

# 2. Временное решение (сбросится при закрытии PowerShell)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 3. Одноразовый запуск с bypass
powershell.exe -ExecutionPolicy Bypass -File ".\SystemDiagnostic.ps1"

# 4. Если файл скачан из интернета - разблокировать
Unblock-File -Path ".\SystemDiagnostic.ps1"

# 5. Постоянное решение для пользователя (ОСТОРОЖНО!)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Уровни Execution Policy:**
- `Restricted` - не выполняет скрипты (по умолчанию)
- `RemoteSigned` - выполняет локальные + подписанные удаленные
- `Unrestricted` - выполняет все скрипты (небезопасно)
- `Bypass` - временно игнорирует политику

#### "Requires -Version 5.1" ошибка
```powershell
# Проверить версию PowerShell
$PSVersionTable.PSVersion

# Обновить PowerShell до 5.1+
# https://docs.microsoft.com/powershell/scripting/install/installing-powershell
```

#### .NET Framework проблемы
```powershell
# Проверить версию .NET Framework
Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release

# Если Release < 461808, скрипт предложит установку .NET Framework 4.8
```

#### Проблемы с LibreHardwareMonitor
- **VirtualBox**: Температурные сенсоры недоступны (ожидаемое поведение)
- **Старые .NET**: Требуется .NET Framework 4.7.2+
- **TLS ошибки**: Скрипт автоматически включает TLS 1.2

#### Медленная работа в VM
- **CPU sampling errors**: Скрипт автоматически обрабатывает VirtualBox ограничения
- **Сетевые задержки**: Загрузка в VM может занимать больше времени

### Режимы диагностики

#### Стандартный режим
- Все модули кроме SFC проверки
- Интерактивные запросы пользователя
- Время выполнения: ~2-3 минуты

#### Extended режим (-Extended)
- Включает SFC проверку системных файлов
- Детальные логи и дополнительная информация
- Время выполнения: ~3-5 минут

#### ExportOnly режим (-ExportOnly)
- Без интерактивных элементов
- Подходит для автоматизации
- Автоматический пропуск .NET Framework установки

## 📊 Примеры использования

### 1. Ежедневная проверка сервера
```powershell
# Создать задачу в Task Scheduler
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\SystemDiagnostic.ps1 -ExportOnly"
$Trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
Register-ScheduledTask -TaskName "Daily System Check" -Action $Action -Trigger $Trigger
```

### 2. Удаленная диагностика через RDP
```powershell
# Оптимизированные отчеты для копирования через RDP
.\SystemDiagnostic.ps1 -OutputPath "C:\Temp"
# Файлы <500KB идеальны для копирования
```

### 3. Массовая диагностика серверов
```powershell
# PowerShell Remoting для множественных серверов
$Servers = @("Server01", "Server02", "Server03")
Invoke-Command -ComputerName $Servers -ScriptBlock {
    & "C:\Scripts\SystemDiagnostic.ps1" -ExportOnly -OutputPath "C:\Reports"
}
```

### 4. Интеграция с мониторингом
```powershell
# Анализ результатов для алертов
$Report = Get-Content "SystemDiagnostic_v26_*.txt" | Where-Object {$_ -like "*Issues Found:*"}
if ($Report -match "Issues Found: ([6-9]|\d{2,})") {
    Send-MailMessage -Subject "Server Alert: Multiple Issues" -Body $Report
}
```

## 🚀 Новое в версии 26

### ✨ Основные улучшения

#### 🔥 SMART диагностика дисков
- Анализ температуры и износа SSD/HDD
- Предупреждения о критическом состоянии
- Мониторинг времени работы и ошибок чтения

#### 🧠 Анализ дампов памяти
- Автоматическое обнаружение minidumps и MEMORY.DMP
- Анализ частоты сбоев системы
- Предупреждения о нестабильности

#### ⚡ Улучшенный CPU мониторинг
- **ИСПРАВЛЕНО**: Точная формула загрузки CPU
- Усреднение по 5 измерениям для точности
- Специальная обработка VirtualBox ограничений

#### 🌡️ Надежный температурный мониторинг
- Автоматическая загрузка LibreHardwareMonitor
- Интерактивная установка .NET Framework 4.8
- TLS 1.2 поддержка для Windows Server 2016

#### 🔧 Расширенные счетчики производительности
- Детальная диагностика дисков (только в -Extended)
- Анализ использования памяти
- Интеллектуальные предупреждения

### 🛠️ Технические улучшения

#### Оптимизация размера отчетов
- Компактное форматирование данных
- Отчеты <500KB 
- Умная фильтрация избыточной информации

#### Улучшенная обработка ошибок
- Graceful degradation при недоступности компонентов
- Детальное логирование для диагностики
- Fallback методы для критических проверок

#### Совместимость с виртуализацией
- Автоматическое определение VirtualBox/VMware
- Адаптация методов диагностики
- Корректная обработка виртуальных ограничений

## 📚 Дополнительные ресурсы

### Документация Microsoft
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Windows System Information](https://docs.microsoft.com/windows/desktop/cimwin32prov/computer-system-hardware-classes)
- [Performance Counters](https://docs.microsoft.com/windows/win32/perfctrs/performance-counters-portal)

### Инструменты диагностики
- [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor)
- [Microsoft Support and Recovery Assistant](https://support.microsoft.com/help/17588)
- [Windows Performance Toolkit](https://docs.microsoft.com/windows-hardware/test/wpt/)

### Сообщество
- [PowerShell Community](https://github.com/PowerShell/PowerShell)
- [Reddit r/PowerShell](https://www.reddit.com/r/PowerShell/)
- [Stack Overflow PowerShell](https://stackoverflow.com/questions/tagged/powershell)

## 🤝 Вклад в развитие

### Сообщение об ошибках
1. Проверьте существующие issues
2. Приложите SystemDiagnostic отчет
3. Укажите версию ОС и PowerShell
4. Опишите шаги воспроизведения

### Предложения улучшений
- Новые модули диагностики
- Оптимизация производительности
- Поддержка дополнительного оборудования
- Интеграция с системами мониторинга

## 📄 Лицензия

MIT License - см. файл [LICENSE](LICENSE) для деталей.

## 🔄 История версий

### v26 (Текущая)
- ✅ SMART диагностика дисков
- ✅ Анализ дампов памяти  
- ✅ Исправлен CPU мониторинг
- ✅ Улучшенный температурный контроль
- ✅ .NET Framework автоустановка
- Расширенные сетевые проверки
- Улучшенная BitLocker диагностика
- Оптимизация размера отчетов
- Модульная архитектура
- 22 диагностических модуля
- Extended режим
- RDP оптимизация

---

**💡 Совет**: Для лучших результатов запускайте диагностику в период низкой нагрузки системы.

**🆘 Поддержка**: При проблемах создайте issue с приложением отчета SystemDiagnostic.

---
*SystemDiagnostic.ps1 - Комплексная диагностика Windows систем для IT профессионалов*