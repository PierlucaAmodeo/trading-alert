$APIKEY = $env:APIKEY
$TOKEN = $env:TOKEN
$CHAT_ID = $env:CHAT_ID

$symbol = "QQQ"

# =========================
# PARAMETRI STRATEGIA
# =========================

$targetPerc = 4
$stopPerc = -1
$maxDays = 10

# =========================
# PREZZO ATTUALE INTRADAY
# =========================

$intradayUrl = "https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=$symbol&interval=5min&apikey=$APIKEY"

$intradayData = Invoke-RestMethod -Uri $intradayUrl

$intradaySeries = $intradayData.'Time Series (5min)'

if (-not $intradaySeries)
{
    Write-Host "Errore dati intraday."
    exit
}

$intradayDates = $intradaySeries.PSObject.Properties.Name | Sort-Object -Descending

$latestBar = $intradayDates[0]

$oggi = [double]$intradaySeries.$latestBar.'4. close'

# =========================
# DATI DAILY
# =========================

$dailyUrl = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&outputsize=full&apikey=$APIKEY"

$dailyData = Invoke-RestMethod -Uri $dailyUrl

$dailySeries = $dailyData.'Time Series (Daily)'

if (-not $dailySeries)
{
    Write-Host "Errore dati daily."
    exit
}

$dailyDates = $dailySeries.PSObject.Properties.Name | Sort-Object -Descending

# =========================
# CHIUSURA IERI
# =========================

$ieriDate = $dailyDates[1]

$ieri = [double]$dailySeries.$ieriDate.'4. close'

# =========================
# VARIAZIONE %
# =========================

$variazione = (($oggi - $ieri) / $ieri) * 100

# =========================
# CALCOLO MA200
# =========================

$closeList = @()

for ($i = 0; $i -lt 200; $i++)
{
    $d = $dailyDates[$i]

    $close = [double]$dailySeries.$d.'4. close'

    $closeList += $close
}

$ma200 = ($closeList | Measure-Object -Average).Average

# =========================
# TREND FILTER
# =========================

$trendOK = $oggi -gt $ma200

# =========================
# CAPITALE DINAMICO
# =========================

$capitale = 0
$variazione = 2.8

if ($variazione -le -3.5)
{
    $capitale = 20000
}
elseif ($variazione -le -2.5)
{
    $capitale = 15000
}
elseif ($variazione -le -1.5)
{
    $capitale = 10000
}

# =========================
# OUTPUT DEBUG
# =========================

Write-Host ""
Write-Host "==============================="
Write-Host "QQQ STRATEGIA"
Write-Host "==============================="
Write-Host "Ultima barra intraday: $latestBar"
Write-Host "Prezzo attuale: $oggi"
Write-Host "Chiusura ieri ($ieriDate): $ieri"
Write-Host "Variazione: $([math]::Round($variazione,2))%"
Write-Host "MA200: $([math]::Round($ma200,2))"

if ($trendOK)
{
    Write-Host "Trend: BULLISH (prezzo > MA200)"
}
else
{
    Write-Host "Trend: BEARISH (prezzo <= MA200)"
}

Write-Host "==============================="

# =========================
# SEGNALE ACQUISTO
# =========================

if (($capitale -gt 0) -and $trendOK)
{
    $entry = [math]::Round($oggi,2)

    $target = [math]::Round(
        $entry * (1 + ($targetPerc / 100)),
        2
    )

    $stop = [math]::Round(
        $entry * (1 + ($stopPerc / 100)),
        2
    )

    $msg = @"
QQQ - SEGNALE ACQUISTO

Ora controllo:
$latestBar

Ribasso vs chiusura ieri:
$([math]::Round($variazione,2))%

Prezzo attuale:
$entry

MA200:
$([math]::Round($ma200,2))

Trend:
BULLISH

Capitale da investire:
$capitale €

Take Profit:
$target (+4%)

Stop Loss:
$stop (-1%)

Durata massima:
$maxDays giorni
"@

    $telegramUrl = "https://api.telegram.org/bot$TOKEN/sendMessage"

    Invoke-RestMethod `
        -Uri $telegramUrl `
        -Method Post `
        -Body @{
            chat_id = $CHAT_ID
            text = $msg
        }

    Write-Host "ALERT INVIATO"
}
else
{
    Write-Host "NESSUN SEGNALE"
}
