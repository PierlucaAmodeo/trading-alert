$TOKEN = $env:TOKEN
$CHAT_ID = $env:CHAT_ID

$symbol = "qqq.us"

# =========================
# PARAMETRI STRATEGIA
# =========================

$targetPerc = 4
$stopPerc = -1
$maxDays = 10

$STOOQ_APIKEY = $env:STOOQ_APIKEY

# =========================
# DOWNLOAD DATI STOOQ
# =========================

$url = "https://stooq.com/q/d/l/?s=$symbol&i=d&apikey=$STOOQ_APIKEY"

$tempFile = "$env:TEMP\qqq.csv"

$headers = @{
    "User-Agent" = "Mozilla/5.0"
}

Invoke-WebRequest `
    -Uri $url `
    -Headers $headers `
    -OutFile $tempFile

$data = Import-Csv $tempFile

Write-Host "Righe scaricate: $($data.Count)"

if ($data.Count -lt 210)
{
    Write-Host "Dati insufficienti."
    exit
}

# =========================
# PREZZI
# =========================

$oggiRow = $data[-1]
$ieriRow = $data[-2]

$oggi = [double]$oggiRow.Close
$ieri = [double]$ieriRow.Close

$oggiDate = $oggiRow.Date
$ieriDate = $ieriRow.Date

# =========================
# VARIAZIONE %
# =========================

$variazione = (($oggi - $ieri) / $ieri) * 100

# =========================
# MA200
# =========================

$closeList = @()

for ($i = $data.Count - 200; $i -lt $data.Count; $i++)
{
    $closeList += [double]$data[$i].Close
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
    $capitale = 20
}
elseif ($variazione -le -2.5)
{
    $capitale = 15
}
elseif ($variazione -le -1.5)
{
    $capitale = 10
}

# =========================
# DEBUG
# =========================

Write-Host ""
Write-Host "==============================="
Write-Host "QQQ STRATEGIA"
Write-Host "==============================="
Write-Host "Data oggi: $oggiDate"
Write-Host "Prezzo oggi: $oggi"
Write-Host "Prezzo ieri: $ieri"
Write-Host "Variazione: $([math]::Round($variazione,2))%"
Write-Host "MA200: $([math]::Round($ma200,2))"

if ($trendOK)
{
    Write-Host "Trend: BULLISH"
}
else
{
    Write-Host "Trend: BEARISH"
}

Write-Host "==============================="

# =========================
# SEGNALE
# =========================

if (($capitale -gt 0) -and $trendOK)
{
    $entry = [math]::Round($oggi,2)

    $target = [math]::Round(
        $entry * 1.04,
        2
    )

    $stop = [math]::Round(
        $entry * 0.99,
        2
    )

    $msg = @"
QQQ - SEGNALE ACQUISTO

Data:
$oggiDate

Ribasso:
$([math]::Round($variazione,2))%

Prezzo:
$entry

MA200:
$([math]::Round($ma200,2))

Capitale:
$capitale €

Take Profit:
$target

Stop Loss:
$stop

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
