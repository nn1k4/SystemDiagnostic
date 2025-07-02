# ===================================================================================
# SYSTEM DIAGNOSTIC SCRIPT v26 - ENHANCED SMART & PERFORMANCE MONITORING
# Улучшенная версия с SMART диагностикой, анализом дампов и расширенными счетчиками
# Базируется на проверенной методике температурного мониторинга
# ===================================================================================

#Requires -Version 5.1

param(
    [switch]$ExportOnly,
    [switch]$Extended,
    [string]$OutputPath = "."
)

# ===================================================================================
# ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА
# ===================================================================================

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ ОШИБКА: Требуются права администратора!" -ForegroundColor Red
    Write-Host "Запустите PowerShell как администратор и попробуйте снова." -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

# ===================================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ===================================================================================

$Global:StartTime = Get-Date
$Global:IssuesCount = 0
$Global:LogEntries = [System.Collections.Generic.List[string]]::new()
$Global:CurrentModule = 0
$Global:TotalModules = 22

# Отключение progress bars в ExportOnly режиме
if ($ExportOnly) {
    $ProgressPreference = 'SilentlyContinue'
}

# ===================================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (ПРОСТЫЕ И НАДЕЖНЫЕ)
# ===================================================================================

function Invoke-SafeDiagnostic {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Description
    )
    
    try {
        Write-DiagnosticLog "Starting: $Description" -Level "DEBUG"
        & $ScriptBlock
        Write-DiagnosticLog "Completed: $Description" -Level "SUCCESS"
    } catch {
        Write-DiagnosticLog "Error in $Description`: $($_.Exception.Message)" -Level "ERROR"
        $Global:IssuesCount++
    }
}

# ===================================================================================
# УЛУЧШЕННАЯ ФУНКЦИЯ Get-TemperatureInfo С ИНТЕРАКТИВНОЙ УСТАНОВКОЙ .NET 4.7.2
# ===================================================================================

function Test-DotNetVersion {
    <#
    .SYNOPSIS
    Проверяет установленную версию .NET Framework
    
    .DESCRIPTION
    Возвращает $true если установлен .NET 4.7.2 или выше, иначе $false
    #>
    
    try {
        # Проверяем .NET Framework версию через реестр
        $releaseKey = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
        
        if ($releaseKey) {
            $dotNetVersion = $releaseKey.Release
            
            # .NET Framework 4.7.2 имеет Release >= 461808
            if ($dotNetVersion -ge 461808) {
                $versionText = switch ($dotNetVersion) {
                    {$_ -ge 528040} { "4.8 или выше" }
                    {$_ -ge 461808} { "4.7.2" }
                    default { "Неизвестная версия ($dotNetVersion)" }
                }
                Write-DiagnosticLog ".NET Framework: $versionText (Release: $dotNetVersion)" -Level "INFO"
                return $true
            } else {
                $versionText = switch ($dotNetVersion) {
                    {$_ -ge 460798} { "4.7" }
                    {$_ -ge 394802} { "4.6.2" }
                    {$_ -ge 394254} { "4.6.1" }
                    {$_ -ge 393295} { "4.6" }
                    {$_ -ge 379893} { "4.5.2" }
                    {$_ -ge 378675} { "4.5.1" }
                    {$_ -ge 378389} { "4.5" }
                    default { "Старая версия ($dotNetVersion)" }
                }
                Write-DiagnosticLog ".NET Framework: $versionText (Release: $dotNetVersion) - требуется 4.7.2+" -Level "WARNING"
                return $false
            }
        } else {
            Write-DiagnosticLog ".NET Framework: Не удалось определить версию" -Level "ERROR"
            return $false
        }
    } catch {
        Write-DiagnosticLog ".NET Framework: Ошибка проверки версии - $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Install-DotNetDirect {
    <#
    .SYNOPSIS
    Прямая загрузка и установка .NET Framework 4.8 с управлением перезагрузкой
    
    .DESCRIPTION
    Универсальный метод установки .NET Framework 4.8 для Windows Server 2016/2019/2022, Windows 10/11
    Использует только официальный offline installer от Microsoft
    #>
    
    try {
        Write-DiagnosticLog "Установка .NET Framework 4.8 через прямую загрузку..." -Level "INFO"
        
        # 🚨 КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ О ПЕРЕЗАГРУЗКЕ
        if (-not $ExportOnly) {
            Write-Host ""
            Write-Host "🚨 КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ О ПЕРЕЗАГРУЗКЕ!" -ForegroundColor Red
            Write-Host ("=" * 60) -ForegroundColor Red
            Write-Host "⚠️  .NET Framework 4.8 может потребовать АВТОМАТИЧЕСКУЮ ПЕРЕЗАГРУЗКУ сервера!" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "🔄 ВАРИАНТЫ УСТАНОВКИ:" -ForegroundColor Cyan
            Write-Host "[A] - Установить с автоматической перезагрузкой (рекомендуется)" -ForegroundColor Green
            Write-Host "[M] - Установить БЕЗ автоматической перезагрузки (ручная перезагрузка)" -ForegroundColor Yellow
            Write-Host "[N] - Отменить установку" -ForegroundColor Red
            Write-Host ""
            
            do {
                $rebootChoice = Read-Host "Ваш выбор (A/M/N)"
                $rebootChoice = $rebootChoice.ToUpper().Trim()
                
                if ($rebootChoice -eq "A" -or $rebootChoice -eq "AUTO") {
                    Write-Host "✅ Выбрана установка с автоматической перезагрузкой" -ForegroundColor Green
                    $installArgs = "/quiet"
                    break
                } elseif ($rebootChoice -eq "M" -or $rebootChoice -eq "MANUAL") {
                    Write-Host "⚠️ Выбрана установка БЕЗ автоматической перезагрузки" -ForegroundColor Yellow
                    Write-Host "   После установки ОБЯЗАТЕЛЬНО перезагрузите сервер вручную!" -ForegroundColor Yellow
                    $installArgs = "/quiet /norestart"
                    break
                } elseif ($rebootChoice -eq "N" -or $rebootChoice -eq "NO") {
                    Write-Host "❌ Установка отменена пользователем" -ForegroundColor Red
                    return $false
                } else {
                    Write-Host "❌ Неверный выбор. Введите A (авто), M (ручная) или N (отмена)" -ForegroundColor Red
                }
            } while ($true)
        } else {
            # В ExportOnly режиме используем /norestart по умолчанию
            Write-DiagnosticLog "ExportOnly режим: используем /norestart параметр" -Level "INFO"
            $installArgs = "/quiet /norestart"
        }
        
        # Актуальные URL для .NET Framework 4.8
        $dotNet48Urls = @(
            # Актуальная рабочая ссылка Microsoft Visual Studio
            "https://download.visualstudio.microsoft.com/download/pr/1f5af042-d0e4-4002-9c59-9ba66bcf15f6/089f837de42708daacaae7c04b7494db/ndp48-x86-x64-allos-enu.exe",
            # Резервная официальная ссылка Microsoft
            "https://go.microsoft.com/fwlink/?linkid=2088631",
            # Альтернативная прямая ссылка
            "https://download.microsoft.com/download/6/E/4/6E48E8AB-DC00-419E-9704-06DD46E5F81D/ndp48-x86-x64-allos-enu.exe"
        )
        
        $dotNet48Installer = Join-Path $PSScriptRoot "NDP48-x86-x64-AllOS-ENU.exe"
        
        # Обеспечиваем TLS 1.2 для Windows Server 2016
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Попытка загрузки с нескольких URL
        $downloadSuccess = $false
        foreach ($url in $dotNet48Urls) {
            try {
                Write-DiagnosticLog "Попытка загрузки .NET Framework 4.8 с: $($url.Split('/')[-1])" -Level "DEBUG"
                # Временно закомментируй если нужно пропустить скачивание файла во время теста. 
				# В таком случае добавь файл "NDP48-x86-x64-AllOS-ENU.exe" руками.
                Invoke-WebRequest -Uri $url -OutFile $dotNet48Installer -UseBasicParsing -TimeoutSec 300
                
                if (Test-Path $dotNet48Installer) {
                    $fileSize = [math]::Round((Get-Item $dotNet48Installer).Length / 1MB, 1)
                    
                    if ($fileSize -gt 100) {  # .NET Framework 4.8 должен быть ~120MB
                        Write-DiagnosticLog ".NET Framework 4.8 скачан успешно (${fileSize}MB)" -Level "SUCCESS"
                        $downloadSuccess = $true
                        break
                    } else {
                        Write-DiagnosticLog "Загруженный файл слишком мал (${fileSize}MB) - возможно ошибка" -Level "WARNING"
                        Remove-Item $dotNet48Installer -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-DiagnosticLog "Загрузка с $($url.Split('/')[-1]) не удалась: $($_.Exception.Message)" -Level "DEBUG"
                if (Test-Path $dotNet48Installer) {
                    Remove-Item $dotNet48Installer -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if (-not $downloadSuccess) {
            Write-DiagnosticLog "Все попытки загрузки .NET Framework 4.8 не удались" -Level "ERROR"
            Write-DiagnosticLog "Рекомендация: Загрузите .NET Framework 4.8 вручную с https://dotnet.microsoft.com/download/dotnet-framework/net48" -Level "WARNING"
            return $false
        }
        
        # Запуск установки с выбранными параметрами
        Write-DiagnosticLog "Запуск установки .NET Framework 4.8 с параметрами: $installArgs" -Level "INFO"
        $installProcess = Start-Process -FilePath $dotNet48Installer -ArgumentList $installArgs -Wait -PassThru
        
        # Анализ кода выхода установщика
        $exitCode = $installProcess.ExitCode
        switch ($exitCode) {
            0 { 
                Write-DiagnosticLog ".NET Framework 4.8 установлен успешно" -Level "SUCCESS"
                if ($installArgs -contains "/norestart") {
                    Write-DiagnosticLog "⚠️ ТРЕБУЕТСЯ РУЧНАЯ ПЕРЕЗАГРУЗКА для завершения установки!" -Level "WARNING"
                }
                $installSuccess = $true
            }
            3010 { 
                Write-DiagnosticLog ".NET Framework 4.8 установлен успешно (требуется перезагрузка)" -Level "SUCCESS"
                if ($installArgs -contains "/norestart") {
                    Write-DiagnosticLog "⚠️ ТРЕБУЕТСЯ РУЧНАЯ ПЕРЕЗАГРУЗКА для завершения установки!" -Level "WARNING"
                }
                $installSuccess = $true
            }
            5100 { 
                Write-DiagnosticLog ".NET Framework 4.8 уже установлен (или более новая версия)" -Level "SUCCESS"
                $installSuccess = $true
            }
            1602 {
                Write-DiagnosticLog "Установка отменена пользователем" -Level "WARNING"
                $installSuccess = $false
            }
            1603 {
                Write-DiagnosticLog "Критическая ошибка установки" -Level "ERROR"
                $installSuccess = $false
            }
            1641 {
                Write-DiagnosticLog "Установка завершена, система была перезагружена" -Level "SUCCESS"
                $installSuccess = $true
            }
            default {
                Write-DiagnosticLog "Установка завершилась с неожиданным кодом: $exitCode" -Level "WARNING"
                $installSuccess = $false
            }
        }
        
        # Проверка успешности установки
        if ($installSuccess) {
            # Дополнительная проверка версии .NET Framework после установки
            Start-Sleep -Seconds 3  # Даем время для обновления реестра
            
            $newRelease = (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue).Release
            if ($newRelease -ge 528040) {  # .NET Framework 4.8
                Write-DiagnosticLog "Подтверждена установка .NET Framework 4.8 (Release: $newRelease)" -Level "SUCCESS"
                return $true
            } elseif ($newRelease -ge 461808) {  # .NET Framework 4.7.2+
                Write-DiagnosticLog "Установлен .NET Framework 4.7.2+ (Release: $newRelease) - достаточно для LibreHardwareMonitor" -Level "SUCCESS"
                return $true
            } else {
                Write-DiagnosticLog "После установки версия .NET Framework все еще недостаточна (Release: $newRelease)" -Level "WARNING"
                Write-DiagnosticLog "Возможно требуется перезагрузка для завершения установки" -Level "WARNING"
                return $false
            }
        } else {
            return $false
        }
        
    } catch {
        Write-DiagnosticLog "Критическая ошибка установки .NET Framework: $($_.Exception.Message)" -Level "ERROR"
        return $false
    } finally {
        # Очистка загруженного файла
        if (Test-Path $dotNet48Installer) {
            Remove-Item $dotNet48Installer -Force -ErrorAction SilentlyContinue
            Write-DiagnosticLog "Установочный файл .NET Framework удален" -Level "DEBUG"
        }
    }
}

function Get-UserChoiceEnhanced {
    <#
    .SYNOPSIS
    Упрощенный интерактивный запрос с предупреждениями о перезагрузке
    
    .DESCRIPTION
    Предлагает установку .NET Framework 4.8 через прямую загрузку официального installer
    #>
    
    if ($ExportOnly) {
        Write-DiagnosticLog "ExportOnly режим: автоматически пропускаем установку .NET Framework" -Level "INFO"
        return $false
    }
    
    Write-Host ""
    Write-Host "🔧 ТРЕБУЕТСЯ .NET FRAMEWORK 4.7.2+" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Yellow
    Write-Host "LibreHardwareMonitor требует .NET Framework 4.7.2 или выше" -ForegroundColor White
    Write-Host "для корректного температурного мониторинга." -ForegroundColor White
    Write-Host ""
    Write-Host "🚨 ВАЖНЫЕ ПРЕДУПРЕЖДЕНИЯ:" -ForegroundColor Red
    Write-Host "• Установка займет 5-15 минут" -ForegroundColor Yellow
    Write-Host "• МОЖЕТ ПОТРЕБОВАТЬСЯ АВТОМАТИЧЕСКАЯ ПЕРЕЗАГРУЗКА СЕРВЕРА ⚠️" -ForegroundColor Red
    Write-Host "• Кратковременная нагрузка на систему во время установки" -ForegroundColor Yellow
    Write-Host "• Рекомендуется в период технического обслуживания" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ ДОСТУПНОЕ РЕШЕНИЕ:" -ForegroundColor Green
    Write-Host "• Прямая загрузка и установка .NET Framework 4.8" -ForegroundColor White
    Write-Host "• Официальный offline installer от Microsoft (~120MB)" -ForegroundColor White
    Write-Host "• Универсальная совместимость: Windows Server 2016+, Windows 10/11" -ForegroundColor White
    Write-Host "• Полный контроль над процессом перезагрузки" -ForegroundColor White
    Write-Host ""
    Write-Host "🌡️ ПРЕИМУЩЕСТВА:" -ForegroundColor Green
    Write-Host "• Температурный мониторинг CPU, GPU, материнской платы" -ForegroundColor White
    Write-Host "• Раннее предупреждение о перегреве оборудования" -ForegroundColor White
    Write-Host "• Улучшенная диагностика системы" -ForegroundColor White
    Write-Host ""
    Write-Host "ВАРИАНТЫ:" -ForegroundColor Cyan
    Write-Host "[Y] - Установить .NET Framework 4.8 (с контролем перезагрузки)" -ForegroundColor Green
    Write-Host "[N] - Пропустить температурный мониторинг" -ForegroundColor Yellow
    Write-Host "[M] - Показать ручные инструкции" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        $choice = Read-Host "Ваш выбор (Y/N/M)"
        $choice = $choice.ToUpper().Trim()
        
        if ($choice -eq "Y" -or $choice -eq "YES" -or $choice -eq "Д" -or $choice -eq "ДА") {
            Write-Host "✅ Выбрана установка .NET Framework 4.8 через прямую загрузку" -ForegroundColor Green
            return $true
        } elseif ($choice -eq "N" -or $choice -eq "NO" -or $choice -eq "Н" -or $choice -eq "НЕТ") {
            Write-Host "⏭️  Температурный мониторинг будет пропущен" -ForegroundColor Yellow
            return $false
        } elseif ($choice -eq "M" -or $choice -eq "М") {
            Write-Host ""
            Write-Host "📋 РУЧНЫЕ ИНСТРУКЦИИ ПО УСТАНОВКЕ .NET FRAMEWORK 4.8:" -ForegroundColor Cyan
            Write-Host ("=" * 60) -ForegroundColor Cyan
            Write-Host ""
            Write-Host "🌐 ВАРИАНТ 1: Прямая загрузка (РЕКОМЕНДУЕТСЯ)" -ForegroundColor Green
            Write-Host "1. Перейдите на https://dotnet.microsoft.com/download/dotnet-framework/net48" -ForegroundColor White
            Write-Host "2. Нажмите 'Download .NET Framework 4.8 Runtime'" -ForegroundColor White
            Write-Host "3. Выберите 'Offline installer' (~120MB)" -ForegroundColor White
            Write-Host "4. Запустите установщик от имени администратора" -ForegroundColor White
            Write-Host ""
            Write-Host "   📝 ПАРАМЕТРЫ КОМАНДНОЙ СТРОКИ:" -ForegroundColor Gray
            Write-Host "   • /quiet - автоматическая установка с перезагрузкой" -ForegroundColor Gray
            Write-Host "   • /quiet /norestart - БЕЗ автоматической перезагрузки" -ForegroundColor Gray
            Write-Host ""
            Write-Host "🔄 ВАРИАНТ 2: Windows Update" -ForegroundColor Green
            Write-Host "1. Откройте Windows Update (Пуск → Настройки → Обновления)" -ForegroundColor White
            Write-Host "2. Нажмите 'Проверить обновления'" -ForegroundColor White
            Write-Host "3. Найдите и установите обновления .NET Framework" -ForegroundColor White
            Write-Host "4. Дождитесь завершения и перезагрузки" -ForegroundColor White
            Write-Host ""
            Write-Host "⚡ ВАРИАНТ 3: PowerShell (быстрый метод)" -ForegroundColor Green
            Write-Host "# Скачать и установить:" -ForegroundColor Gray
            Write-Host '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12' -ForegroundColor Gray
            Write-Host '$url = "https://go.microsoft.com/fwlink/?linkid=2088631"' -ForegroundColor Gray
            Write-Host 'Invoke-WebRequest $url -OutFile "ndp48.exe" -UseBasicParsing' -ForegroundColor Gray
            Write-Host 'Start-Process "ndp48.exe" -ArgumentList "/quiet /norestart" -Wait' -ForegroundColor Gray
            Write-Host ""
            Write-Host "🔍 ПРОВЕРКА УСПЕШНОЙ УСТАНОВКИ:" -ForegroundColor Green
            Write-Host '$release = (Get-ItemProperty "HKLM:\\SOFTWARE\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full\\" -Name Release).Release' -ForegroundColor Gray
            Write-Host 'if ($release -ge 528040) { "✅ .NET Framework 4.8 установлен" } else { "❌ Требуется установка" }' -ForegroundColor Gray
            Write-Host ""
            Write-Host "🚨 ВАЖНО ПОСЛЕ УСТАНОВКИ:" -ForegroundColor Red
            Write-Host "• При выборе /norestart - ОБЯЗАТЕЛЬНО перезагрузите сервер вручную!" -ForegroundColor Red
            Write-Host "• Проверьте версию .NET Framework после перезагрузки" -ForegroundColor Yellow
            Write-Host "• Перезапустите диагностический скрипт для активации температурного мониторинга" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "💡 СОВЕТ: После установки и перезагрузки запустите скрипт снова" -ForegroundColor Cyan
            Write-Host "для проверки работоспособности температурного мониторинга." -ForegroundColor Cyan
            Write-Host ""
            return $false
        } else {
            Write-Host "❌ Неверный выбор. Введите Y (да), N (нет) или M (инструкции)" -ForegroundColor Red
        }
    } while ($true)
}

function Get-TemperatureInfo {
    <#
    .SYNOPSIS
    Улучшенная функция температурного мониторинга с автоматической проверкой .NET 4.7.2
    
    .DESCRIPTION
    Проверяет наличие .NET Framework 4.7.2, предлагает установку при необходимости,
    скачивает LibreHardwareMonitor и выполняет температурный мониторинг
    #>
    
    Write-DiagnosticLog "Starting temperature monitoring with .NET Framework validation" -Level "INFO"
    
    # Шаг 1: Проверка версии .NET Framework
    $dotNetOk = Test-DotNetVersion
    
    if (-not $dotNetOk) {
        Write-DiagnosticLog ".NET Framework 4.7.2+ не обнаружен" -Level "WARNING"
        
        # Шаг 2: Интерактивный запрос установки
        $shouldInstall = Get-UserChoiceEnhanced
        
        if ($shouldInstall) {
            Write-DiagnosticLog "Пользователь выбрал установку .NET Framework 4.7.2" -Level "INFO"
            
            # Шаг 3: Установка .NET Framework 4.7.2
            $installSuccess = Install-DotNetDirect
            
            if (-not $installSuccess) {
                Write-DiagnosticLog "Не удалось установить .NET Framework 4.7.2 - пропускаем температурный мониторинг" -Level "ERROR"
                return
            }
            
            # Повторная проверка после установки
            $dotNetOk = Test-DotNetVersion
            if (-not $dotNetOk) {
                Write-DiagnosticLog ".NET Framework 4.7.2 все еще недоступен после установки - возможно требуется перезагрузка" -Level "WARNING"
                Write-DiagnosticLog "Пропускаем температурный мониторинг до перезагрузки системы" -Level "WARNING"
                return
            }
        } else {
            Write-DiagnosticLog "Пользователь отказался от установки .NET Framework - пропускаем температурный мониторинг" -Level "INFO"
            return
        }
    }
    
    # Шаг 4: Продолжаем с LibreHardwareMonitor (исходная логика)
    $lhmDir = Join-Path $PSScriptRoot 'LibreHardwareMonitor'
    $lhmExe = Join-Path $lhmDir 'LibreHardwareMonitor.exe'
    
    # Create directory if missing
    if (-not (Test-Path $lhmDir)) {
        $null = New-Item -ItemType Directory -Path $lhmDir -Force
    }
    
    if (-not (Test-Path $lhmExe)) {
        Write-DiagnosticLog "LibreHardwareMonitor not found. Downloading..." -Level "WARNING"
        $zip = Join-Path $PSScriptRoot 'LHM.zip'
        $url = 'https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.4/LibreHardwareMonitor-net472.zip'
        
        try {
            # Включить TLS 1.2 для Windows Server 2016
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $lhmDir -Force
            Remove-Item $zip -Force
            Write-DiagnosticLog "LibreHardwareMonitor downloaded and installed" -Level "SUCCESS"
        } catch {
            Write-DiagnosticLog "Download failed: $($_.Exception.Message)" -Level "ERROR"
            return
        }
    }
    
    # Шаг 5: Запуск температурного мониторинга (исходная логика)
    if (Test-Path $lhmExe) {
        $proc = Start-Process -FilePath $lhmExe -PassThru -WindowStyle Hidden
        
        # Initial wait for service registration
        Write-DiagnosticLog "Waiting for LibreHardwareMonitor initialization" -Level "DEBUG"
        Start-Sleep -Seconds 15  # Increased initial wait time
        
        $sensors = $null
        $retries = 12
        $delay = 5
        $namespaceReady = $false
        
        for ($i = 1; $i -le $retries; $i++) {
            # Check process status
            if ($proc.HasExited) {
                $exitCode = $proc.ExitCode
                Write-DiagnosticLog "LibreHardwareMonitor exited prematurely (Code: ${exitCode})" -Level "ERROR"
                return
            }
            
            try {
                $sensors = Get-CimInstance -Namespace "root\LibreHardwareMonitor" -Class Sensor -ErrorAction Stop
                if ($sensors) {
                    $namespaceReady = $true
                    Write-DiagnosticLog "WMI namespace initialized successfully" -Level "DEBUG"
                    break
                }
            } catch {
                Write-DiagnosticLog "Attempt ${i}/${retries}: $($_.Exception.Message)" -Level "DEBUG"
            }
            
            Start-Sleep -Seconds $delay
        }
        
        if (-not $namespaceReady) {
            Write-DiagnosticLog "Failed to initialize temperature monitoring after $($retries * $delay) seconds" -Level "ERROR"
        } else {
            $temps = $sensors | Where-Object { 
                $_.SensorType -eq 'Temperature' -and 
                $_.Value -gt 0 -and 
                $_.Value -lt 100 -and  # Исключаем аномально высокие значения
                $_.Name -notmatch "Virtual|Composite|Average"  # Фильтр ложных сенсоров
            }
            
            if ($temps) {
                Write-DiagnosticLog "Found $($temps.Count) valid temperature sensors" -Level "DEBUG"
                foreach ($s in $temps) {
                    $name = ($s.Name -replace '[^\w\s()]', '').Trim()
                    $val = [math]::Round($s.Value, 1)
                    
                    # Highlight high temperatures
                    if ($val -gt 90) {
                        Write-DiagnosticLog "Sensor ${name}: ${val}°C [HIGH TEMPERATURE!]" -Level "WARNING"
                    } elseif ($val -gt 80) {
                        Write-DiagnosticLog "Sensor ${name}: ${val}°C [WARM]" -Level "WARNING"
                    } else {
                        Write-DiagnosticLog "Sensor ${name}: ${val}°C" -Level "INFO"
                    }
                }
            } else {
                Write-DiagnosticLog "No valid temperature sensors detected" -Level "WARNING"
            }
        }
        
        # Cleanup process
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-DiagnosticLog {
    param(
        [string]$Message, 
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "PROGRESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $Global:LogEntries.Add($logEntry)
    
    if (-not $ExportOnly) {
        $color = switch($Level) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" } 
            "ERROR" { "Red" }
            "PROGRESS" { "Cyan" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

function Update-Progress {
    param([string]$Activity, [int]$PercentComplete)
    
    $Global:CurrentModule++
    Write-DiagnosticLog "$PercentComplete% ($Global:CurrentModule/$Global:TotalModules) - $Activity" -Level "PROGRESS"
    
    if (-not $ExportOnly) {
        Write-Progress -Activity "🔍 SYSTEM DIAGNOSTIC v26" -Status $Activity -PercentComplete $PercentComplete
    }
}

function Format-ComponentInfo {
    param([object]$Object, [string[]]$Properties)
    
    if ($null -eq $Object) { 
        return "Недоступно" 
    }
    
    $info = @()
    foreach ($prop in $Properties) {
        try {
            $value = $Object.$prop
            if ($null -ne $value -and $value -ne "") {
                if ($value -is [array]) {
                    $value = $value -join ", "
                }
                $info += "$prop=$value"
            }
        } catch {
            # Безопасное игнорирование ошибок свойств
        }
    }
    
    # ИСПРАВЛЕНО: Правильный PowerShell синтаксис (не return if)
    if ($info.Count -gt 0) {
        return $info -join "; "
    } else {
        return "Нет данных"
    }
}

# ===================================================================================
# ЗАГОЛОВОК ДИАГНОСТИКИ
# ===================================================================================

if (-not $ExportOnly) {
    Clear-Host
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "🔍 SYSTEM DIAGNOSTIC TOOL v26 - ENHANCED SMART & PERFORMANCE MONITORING" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "Время запуска: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Green
    Write-Host "Режим: Полная диагностика с SMART мониторингом и анализом производительности" -ForegroundColor Green
    if ($Extended) {
        Write-Host "Расширенный режим: ВКЛЮЧЕН" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-DiagnosticLog "===== SYSTEM DIAGNOSTIC TOOL v26 - ENHANCED SMART & PERFORMANCE MONITORING ====="
Write-DiagnosticLog "Начало полной диагностики системы"
if ($Extended) {
    Write-DiagnosticLog "Extended mode: ENABLED"
}

# ===================================================================================
# МОДУЛЬ 1: СИСТЕМНАЯ ИНФОРМАЦИЯ
# ===================================================================================

Update-Progress "System Information" 5

try {
    $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
    if ($computerInfo) {
        $osInfo = Format-ComponentInfo $computerInfo @('WindowsProductName', 'WindowsVersion', 'WindowsBuildLabEx', 'TotalPhysicalMemory')
        Write-DiagnosticLog "OS: $osInfo"
        
        $systemInfo = Format-ComponentInfo $computerInfo @('CsManufacturer', 'CsModel', 'CsProcessors', 'Domain')
        Write-DiagnosticLog "System: $systemInfo"
        
        $userInfo = Format-ComponentInfo $computerInfo @('CsUserName', 'CsDomain', 'TimeZone')
        Write-DiagnosticLog "User: $userInfo"
    } else {
        Write-DiagnosticLog "Fallback: Используем WMI для системной информации"
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        
        if ($os) {
            Write-DiagnosticLog "OS: $($os.Caption) $($os.Version) Build $($os.BuildNumber)"
            Write-DiagnosticLog "Architecture: $($os.OSArchitecture)"
            Write-DiagnosticLog "Install Date: $($os.InstallDate)"
        }
        if ($cs) {
            Write-DiagnosticLog "System: $($cs.Manufacturer) $($cs.Model)"
            Write-DiagnosticLog "Domain: $($cs.Domain)"
            Write-DiagnosticLog "User: $($cs.UserName)"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения системной информации: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 2: МАТЕРИНСКАЯ ПЛАТА И BIOS
# ===================================================================================

Update-Progress "Motherboard & BIOS" 10

try {
    $motherboard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    if ($motherboard) {
        $mbInfo = Format-ComponentInfo $motherboard @('Manufacturer', 'Product', 'Version', 'SerialNumber')
        Write-DiagnosticLog "Motherboard: $mbInfo"
        
        # Дополнительная информация о материнской плате
        if ($Extended) {
            $mbDetails = Format-ComponentInfo $motherboard @('Model', 'ConfigOptions', 'CreationClassName')
            if ($mbDetails -ne "Нет данных") {
                Write-DiagnosticLog "MB Details: $mbDetails"
            }
        }
    }
    
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue  
    if ($bios) {
        $biosInfo = Format-ComponentInfo $bios @('Manufacturer', 'Name', 'Version', 'ReleaseDate')
        Write-DiagnosticLog "BIOS: $biosInfo"
        
        # SMBIOS информация
        if ($Extended) {
            $biosDetails = Format-ComponentInfo $bios @('SerialNumber', 'SMBIOSBIOSVersion', 'SMBIOSMajorVersion', 'SMBIOSMinorVersion')
            if ($biosDetails -ne "Нет данных") {
                Write-DiagnosticLog "SMBIOS: $biosDetails"
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о материнской плате: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# ИСПРАВЛЕННЫЙ МОДУЛЬ 3: ПРОЦЕССОР (ТОЧНАЯ ДИАГНОСТИКА ЗАГРУЗКИ)
# ===================================================================================

Update-Progress "CPU Information" 15

try {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    if ($cpu) {
        foreach ($proc in $cpu) {
            $cpuInfo = Format-ComponentInfo $proc @('Name', 'Manufacturer', 'MaxClockSpeed', 'NumberOfCores', 'NumberOfLogicalProcessors')
            Write-DiagnosticLog "CPU: $cpuInfo"
            
            # Архитектура и кэш
            $cpuArch = switch ($proc.Architecture) {
                0 { "x86" }
                1 { "MIPS" }
                2 { "Alpha" }
                3 { "PowerPC" }
                6 { "Itanium" }
                9 { "x64" }
                default { "Unknown($($proc.Architecture))" }
            }
            Write-DiagnosticLog "CPU Architecture: $cpuArch"
            
            # Кэш процессора
            if ($proc.L2CacheSize -or $proc.L3CacheSize) {
                $cacheInfo = @()
                if ($proc.L2CacheSize) { $cacheInfo += "L2=$($proc.L2CacheSize)KB" }
                if ($proc.L3CacheSize) { $cacheInfo += "L3=$($proc.L3CacheSize)KB" }
                Write-DiagnosticLog "CPU Cache: $($cacheInfo -join ', ')"
            }
            
            # Дополнительные характеристики
            if ($Extended) {
                $cpuFeatures = Format-ComponentInfo $proc @('Family', 'Model', 'Stepping', 'ProcessorId')
                if ($cpuFeatures -ne "Нет данных") {
                    Write-DiagnosticLog "CPU Features: $cpuFeatures"
                }
            }
        }
    }
    
	# ===================================================================================
    # ✅ ИСПРАВЛЕННАЯ ЗАГРУЗКА ПРОЦЕССОРА - МЕТОД С УСРЕДНЕНИЕМ
	# ===================================================================================
    try {
        Write-DiagnosticLog "Measuring CPU load over 5 seconds for accuracy..." -Level "DEBUG"
		
		$isVirtualBox = (Get-CimInstance Win32_ComputerSystem).Manufacturer -like "*innotek*"
		if ($isVirtualBox) {
			Write-DiagnosticLog "VirtualBox detected - using adapted CPU monitoring" -Level "DEBUG"
		}
        
        $measurements = @()
        $sampleCount = 5
        
        # Собираем 5 измерений по 1 секунде каждое
        for ($i = 1; $i -le $sampleCount; $i++) {
            try {
                $cpuSample = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                if ($cpuSample -and $cpuSample.CounterSamples) {
                    # ✅ ИСПРАВЛЕНО: Убрано вычитание из 100 - счетчик УЖЕ показывает проценты!
                    $currentLoad = [math]::Round($cpuSample.CounterSamples[0].CookedValue, 1)
                    $measurements += $currentLoad
                    Write-DiagnosticLog "Sample $i`: $currentLoad%" -Level "DEBUG"
                } else {
                    Write-DiagnosticLog "Failed to get CPU sample $i" -Level "DEBUG"
                }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-DiagnosticLog "Error getting CPU sample $i`: $errorMsg" -Level "DEBUG"
            
            # Специальная обработка VirtualBox ошибки
            if ($errorMsg -like "*negative denominator*" -and $isVirtualBox) {
                Write-DiagnosticLog "VirtualBox counter limitation detected - continuing with available samples" -Level "WARNING"
            }
        }
        }
        
        # Вычисляем среднюю загрузку
        if ($measurements.Count -gt 0) {
            $averageLoad = [math]::Round(($measurements | Measure-Object -Average).Average, 1)
            $minLoad = [math]::Round(($measurements | Measure-Object -Minimum).Minimum, 1)
            $maxLoad = [math]::Round(($measurements | Measure-Object -Maximum).Maximum, 1)
            
            Write-DiagnosticLog "CPU Load (5s average): $averageLoad% (min: $minLoad%, max: $maxLoad%)"
            
            # Интеллектуальные предупреждения на основе средней загрузки
            if ($averageLoad -gt 90) {
                Write-DiagnosticLog "CRITICAL: Very high CPU load detected!" -Level "ERROR"
                $Global:IssuesCount++
            } elseif ($averageLoad -gt 75) {
                Write-DiagnosticLog "WARNING: High CPU load detected" -Level "WARNING"
            } elseif ($averageLoad -lt 5) {
                Write-DiagnosticLog "System appears to be idle (very low CPU usage)" -Level "INFO"
            }
            
            # Расширенная информация в Extended режиме
            if ($Extended) {
                $variance = if ($measurements.Count -gt 1) {
                    $mean = ($measurements | Measure-Object -Average).Average
                    $squaredDiffs = $measurements | ForEach-Object { [math]::Pow($_ - $mean, 2) }
                    $variance = [math]::Round(($squaredDiffs | Measure-Object -Average).Average, 2)
                    $variance
                } else { 0 }
                
                Write-DiagnosticLog "CPU Load Statistics: Avg=$averageLoad%, Min=$minLoad%, Max=$maxLoad%, Variance=$variance"
                Write-DiagnosticLog "CPU Samples collected: $($measurements.Count)/$sampleCount successful"
            }
        } else {
            Write-DiagnosticLog "No valid CPU measurements collected" -Level "WARNING"
            
            # Fallback: одиночное измерение без усреднения
            try {
                $fallbackCpu = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                if ($fallbackCpu) {
                    # ✅ ИСПРАВЛЕНО: Прямое использование значения счетчика
                    $fallbackLoad = [math]::Round($fallbackCpu.CounterSamples[0].CookedValue, 1)
                    Write-DiagnosticLog "CPU Load (single sample): $fallbackLoad%" -Level "WARNING"
                }
            } catch {
                Write-DiagnosticLog "Fallback CPU measurement also failed" -Level "ERROR"
            }
        }
        
    } catch {
        Write-DiagnosticLog "CPU load measurement failed: $($_.Exception.Message)" -Level "ERROR"
        
        # Альтернативный метод через WMI (менее точный)
        try {
            Write-DiagnosticLog "Trying alternative WMI method..." -Level "DEBUG"
            $wmiCpu = Get-CimInstance Win32_PerfRawData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
            if ($wmiCpu) {
                Write-DiagnosticLog "CPU load measurement via WMI available (less accurate)" -Level "INFO"
            }
        } catch {
            Write-DiagnosticLog "All CPU load measurement methods failed" -Level "ERROR"
        }
    }
    
} catch {
    Write-DiagnosticLog "Ошибка получения информации о процессоре: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 4: ОПЕРАТИВНАЯ ПАМЯТЬ (ДЕТАЛЬНАЯ ИНФОРМАЦИЯ)
# ===================================================================================

Update-Progress "Memory Information" 20

try {
    $memory = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    if ($memory) {
        $totalMemory = 0
        $memorySlots = 0
        
        foreach ($dimm in $memory) {
            $capacity = [math]::Round($dimm.Capacity / 1GB, 2)
            $totalMemory += $capacity
            $memorySlots++
            
            $memInfo = @()
            $memInfo += "Slot=$($dimm.DeviceLocator)"
            $memInfo += "Size=${capacity}GB"
            
            if ($dimm.Speed) { $memInfo += "Speed=$($dimm.Speed)MHz" }
            if ($dimm.Manufacturer -and $dimm.Manufacturer.Trim() -ne "") { 
                $memInfo += "Manufacturer=$($dimm.Manufacturer.Trim())" 
            }
            if ($Extended -and $dimm.PartNumber -and $dimm.PartNumber.Trim() -ne "") { 
                $memInfo += "PartNumber=$($dimm.PartNumber.Trim())" 
            }
            
            # Тип памяти
            $memType = switch ($dimm.MemoryType) {
                20 { "DDR" }
                21 { "DDR2" }
                24 { "DDR3" }
                26 { "DDR4" }
                34 { "DDR5" }
                default { "Unknown($($dimm.MemoryType))" }
            }
            $memInfo += "Type=$memType"
            
            # Форм-фактор
            $formFactor = switch ($dimm.FormFactor) {
                8 { "DIMM" }
                12 { "SO-DIMM" }
                13 { "Micro-DIMM" }
                default { "Unknown($($dimm.FormFactor))" }
            }
            $memInfo += "FormFactor=$formFactor"
            
            Write-DiagnosticLog "Memory Module: $($memInfo -join '; ')"
        }
        
        Write-DiagnosticLog "Total Memory: ${totalMemory}GB in $memorySlots slots"
    }
    
    # Доступная память
    $availableMemory = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($availableMemory) {
        $freeMemory = [math]::Round($availableMemory.FreePhysicalMemory / 1MB, 2)
        $totalPhysical = [math]::Round($availableMemory.TotalVisibleMemorySize / 1MB, 2)
        $usagePercent = [math]::Round(($totalPhysical - $freeMemory) / $totalPhysical * 100, 1)
        
        Write-DiagnosticLog "Memory Usage: ${freeMemory}GB free of ${totalPhysical}GB (${usagePercent}% used)"
        
        # Предупреждения о высоком использовании памяти
        if ($usagePercent -gt 90) {
            Write-DiagnosticLog "CRITICAL: Memory usage very high!" -Level "ERROR"
            $Global:IssuesCount++
        } elseif ($usagePercent -gt 80) {
            Write-DiagnosticLog "WARNING: Memory usage high" -Level "WARNING"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о памяти: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 5: ВИДЕОКАРТЫ (ПОЛНАЯ ИНФОРМАЦИЯ)
# ===================================================================================

Update-Progress "Video Controllers" 25

try {
    $videoControllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    if ($videoControllers) {
        foreach ($gpu in $videoControllers) {
            $gpuInfo = @()
            
            if ($gpu.Name) { $gpuInfo += "Name=$($gpu.Name)" }
            
            # VRAM информация
            if ($gpu.AdapterRAM -and $gpu.AdapterRAM -gt 0) { 
                $vram = [math]::Round($gpu.AdapterRAM / 1GB, 2)
                $gpuInfo += "VRAM=${vram}GB" 
            }
            
            # Драйверы
            if ($gpu.DriverVersion) { $gpuInfo += "DriverVersion=$($gpu.DriverVersion)" }
            if ($gpu.DriverDate) { 
                $driverDate = $gpu.DriverDate.ToString('yyyy-MM-dd')
                $gpuInfo += "DriverDate=$driverDate" 
            }
            
            # Разрешение и частота
            if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {
                $resolution = "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
                $gpuInfo += "Resolution=$resolution"
            }
            if ($gpu.CurrentRefreshRate) { 
                $gpuInfo += "RefreshRate=$($gpu.CurrentRefreshRate)Hz" 
            }
            
            # Цветность
            if ($gpu.CurrentBitsPerPixel) { 
                $gpuInfo += "ColorDepth=$($gpu.CurrentBitsPerPixel)bit" 
            }
            
            Write-DiagnosticLog "GPU: $($gpuInfo -join '; ')"
            
            # Дополнительная информация о GPU
            if ($Extended) {
                $gpuDetails = Format-ComponentInfo $gpu @('DeviceID', 'PNPDeviceID', 'Status', 'Availability')
                if ($gpuDetails -ne "Нет данных") {
                    Write-DiagnosticLog "GPU Details: $gpuDetails"
                }
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о видеокартах: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 6: МОНИТОРЫ
# ===================================================================================

Update-Progress "Monitors" 30

try {
    # Попытка получить информацию через WMI
    $monitors = Get-CimInstance WmiMonitorID -Namespace root\wmi -ErrorAction SilentlyContinue
    if ($monitors) {
        foreach ($monitor in $monitors) {
            $monitorInfo = @()
            
            # Декодирование имени монитора
            if ($monitor.UserFriendlyName) {
                $nameBytes = $monitor.UserFriendlyName | Where-Object { $_ -ne 0 }
                if ($nameBytes) {
                    $name = [System.Text.Encoding]::ASCII.GetString($nameBytes)
                    $monitorInfo += "Name=$name"
                }
            }
            
            # Декодирование производителя
            if ($monitor.ManufacturerName) {
                $mfgBytes = $monitor.ManufacturerName | Where-Object { $_ -ne 0 }
                if ($mfgBytes) {
                    $manufacturer = [System.Text.Encoding]::ASCII.GetString($mfgBytes)
                    $monitorInfo += "Manufacturer=$manufacturer"
                }
            }
            
            # Серийный номер
            if ($Extended -and $monitor.SerialNumberID) {
                $serialBytes = $monitor.SerialNumberID | Where-Object { $_ -ne 0 }
                if ($serialBytes) {
                    $serial = [System.Text.Encoding]::ASCII.GetString($serialBytes)
                    $monitorInfo += "Serial=$serial"
                }
            }
            
            if ($monitorInfo.Count -gt 0) {
                Write-DiagnosticLog "Monitor: $($monitorInfo -join '; ')"
            }
        }
    } else {
        # Fallback через Win32_DesktopMonitor
        $desktopMonitors = Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue
        if ($desktopMonitors) {
            foreach ($monitor in $desktopMonitors) {
                $monitorInfo = Format-ComponentInfo $monitor @('Name', 'MonitorManufacturer', 'MonitorType', 'ScreenHeight', 'ScreenWidth')
                if ($monitorInfo -ne "Нет данных") {
                    Write-DiagnosticLog "Monitor: $monitorInfo"
                }
            }
        } else {
            Write-DiagnosticLog "Monitor information not available"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о мониторах: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 7: ПРИНТЕРЫ (ОПТИМИЗИРОВАННЫЙ)
# ===================================================================================

Update-Progress "Printers" 35

try {
    $printers = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
    if ($printers) {
        $printerCount = 0
        foreach ($printer in $printers) {
            $printerCount++
            $printerInfo = @()
            
            if ($printer.Name) { $printerInfo += "Name=$($printer.Name)" }
            if ($printer.DriverName) { $printerInfo += "Driver=$($printer.DriverName)" }
            if ($printer.PortName) { $printerInfo += "Port=$($printer.PortName)" }
            
            # Статус принтера
            $status = switch ($printer.PrinterStatus) {
                1 { "Other" }
                2 { "Unknown" }
                3 { "Idle" }
                4 { "Printing" }
                5 { "Warmup" }
                6 { "Stopped Printing" }
                7 { "Offline" }
                default { if ($printer.WorkOffline) { "Offline" } else { "Online" } }
            }
            $printerInfo += "Status=$status"
            
            if ($printer.Default) { $printerInfo += "Default=Yes" }
            if ($Extended) {
                if ($printer.Network) { $printerInfo += "Network=Yes" }
                if ($printer.Local) { $printerInfo += "Local=Yes" }
            }
            
            Write-DiagnosticLog "Printer: $($printerInfo -join '; ')"
        }
        Write-DiagnosticLog "Total Printers: $printerCount"
    } else {
        Write-DiagnosticLog "No printers found"
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о принтерах: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 8: ДИСКИ И ХРАНИЛИЩЕ (РАСШИРЕННАЯ ИНФОРМАЦИЯ)
# ===================================================================================

Update-Progress "Disk Information" 40

try {
    # Физические диски
    $physicalDisks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
    if ($physicalDisks) {
        foreach ($disk in $physicalDisks) {
            $diskInfo = @()
            
            if ($disk.Model) { 
                $model = $disk.Model.Trim()
                $diskInfo += "Model=$model" 
            }
            if ($disk.Size) { 
                $size = [math]::Round($disk.Size / 1GB, 2)
                $diskInfo += "Size=${size}GB" 
            }
            if ($disk.InterfaceType) { $diskInfo += "Interface=$($disk.InterfaceType)" }
            if ($disk.MediaType) { $diskInfo += "Type=$($disk.MediaType)" }
            if ($Extended -and $disk.SerialNumber) { 
                $serial = $disk.SerialNumber.Trim()
                if ($serial -ne "") {
                    $diskInfo += "Serial=$serial" 
                }
            }
            
            # Статус диска
            $status = switch ($disk.Status) {
                "OK" { "OK" }
                "Error" { "ERROR" }
                "Degraded" { "WARNING" }
                "Pred Fail" { "PRED_FAIL" }
                default { $disk.Status }
            }
            $diskInfo += "Status=$status"
            
            Write-DiagnosticLog "Physical Disk: $($diskInfo -join '; ')"
        }
    }
    
    # Логические диски с детальной информацией
    $logicalDisks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    if ($logicalDisks) {
        foreach ($drive in $logicalDisks) {
            $freeSpace = [math]::Round($drive.FreeSpace / 1GB, 2)
            $totalSpace = [math]::Round($drive.Size / 1GB, 2)
            $usedSpace = $totalSpace - $freeSpace
            $usedPercent = [math]::Round($usedSpace / $totalSpace * 100, 1)
            
            $status = if ($usedPercent -gt 90) { "CRITICAL" } 
                     elseif ($usedPercent -gt 80) { "WARNING" } 
                     else { "OK" }
            
            $driveInfo = @()
            $driveInfo += "Drive=$($drive.DeviceID)"
            $driveInfo += "Total=${totalSpace}GB"
            $driveInfo += "Free=${freeSpace}GB"
            $driveInfo += "Used=${usedPercent}%"
            $driveInfo += "Status=$status"
            
            if ($drive.FileSystem) { $driveInfo += "FileSystem=$($drive.FileSystem)" }
            if ($Extended -and $drive.VolumeName) { $driveInfo += "Label=$($drive.VolumeName)" }
            
            Write-DiagnosticLog "Logical Disk: $($driveInfo -join '; ')"
            
            # Предупреждения о заполненности диска
            if ($usedPercent -gt 90) {
                Write-DiagnosticLog "CRITICAL: Disk $($drive.DeviceID) almost full!" -Level "ERROR"
                $Global:IssuesCount++
            } elseif ($usedPercent -gt 80) {
                Write-DiagnosticLog "WARNING: Disk $($drive.DeviceID) getting full" -Level "WARNING"
            }
        }
    }
    
    # BitLocker статус (оптимизированный)
    try {
        $bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if ($bitlockerVolumes) {
            $protectedCount = ($bitlockerVolumes | Where-Object { $_.ProtectionStatus -eq "On" }).Count
            $totalCount = $bitlockerVolumes.Count
            
            Write-DiagnosticLog "BitLocker: $protectedCount/$totalCount volumes protected"
            
            if ($Extended) {
                # Детальная информация только в расширенном режиме
                foreach ($volume in $bitlockerVolumes) {
                    $volInfo = @()
                    $volInfo += "Mount=$($volume.MountPoint)"
                    $volInfo += "Status=$($volume.ProtectionStatus)"
                    if ($volume.EncryptionMethod) { $volInfo += "Method=$($volume.EncryptionMethod)" }
                    if ($volume.EncryptionPercentage) { $volInfo += "Progress=$($volume.EncryptionPercentage)%" }
                    
                    Write-DiagnosticLog "BitLocker Volume: $($volInfo -join '; ')"
                }
            } else {
                # Краткая сводка - только незащищенные
                $unprotected = $bitlockerVolumes | Where-Object { $_.ProtectionStatus -ne "On" }
                if ($unprotected) {
                    foreach ($vol in $unprotected) {
                        Write-DiagnosticLog "Unprotected volume: $($vol.MountPoint)" -Level "WARNING"
                    }
                }
            }
        }
    } catch {
        Write-DiagnosticLog "BitLocker information not available" -Level "DEBUG"
    }
} catch {
    Write-DiagnosticLog "Ошибка получения информации о дисках: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 8.1: SMART ДИАГНОСТИКА ДИСКОВ (КРИТИЧНО ДЛЯ ЗДОРОВЬЯ СИСТЕМЫ)
# ===================================================================================

Update-Progress "SMART Disk Health" 42

Invoke-SafeDiagnostic {
    Write-DiagnosticLog "Запуск SMART диагностики дисков..."
    
    # Получение SMART данных
    $smartData = Get-Disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    
    if ($smartData) {
        foreach ($disk in $smartData) {
            $healthInfo = @()
            
            if ($disk.DeviceId) { $healthInfo += "DeviceID=$($disk.DeviceId)" }
            if ($disk.Temperature -and $disk.Temperature -gt 0) { 
                $temp = $disk.Temperature
                $healthInfo += "Temperature=${temp}°C"
                
                # Предупреждения о температуре диска
                if ($temp -gt 60) {
                    Write-DiagnosticLog "Disk $($disk.DeviceId): HIGH TEMPERATURE ${temp}°C!" -Level "WARNING"
                    $Global:IssuesCount++
                } elseif ($temp -gt 50) {
                    Write-DiagnosticLog "Disk $($disk.DeviceId): WARM ${temp}°C" -Level "WARNING"
                }
            }
            
            if ($disk.PowerOnHours -and $disk.PowerOnHours -gt 0) { 
                $hours = $disk.PowerOnHours
                $days = [math]::Round($hours / 24, 1)
                $healthInfo += "PowerOnTime=${hours}h (${days} days)"
                
                # Предупреждение о большой наработке
                if ($hours -gt 43800) { # >5 лет
                    Write-DiagnosticLog "Disk $($disk.DeviceId): HIGH operating hours ($hours h)" -Level "WARNING"
                }
            }
            
            if ($disk.Wear -and $disk.Wear -gt 0) { 
                $healthInfo += "Wear=${disk.Wear}%"
                
                # Критическое предупреждение об износе
                if ($disk.Wear -gt 80) {
                    Write-DiagnosticLog "Disk $($disk.DeviceId): CRITICAL WEAR ${disk.Wear}%!" -Level "ERROR"
                    $Global:IssuesCount++
                } elseif ($disk.Wear -gt 60) {
                    Write-DiagnosticLog "Disk $($disk.DeviceId): HIGH WEAR ${disk.Wear}%" -Level "WARNING"
                }
            }
            
            if ($disk.ReadErrorsUncorrected -and $disk.ReadErrorsUncorrected -gt 0) { 
                $healthInfo += "ReadErrors=$($disk.ReadErrorsUncorrected)"
                
                # Ошибки чтения - критично!
                if ($disk.ReadErrorsUncorrected -gt 0) {
                    Write-DiagnosticLog "Disk $($disk.DeviceId): READ ERRORS DETECTED!" -Level "ERROR"
                    $Global:IssuesCount++
                }
            }
            
            if ($healthInfo.Count -gt 0) {
                Write-DiagnosticLog "SMART Health: $($healthInfo -join '; ')"
            }
        }
        
        Write-DiagnosticLog "SMART диагностика завершена для $($smartData.Count) дисков"
    } else {
        Write-DiagnosticLog "SMART data not available or unsupported" -Level "WARNING"
        
        # Fallback: базовая проверка дисков через Get-Disk
        $basicDisks = Get-Disk -ErrorAction SilentlyContinue
        if ($basicDisks) {
            foreach ($disk in $basicDisks) {
                $healthStatus = $disk.HealthStatus
                $operationalStatus = $disk.OperationalStatus
                
                if ($healthStatus -ne "Healthy" -or $operationalStatus -ne "Online") {
                    Write-DiagnosticLog "Disk $($disk.Number): Health=$healthStatus, Status=$operationalStatus" -Level "ERROR"
                    $Global:IssuesCount++
                } else {
                    Write-DiagnosticLog "Disk $($disk.Number): $healthStatus ($operationalStatus)"
                }
            }
        }
    }
} "SMART disk health monitoring"

# ===================================================================================
# МОДУЛЬ 9: СЕТЕВЫЕ АДАПТЕРЫ (ПОЛНАЯ ИНФОРМАЦИЯ)
# ===================================================================================

Update-Progress "Network Adapters" 45

try {
    # Активные сетевые адаптеры
    $networkAdapters = Get-CimInstance Win32_NetworkAdapter -Filter "NetEnabled=True" -ErrorAction SilentlyContinue
    if ($networkAdapters) {
        foreach ($adapter in $networkAdapters) {
            $adapterInfo = @()
            
            if ($adapter.Name) { $adapterInfo += "Name=$($adapter.Name)" }
            if ($adapter.MACAddress) { $adapterInfo += "MAC=$($adapter.MACAddress)" }
            
            # Скорость подключения
            if ($adapter.Speed -and $adapter.Speed -gt 0) { 
                if ($adapter.Speed -ge 1000000000) {
                    $speed = [math]::Round($adapter.Speed / 1000000000, 1)
                    $adapterInfo += "Speed=${speed}Gbps"
                } else {
                    $speed = [math]::Round($adapter.Speed / 1000000, 0)
                    $adapterInfo += "Speed=${speed}Mbps"
                }
            }
            
            # Тип адаптера
            $adapterType = switch ($adapter.AdapterType) {
                "Ethernet 802.3" { "Ethernet" }
                "Wireless" { "WiFi" }
                "Token Ring" { "TokenRing" }
                default { $adapter.AdapterType }
            }
            if ($adapterType) { $adapterInfo += "Type=$adapterType" }
            
            # Статус подключения
            $netStatus = switch ($adapter.NetConnectionStatus) {
                0 { "Disconnected" }
                1 { "Connecting" }
                2 { "Connected" }
                3 { "Disconnecting" }
                4 { "Hardware not present" }
                5 { "Hardware disabled" }
                6 { "Hardware malfunction" }
                7 { "Media disconnected" }
                8 { "Authenticating" }
                9 { "Authentication succeeded" }
                10 { "Authentication failed" }
                11 { "Invalid address" }
                12 { "Credentials required" }
                default { "Unknown($($adapter.NetConnectionStatus))" }
            }
            $adapterInfo += "Status=$netStatus"
            
            Write-DiagnosticLog "Network Adapter: $($adapterInfo -join '; ')"
        }
    }
    
    # IP конфигурация
    $ipConfigs = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue
    if ($ipConfigs) {
        foreach ($config in $ipConfigs) {
            $netInfo = @()
            
            if ($config.Description) { 
                $description = $config.Description
                if ($description.Length -gt 50) {
                    $description = $description.Substring(0, 47) + "..."
                }
                $netInfo += "Adapter=$description" 
            }
            
            if ($config.IPAddress) { 
                $ipAddresses = $config.IPAddress | Where-Object { $_ -notlike "*:*" } # Исключаем IPv6
                if ($ipAddresses) {
                    $netInfo += "IP=$($ipAddresses -join ', ')" 
                }
            }
            
            if ($Extended -and $config.IPSubnet) { 
                $subnets = $config.IPSubnet | Where-Object { $_ -notlike "*:*" } # Исключаем IPv6
                if ($subnets) {
                    $netInfo += "Subnet=$($subnets -join ', ')" 
                }
            }
            
            if ($config.DefaultIPGateway) { 
                $gateways = $config.DefaultIPGateway | Where-Object { $_ -notlike "*:*" } # Исключаем IPv6
                if ($gateways) {
                    $netInfo += "Gateway=$($gateways -join ', ')" 
                }
            }
            
            if ($Extended -and $config.DNSServerSearchOrder) { 
                $dnsServers = $config.DNSServerSearchOrder | Where-Object { $_ -notlike "*:*" } # Исключаем IPv6
                if ($dnsServers) {
                    $netInfo += "DNS=$($dnsServers -join ', ')" 
                }
            }
            
            if ($config.DHCPEnabled) { $netInfo += "DHCP=Enabled" }
            
            if ($netInfo.Count -gt 0) {
                Write-DiagnosticLog "IP Config: $($netInfo -join '; ')"
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения сетевой информации: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 10: ЯЗЫКИ И РАСКЛАДКИ
# ===================================================================================

Update-Progress "Languages & Keyboards" 50

try {
    # Установленные языковые пакеты
    $installedLanguages = Get-WinUserLanguageList -ErrorAction SilentlyContinue
    if ($installedLanguages) {
        $languageCount = $installedLanguages.Count
        Write-DiagnosticLog "Installed Languages: $languageCount languages configured"
        
        foreach ($lang in $installedLanguages) {
            $langInfo = @()
            $langInfo += "Tag=$($lang.LanguageTag)"
            $langInfo += "Name=$($lang.LocalizedName)"
            
            if ($Extended -and $lang.InputMethodTips) { 
                $inputMethods = $lang.InputMethodTips.Count
                $langInfo += "InputMethods=$inputMethods" 
            }
            
            # Статус автокоррекции и предиктивного ввода
            $langInfo += "Autonym=$($lang.Autonym)"
            
            Write-DiagnosticLog "Language: $($langInfo -join '; ')"
        }
    }
    
    # Системная локаль
    $systemLocale = Get-WinSystemLocale -ErrorAction SilentlyContinue
    if ($systemLocale) {
        Write-DiagnosticLog "System Locale: $($systemLocale.Name) ($($systemLocale.DisplayName))"
    }
    
    # Пользовательская локаль
    try {
        $userLocale = Get-Culture
        if ($userLocale) {
            Write-DiagnosticLog "User Locale: $($userLocale.Name) ($($userLocale.DisplayName))"
        }
    } catch {
        Write-DiagnosticLog "User locale information not available" -Level "DEBUG"
    }
    
    # Раскладки клавиатуры
    if ($Extended) {
        $keyboards = Get-CimInstance Win32_Keyboard -ErrorAction SilentlyContinue
        if ($keyboards) {
            foreach ($kb in $keyboards) {
                $kbInfo = @()
                if ($kb.Name) { $kbInfo += "Name=$($kb.Name)" }
                if ($kb.Layout) { $kbInfo += "Layout=$($kb.Layout)" }
                if ($kb.Description) { $kbInfo += "Description=$($kb.Description)" }
                
                if ($kbInfo.Count -gt 0) {
                    Write-DiagnosticLog "Keyboard: $($kbInfo -join '; ')"
                }
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка получения языковой информации: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 11: ТЕМПЕРАТУРНЫЙ МОНИТОРИНГ (ПРОВЕРЕННАЯ МЕТОДИКА v5.5)
# ===================================================================================

Update-Progress "Temperature Monitoring" 55

Invoke-SafeDiagnostic { 
    Get-TemperatureInfo 
} "Temperature monitoring"

# ===================================================================================
# МОДУЛЬ 12: СОБЫТИЯ СИСТЕМЫ
# ===================================================================================

Update-Progress "Event Logs" 60

try {
    # Критические события за последние 24 часа
    $systemEvents = Get-WinEvent -FilterHashtable @{
        LogName='System'; 
        Level=1,2; 
        StartTime=(Get-Date).AddDays(-1)
    } -MaxEvents 10 -ErrorAction SilentlyContinue
    
    if ($systemEvents) {
        Write-DiagnosticLog "Found $($systemEvents.Count) critical system events (last 24h)"
        
        foreach ($event in $systemEvents) {
            $eventMsg = $event.Message -replace "`r`n", " " -replace "`n", " "
            if ($eventMsg.Length -gt 150) {
                $eventMsg = $eventMsg.Substring(0, 150) + "..."
            }
            
            $levelText = switch ($event.Level) {
                1 { "CRITICAL" }
                2 { "ERROR" }
                3 { "WARNING" }
                4 { "INFO" }
                default { "LEVEL$($event.Level)" }
            }
            
            $timeStamp = $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
            Write-DiagnosticLog "[$timeStamp] $levelText ID:$($event.Id) - $eventMsg" -Level "WARNING"
        }
        
        if ($systemEvents.Count -gt 0) {
            $Global:IssuesCount++
        }
    } else {
        Write-DiagnosticLog "No critical system events found in last 24 hours"
    }
    
    # Последние ошибки приложений
    if ($Extended) {
        try {
            $appEvents = Get-WinEvent -FilterHashtable @{
                LogName='Application'; 
                Level=1,2; 
                StartTime=(Get-Date).AddHours(-6)
            } -MaxEvents 5 -ErrorAction SilentlyContinue
            
            if ($appEvents) {
                Write-DiagnosticLog "Found $($appEvents.Count) critical application events (last 6h)"
                foreach ($event in $appEvents) {
                    $timeStamp = $event.TimeCreated.ToString('HH:mm:ss')
                    Write-DiagnosticLog "[$timeStamp] APP ERROR ID:$($event.Id) Source:$($event.ProviderName)" -Level "DEBUG"
                }
            }
        } catch {
            Write-DiagnosticLog "Application event log analysis skipped" -Level "DEBUG"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка анализа событий: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 13: СЕТЕВОЕ ПОДКЛЮЧЕНИЕ
# ===================================================================================

Update-Progress "Network Connectivity" 65

try {
    # Тест интернет-подключения
    $internetTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($internetTest) {
        Write-DiagnosticLog "Network: Internet access confirmed (DNS to 8.8.8.8:53)"
        
        # Дополнительный тест до популярного сайта
        if ($Extended) {
            try {
                $webTest = Test-NetConnection -ComputerName "google.com" -Port 80 -InformationLevel Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                if ($webTest) {
                    Write-DiagnosticLog "Network: Web access confirmed (HTTP to google.com:80)"
                }
            } catch {
                Write-DiagnosticLog "Web connectivity test failed" -Level "DEBUG"
            }
        }
    } else {
        Write-DiagnosticLog "Network: Internet access failed" -Level "WARNING"
        $Global:IssuesCount++
        
        # Тест локального шлюза
        try {
            $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object { $_.NextHop -ne "0.0.0.0" } | Select-Object -First 1).NextHop
            if ($gateway) {
                $gatewayTest = Test-NetConnection -ComputerName $gateway -InformationLevel Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                if ($gatewayTest) {
                    Write-DiagnosticLog "Network: Local gateway $gateway reachable"
                } else {
                    Write-DiagnosticLog "Network: Local gateway $gateway unreachable" -Level "ERROR"
                }
            }
        } catch {
            Write-DiagnosticLog "Gateway connectivity test failed" -Level "DEBUG"
        }
    }
    
    # DNS тест
    try {
        $dnsTest = Resolve-DnsName -Name "google.com" -Type A -ErrorAction SilentlyContinue
        if ($dnsTest) {
            Write-DiagnosticLog "Network: DNS resolution working"
        } else {
            Write-DiagnosticLog "Network: DNS resolution failed" -Level "WARNING"
        }
    } catch {
        Write-DiagnosticLog "DNS test failed" -Level "DEBUG"
    }
} catch {
    Write-DiagnosticLog "Network connectivity test failed: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 14: СЛУЖБЫ
# ===================================================================================

Update-Progress "Services" 70

try {
    $services = Get-Service -ErrorAction SilentlyContinue
    if ($services) {
        $runningServices = ($services | Where-Object Status -eq 'Running').Count
        $stoppedServices = ($services | Where-Object Status -eq 'Stopped').Count
        $totalServices = $services.Count
        
        Write-DiagnosticLog "Services Status: $runningServices running, $stoppedServices stopped of $totalServices total"
        
        # Проверка критических служб Windows
        $criticalServices = @{
            'Winmgmt' = 'Windows Management Instrumentation'
            'EventLog' = 'Windows Event Log'
            'Dnscache' = 'DNS Client'
            'RpcSs' = 'Remote Procedure Call (RPC)'
            'LanmanServer' = 'Server'
            'LanmanWorkstation' = 'Workstation'
            'Themes' = 'Themes'
            'AudioSrv' = 'Windows Audio'
            'Spooler' = 'Print Spooler'
        }
        
        foreach ($svcName in $criticalServices.Keys) {
            $service = $services | Where-Object Name -eq $svcName
            if ($service) {
                $status = $service.Status
                $description = $criticalServices[$svcName]
                
                if ($status -eq 'Running') {
                    Write-DiagnosticLog "Service $($svcName.PadRight(20)): $status ($description)"
                } else {
                    Write-DiagnosticLog "Service $($svcName.PadRight(20)): $status ($description)" -Level "WARNING"
                    $Global:IssuesCount++
                }
            } else {
                Write-DiagnosticLog "Service $($svcName.PadRight(20)): NOT FOUND" -Level "ERROR"
            }
        }
        
        # Проверка служб безопасности
        if ($Extended) {
            $securityServices = @('MpsSvc', 'WinDefend', 'wscsvc')
            foreach ($svcName in $securityServices) {
                $service = $services | Where-Object Name -eq $svcName
                if ($service -and $service.Status -eq 'Running') {
                    Write-DiagnosticLog "Security Service $svcName`: Running"
                }
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка анализа служб: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 15: АВТОЗАГРУЗКА
# ===================================================================================

Update-Progress "Startup Items" 75

try {
    $startupItems = @()
    
    # Реестр для всех пользователей
    $runKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    
    foreach ($key in $runKeys) {
        try {
            if (Test-Path $key) {
                $items = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
                if ($items) {
                    $keyName = Split-Path $key -Leaf
                    $items.PSObject.Properties | Where-Object Name -notlike "PS*" | ForEach-Object {
                        $itemPath = $_.Value
                        if ($itemPath.Length -gt 80) {
                            $itemPath = $itemPath.Substring(0, 77) + "..."
                        }
                        $startupItems += "[$keyName] $($_.Name) = $itemPath"
                    }
                }
            }
        } catch {
            Write-DiagnosticLog "Cannot access registry key: $key" -Level "DEBUG"
        }
    }
    
    # Startup папки
    $startupFolders = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    
    foreach ($folder in $startupFolders) {
        try {
            if (Test-Path $folder) {
                $items = Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    $startupItems += "[Startup Folder] $($item.Name)"
                }
            }
        } catch {
            Write-DiagnosticLog "Cannot access startup folder: $folder" -Level "DEBUG"
        }
    }
    
    Write-DiagnosticLog "Startup items found: $($startupItems.Count)"
    
    # Показываем первые 10 элементов автозагрузки
    $itemsToShow = if ($Extended) { [Math]::Min($startupItems.Count, 20) } else { [Math]::Min($startupItems.Count, 10) }
    for ($i = 0; $i -lt $itemsToShow; $i++) {
        Write-DiagnosticLog "Startup: $($startupItems[$i])"
    }
    
    if ($startupItems.Count -gt $itemsToShow) {
        $remaining = $startupItems.Count - $itemsToShow
        Write-DiagnosticLog "... and $remaining more startup items (use msconfig to view all)"
    }
    
    # Предупреждение при большом количестве элементов автозагрузки
    if ($startupItems.Count -gt 15) {
        Write-DiagnosticLog "High startup item count may slow boot time" -Level "WARNING"
    }
} catch {
    Write-DiagnosticLog "Ошибка анализа автозагрузки: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 16: ЛИЦЕНЗИРОВАНИЕ WINDOWS
# ===================================================================================

Update-Progress "Windows License" 80

try {
    $license = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey <> null" -ErrorAction SilentlyContinue
    if ($license) {
        $licenseStatus = switch ($license.LicenseStatus) {
            0 { "Unlicensed" }
            1 { "Licensed" }
            2 { "OOBGrace" }
            3 { "OOTGrace" }
            4 { "NonGenuineGrace" }
            5 { "Notification" }
            6 { "ExtendedGrace" }
            default { "Unknown($($license.LicenseStatus))" }
        }
        
        Write-DiagnosticLog "Windows License Status: $licenseStatus"
        
        if ($license.Name) {
            Write-DiagnosticLog "Windows Edition: $($license.Name)"
        }
        
        if ($Extended -and $license.PartialProductKey) {
            Write-DiagnosticLog "Product Key (last 5): *****-*****-*****-*****-$($license.PartialProductKey)"
        }
        
        if ($license.LicenseStatus -ne 1) {
            Write-DiagnosticLog "Windows license issue detected" -Level "WARNING"
            $Global:IssuesCount++
        }
    } else {
        Write-DiagnosticLog "Windows license information not available" -Level "WARNING"
    }
    
    # Дополнительная проверка активации
    if ($Extended) {
        try {
            $activationStatus = & cscript //nologo "$env:windir\system32\slmgr.vbs" /xpr 2>$null
            if ($activationStatus -and $activationStatus -match "permanently activated") {
                Write-DiagnosticLog "Activation Status: Permanently activated"
            } elseif ($activationStatus) {
                Write-DiagnosticLog "Activation Status: $activationStatus" -Level "WARNING"
            }
        } catch {
            Write-DiagnosticLog "Could not check activation status" -Level "DEBUG"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка проверки лицензии: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 17: СИСТЕМНЫЕ ПРОЦЕССЫ
# ===================================================================================

Update-Progress "System Processes" 85

try {
    $processes = Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending
    if ($processes) {
        $totalProcesses = $processes.Count
        $totalWorkingSet = ($processes | Measure-Object WorkingSet -Sum).Sum
        $totalWorkingSetMB = [math]::Round($totalWorkingSet / 1MB, 1)
        
        Write-DiagnosticLog "Total processes: $totalProcesses (using ${totalWorkingSetMB}MB RAM)"
        
        # Топ 10 процессов по CPU
        $topCpuProcesses = $processes | Where-Object { $_.CPU -gt 0 } | Select-Object -First 10
        if ($topCpuProcesses) {
            Write-DiagnosticLog "Top CPU consuming processes:"
            foreach ($proc in $topCpuProcesses) {
                $cpu = [math]::Round($proc.CPU, 1)
                $memory = [math]::Round($proc.WorkingSet / 1MB, 1)
                $handles = $proc.Handles
                
                $procInfo = "$($proc.ProcessName.PadRight(25)) PID:$($proc.Id.ToString().PadLeft(6)) CPU:${cpu}s RAM:${memory}MB Handles:$handles"
                Write-DiagnosticLog "Process: $procInfo"
            }
        }
        
        # Топ 5 процессов по памяти
        if ($Extended) {
            $topMemoryProcesses = $processes | Sort-Object WorkingSet -Descending | Select-Object -First 5
            if ($topMemoryProcesses) {
                Write-DiagnosticLog "Top memory consuming processes:"
                foreach ($proc in $topMemoryProcesses) {
                    $memory = [math]::Round($proc.WorkingSet / 1MB, 1)
                    Write-DiagnosticLog "Memory: $($proc.ProcessName.PadRight(25)) ${memory}MB"
                }
            }
        }
        
        # Подсчет процессов по имени
        $processGroups = $processes | Group-Object ProcessName | Sort-Object Count -Descending | Select-Object -First 5
        foreach ($group in $processGroups) {
            if ($group.Count -gt 1) {
                Write-DiagnosticLog "Multiple instances: $($group.Name) ($($group.Count) instances)"
            }
        }
        
        # Расширенные счетчики производительности
        if ($Extended) {
            try {
                Write-DiagnosticLog "Collecting extended performance counters..."
                
                # Диски
                $diskCounters = Get-Counter @(
                    '\PhysicalDisk(_Total)\% Idle Time',
                    '\PhysicalDisk(_Total)\Avg. Disk sec/Read',
                    '\PhysicalDisk(_Total)\Avg. Disk sec/Write'
                ) -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                
                if ($diskCounters) {
                    foreach ($counter in $diskCounters.CounterSamples) {
                        $counterName = $counter.Path.Split('\')[-1]
                        $value = [math]::Round($counter.CookedValue, 3)
                        
                        # Анализ производительности дисков
                        if ($counterName -like "*Idle Time*" -and $value -lt 80) {
                            Write-DiagnosticLog "Disk Performance: $counterName = $value% (HIGH LOAD!)" -Level "WARNING"
                        } elseif ($counterName -like "*sec/Read*" -and $value -gt 0.1) {
                            Write-DiagnosticLog "Disk Performance: $counterName = ${value}s (SLOW!)" -Level "WARNING"  
                        } elseif ($counterName -like "*sec/Write*" -and $value -gt 0.1) {
                            Write-DiagnosticLog "Disk Performance: $counterName = ${value}s (SLOW!)" -Level "WARNING"
                        } else {
                            Write-DiagnosticLog "Disk Performance: $counterName = $value"
                        }
                    }
                }
                
                # Память
                $memoryCounters = Get-Counter '\Memory\% Committed Bytes In Use' -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                if ($memoryCounters) {
                    $memUsage = [math]::Round($memoryCounters.CounterSamples[0].CookedValue, 1)
                    if ($memUsage -gt 90) {
                        Write-DiagnosticLog "Memory Usage: ${memUsage}% (CRITICAL!)" -Level "ERROR"
                        $Global:IssuesCount++
                    } elseif ($memUsage -gt 80) {
                        Write-DiagnosticLog "Memory Usage: ${memUsage}% (HIGH!)" -Level "WARNING"
                    } else {
                        Write-DiagnosticLog "Memory Usage: ${memUsage}%"
                    }
                }
            } catch {
                Write-DiagnosticLog "Extended performance counters failed" -Level "DEBUG"
            }
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка анализа процессов: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 18: ПРОВЕРКА СИСТЕМНЫХ ФАЙЛОВ (РАСШИРЕННАЯ)
# ===================================================================================

Update-Progress "System File Check" 90

try {
    Write-DiagnosticLog "Running comprehensive system integrity check..."
    
    # SFC быстрая проверка (без исправления) - ТОЛЬКО в Extended режиме
    if ($Extended) {
        try {
            Write-DiagnosticLog "Starting SFC verification..."
            $sfcOutput = & sfc /verifyonly 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-DiagnosticLog "SFC: No integrity violations found"
            } else {
                Write-DiagnosticLog "SFC: System file violations detected (Exit Code: $LASTEXITCODE)" -Level "WARNING"
                $Global:IssuesCount++
                
                # Предложение полного сканирования
                Write-DiagnosticLog "Recommendation: Run 'sfc /scannow' to repair files" -Level "WARNING"
            }
        } catch {
            Write-DiagnosticLog "SFC verification failed: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-DiagnosticLog "SFC verification skipped (use -Extended for full check)"
    }
    
    # DISM проверка
    try {
        $dism = & dism /online /cleanup-image /checkhealth 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DiagnosticLog "DISM: System image health check passed"
        } else {
            Write-DiagnosticLog "DISM: System image issues detected" -Level "WARNING"
            $Global:IssuesCount++
        }
    } catch {
        Write-DiagnosticLog "DISM health check failed" -Level "DEBUG"
    }
    
    # Проверка критических системных файлов
    $systemFiles = @(
        "$env:windir\System32\kernel32.dll",
        "$env:windir\System32\ntdll.dll",
        "$env:windir\System32\user32.dll",
        "$env:windir\System32\advapi32.dll"
    )
    
    $missingFiles = 0
    foreach ($file in $systemFiles) {
        if (-not (Test-Path $file)) {
            Write-DiagnosticLog "Critical system file missing: $file" -Level "ERROR"
            $missingFiles++
        }
    }
    
    if ($missingFiles -eq 0) {
        Write-DiagnosticLog "Critical system files: All present"
    } else {
        Write-DiagnosticLog "Missing $missingFiles critical system files" -Level "ERROR"
        $Global:IssuesCount++
    }
} catch {
    Write-DiagnosticLog "System file check failed: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# МОДУЛЬ 18.1: АНАЛИЗ ДАМПОВ ПАМЯТИ
# ===================================================================================

Update-Progress "Memory Dumps Analysis" 92

Invoke-SafeDiagnostic {
    Write-DiagnosticLog "Analyzing system crash dumps..."
    
    $dumpLocations = @(
        'C:\Windows\Minidump',
        'C:\Windows\MEMORY.DMP'
    )
    
    $totalDumps = 0
    $recentDumps = 0
    
    foreach ($location in $dumpLocations) {
        try {
            if (Test-Path $location) {
                if ((Get-Item $location).PSIsContainer) {
                    # Папка minidump
                    $dumps = Get-ChildItem $location -Filter "*.dmp" -ErrorAction SilentlyContinue
                    if ($dumps) {
                        $totalDumps += $dumps.Count
                        $recentDumps += ($dumps | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) }).Count
                        
                        Write-DiagnosticLog "Minidumps found: $($dumps.Count) total"
                        
                        # Показываем последние 3 дампа
                        $latestDumps = $dumps | Sort-Object LastWriteTime -Descending | Select-Object -First 3
                        foreach ($dump in $latestDumps) {
                            $dumpDate = $dump.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                            $dumpSize = [math]::Round($dump.Length / 1KB, 1)
                            Write-DiagnosticLog "Recent dump: $($dump.Name) (${dumpSize}KB) - $dumpDate"
                        }
                        
                        if ($recentDumps -gt 0) {
                            Write-DiagnosticLog "Recent crashes detected ($recentDumps in last 30 days)" -Level "WARNING"
                            $Global:IssuesCount++
                        }
                    } else {
                        Write-DiagnosticLog "No minidumps found in $location"
                    }
                } else {
                    # Файл MEMORY.DMP
                    $dumpFile = Get-Item $location -ErrorAction SilentlyContinue
                    if ($dumpFile) {
                        $dumpSize = [math]::Round($dumpFile.Length / 1MB, 1)
                        $dumpDate = $dumpFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                        Write-DiagnosticLog "Memory dump: MEMORY.DMP (${dumpSize}MB) - $dumpDate"
                        
                        if ($dumpFile.LastWriteTime -gt (Get-Date).AddDays(-30)) {
                            Write-DiagnosticLog "Recent system crash detected" -Level "WARNING"
                            $Global:IssuesCount++
                        }
                    } else {
                        Write-DiagnosticLog "No memory dump found at $location"
                    }
                }
            } else {
                Write-DiagnosticLog "Dump location not found: $location" -Level "DEBUG"
            }
        } catch {
            Write-DiagnosticLog "Cannot access $location`: $($_.Exception.Message)" -Level "DEBUG"
        }
    }
    
    if ($totalDumps -eq 0) {
        Write-DiagnosticLog "No crash dumps found - system appears stable"
    } else {
        Write-DiagnosticLog "Total crash dumps found: $totalDumps ($recentDumps recent)"
    }
} "Memory dump analysis"

# ===================================================================================
# МОДУЛЬ 19: ОБНОВЛЕНИЯ WINDOWS
# ===================================================================================

Update-Progress "Windows Updates" 95

try {
    # Последние установленные обновления
    $hotfixes = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 10
    if ($hotfixes) {
        # Фильтрация обновлений с валидными датами
        $validHotfixes = $hotfixes | Where-Object { 
            $_.InstalledOn -is [DateTime] -and $_.InstalledOn -ne $null 
        }

        $recentUpdates = $validHotfixes | Where-Object { $_.InstalledOn -gt (Get-Date).AddDays(-30) }
        Write-DiagnosticLog "Recent updates (last 30 days): $($recentUpdates.Count) of $($validHotfixes.Count) valid updates"
        
        # Вывод только обновлений с валидными датами
        $showCount = if ($Extended) { 10 } else { 5 }
        foreach ($hotfix in $validHotfixes | Select-Object -First $showCount) {
            $installDate = $hotfix.InstalledOn.ToString('MM/dd/yyyy')
            $description = if ($hotfix.Description) { 
                $hotfix.Description 
            } else { 
                "Update" 
            }
            
            Write-DiagnosticLog "Update: $($hotfix.HotFixID) ($description) installed $installDate"
        }
        
        # Проверка давности последнего обновления (только если есть валидные)
        if ($validHotfixes) {
            $lastUpdate = $validHotfixes | Select-Object -First 1
            $daysSinceUpdate = (Get-Date) - $lastUpdate.InstalledOn
            if ($daysSinceUpdate.Days -gt 60) {
                Write-DiagnosticLog "Last update was $($daysSinceUpdate.Days) days ago - consider checking for updates" -Level "WARNING"
            }
        }
    } else {
        Write-DiagnosticLog "No recent updates found or update history unavailable" -Level "WARNING"
    }
    
    # Проверка Windows Update сервиса
    $wuService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    if ($wuService) {
        Write-DiagnosticLog "Windows Update Service: $($wuService.Status)"
        if ($wuService.Status -ne 'Running' -and $wuService.StartType -ne 'Disabled') {
            Write-DiagnosticLog "Windows Update service not running" -Level "WARNING"
        }
    }
} catch {
    Write-DiagnosticLog "Ошибка проверки обновлений: $($_.Exception.Message)" -Level "ERROR"
}

# ===================================================================================
# МОДУЛЬ 20: ФИНАЛИЗАЦИЯ ОТЧЕТА И СВОДКА
# ===================================================================================

Update-Progress "Finalizing Report" 100

$Global:EndTime = Get-Date
$duration = $Global:EndTime - $Global:StartTime

# Сводка по системе
Write-DiagnosticLog ("=" * 50)
Write-DiagnosticLog "SYSTEM DIAGNOSTIC SUMMARY"
Write-DiagnosticLog ("=" * 50)

# Анализ статуса системы
$systemStatus = if ($Global:IssuesCount -eq 0) { 
    "EXCELLENT" 
} elseif ($Global:IssuesCount -le 2) { 
    "GOOD" 
} elseif ($Global:IssuesCount -le 5) { 
    "FAIR" 
} else { 
    "NEEDS ATTENTION" 
}

Write-DiagnosticLog "System Status: $systemStatus"
Write-DiagnosticLog "Issues Found: $Global:IssuesCount"
Write-DiagnosticLog "Execution Time: $([math]::Round($duration.TotalMinutes, 1)) minutes ($([math]::Round($duration.TotalSeconds, 0)) seconds)"
Write-DiagnosticLog "Modules Completed: $Global:TotalModules/22"
if ($Extended) {
    Write-DiagnosticLog "Extended Mode: ENABLED"
}

# Рекомендации на основе найденных проблем
if ($Global:IssuesCount -eq 0) {
    Write-DiagnosticLog "✅ System appears to be in excellent condition"
} elseif ($Global:IssuesCount -le 2) {
    Write-DiagnosticLog "⚠️ Minor issues detected - review warnings above"
} else {
    Write-DiagnosticLog "❌ Multiple issues detected - immediate attention recommended"
}

Write-DiagnosticLog ("=" * 50)

# ===================================================================================
# СОХРАНЕНИЕ ОТЧЕТА
# ===================================================================================

try {
    # Создаем выходную папку если не существует
    if (-not (Test-Path $OutputPath)) {
        try {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            Write-DiagnosticLog "Created output directory: $OutputPath" -Level "DEBUG"
        } catch {
            Write-DiagnosticLog "Failed to create output directory: $($_.Exception.Message)" -Level "ERROR"
            $OutputPath = "."  # Fallback to current directory
        }
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $extendedSuffix = if ($Extended) { "_Extended" } else { "" }
    $reportPath = Join-Path $OutputPath "SystemDiagnostic_v26$extendedSuffix`_$timestamp.txt"
    
    # Добавляем заголовок файла
    $fileHeader = @(
        "===============================================================================",
        "SYSTEM DIAGNOSTIC REPORT v26 - ENHANCED SMART & PERFORMANCE MONITORING",
        "===============================================================================",
        "Generated: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')",
        "Computer: $env:COMPUTERNAME",
        "User: $env:USERNAME",
        "Domain: $env:USERDOMAIN",
        "Script Version: 7.2 (Enhanced SMART & Performance Monitoring)",
        "Extended Mode: $(if ($Extended) { 'ENABLED' } else { 'DISABLED' })",
        "Execution Time: $([math]::Round($duration.TotalSeconds, 0)) seconds",
        "Issues Found: $Global:IssuesCount",
        "System Status: $systemStatus",
        "===============================================================================",
        ""
    )
    
    # Сохраняем отчет
    $fileHeader + $Global:LogEntries | Out-File -FilePath $reportPath -Encoding UTF8 -ErrorAction Stop
    
    $fileInfo = Get-Item $reportPath
    $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
    
    Write-DiagnosticLog "Report saved to: $reportPath" -Level "SUCCESS"
    Write-DiagnosticLog "Report size: $fileSizeKB KB"
    
    # Дополнительная информация для ExportOnly режима
    if ($ExportOnly) {
        Write-DiagnosticLog "ExportOnly mode: Report generation completed silently"
        Write-DiagnosticLog "Output directory: $OutputPath"
    }
    
    # RDP-friendly анализ размера
    if ($fileSizeKB -le 50) {
        Write-DiagnosticLog "✅ OPTIMAL: Perfect size for RDP copying!" -Level "SUCCESS"
    } elseif ($fileSizeKB -le 100) {
        Write-DiagnosticLog "✅ EXCELLENT: Great size for RDP copying!" -Level "SUCCESS"
    } elseif ($fileSizeKB -le 200) {
        Write-DiagnosticLog "⚠️ GOOD: Acceptable size for RDP copying" -Level "WARNING"
    } else {
        Write-DiagnosticLog "❌ LARGE: Consider optimization for RDP environments" -Level "WARNING"
    }
    
} catch {
    Write-DiagnosticLog "Ошибка сохранения отчета: $($_.Exception.Message)" -Level "ERROR"
    $Global:IssuesCount++
}

# ===================================================================================
# ЗАВЕРШЕНИЕ И ОТОБРАЖЕНИЕ РЕЗУЛЬТАТОВ
# ===================================================================================

if ($ExportOnly) {
    # Краткое сообщение о завершении для ExportOnly режима
    Write-Host "System Diagnostic v26 completed. Report saved to: $reportPath" -ForegroundColor Green
}

if (-not $ExportOnly) {
    Write-Progress -Activity "🔍 SYSTEM DIAGNOSTIC v26" -Completed
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Green
    Write-Host "🎉 SYSTEM DIAGNOSTIC v26 - ENHANCED SMART & PERFORMANCE MONITORING FINISHED!" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 РЕЗУЛЬТАТЫ ДИАГНОСТИКИ:" -ForegroundColor Cyan
    Write-Host "  ⏱️  Время выполнения: $([math]::Round($duration.TotalMinutes, 1)) минут" -ForegroundColor White
    Write-Host "  📋  Модули выполнены: $Global:TotalModules/22" -ForegroundColor White
    Write-Host "  🔍  Найдено проблем: $Global:IssuesCount" -ForegroundColor $(if ($Global:IssuesCount -eq 0) { "Green" } elseif ($Global:IssuesCount -le 2) { "Yellow" } else { "Red" })
    Write-Host "  📈  Статус системы: $systemStatus" -ForegroundColor $(if ($systemStatus -eq "EXCELLENT") { "Green" } elseif ($systemStatus -eq "GOOD") { "Yellow" } else { "Red" })
    if ($Extended) {
        Write-Host "  🔧  Расширенный режим: ВКЛЮЧЕН" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "📁 ФАЙЛ ОТЧЕТА:" -ForegroundColor Cyan
    Write-Host "  📄  Путь: $reportPath" -ForegroundColor White
    Write-Host "  📦  Размер: $fileSizeKB KB" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 НОВОЕ В v26:" -ForegroundColor Cyan
    Write-Host "  ✅  SMART диагностика дисков с анализом температуры и износа" -ForegroundColor Green
    Write-Host "  ✅  Анализ дампов памяти для выявления сбоев системы" -ForegroundColor Green
    Write-Host "  ✅  SFC проверка целостности системных файлов (только в -Extended)" -ForegroundColor Green
    Write-Host "  ✅  Расширенные счетчики производительности дисков и памяти" -ForegroundColor Green
    Write-Host "  ✅  Оптимизированные модули BitLocker и принтеров" -ForegroundColor Green
    Write-Host "  ✅  Интеллектуальные предупреждения о критических состояниях" -ForegroundColor Green
    Write-Host ""
    
    if ($Global:IssuesCount -eq 0) {
        Write-Host "🎊 ПОЗДРАВЛЯЕМ! Система в отличном состоянии!" -ForegroundColor Green
    } elseif ($Global:IssuesCount -le 2) {
        Write-Host "👍 Система в хорошем состоянии с незначительными замечаниями." -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Обнаружены проблемы, требующие внимания. Проверьте отчет." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Нажмите Enter для завершения..." -ForegroundColor Gray
    Read-Host
}