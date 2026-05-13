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
# DOWNLOAD DATI
# =========================

$url = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&outputsize=full&apikey=$APIKEY"
$url = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&apikey=$APIKEY"

$data = Invoke-RestMethod -Uri $url

$series = $data.'Time Series (Daily)'


if (-not $series)
{
    Write-Host "Errore download dati."
    exit
}

# Date ordinate dalla più recente
$dates = $series.PSObject.Properties.Name | Sort-Object -Descending

# =========================
# PREZZI
# =========================

$oggiDate = $dates[0]
$ieriDate = $dates[1]

$oggi = [double]$series.$oggiDate.'4. close'
$ieri = [double]$series.$ieriDate.'4. close'

# =========================
# VARIAZIONE GIORNALIERA
# =========================

$variazione = (($oggi - $ieri) / $ieri) * 100

# =========================
# CALCOLO MA200
# =========================

$closeList = @()

for ($i = 0; $i -lt 200; $i++)
{
    $d = $dates[$i]
    $close = [double]$series.$d.'4. close'
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
Write-Host "Data: $oggiDate"
Write-Host "Close oggi: $oggi"
Write-Host "Close ieri: $ieri"
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

Data: $oggiDate

Ribasso giornaliero:
$([math]::Round($variazione,2))%

Prezzo:
$entry

MA200:
$([math]::Round($ma200,2))

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
