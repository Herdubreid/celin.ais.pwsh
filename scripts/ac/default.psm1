function init {
    $global:hint = "Account Query (enter 'go' to start, 'q' to quit)"
    $Global:ac = @{}
    # Get a base Grid Form
    $ac.mcuFrm = ConvertFrom-Celin.AIS.Ui.GridForm (getLayout base-grid)
    # Set Title and Color
    $ac.mcuFrm.title = "Business Unit"
    $ac.mcuFrm.color = "high"
    # Set the Header
    $ac.mcuFrm.header.format = "{0,12} {1,7} {2,-30} {3,-4} {4,-3} {5,-8} {6,-8} {7,12}"
    $ac.mcuFrm.header.data = @("BU#", "Company", "Description", "Type", "LOD", "From LOD", "To LOD", "No.Accounts")
    # Set the Body Format
    $ac.mcuFrm.body.format = "{0,12} {3,7} {4,-30} {1,-4} {2,-3} {7,-8} {8,-8} {9,12}"

    # Init Accounts
    $ac.f0901 = "f0901 -max no (co,aid,mcu,obj,sub,dl01,lda,pec,crcd) by[asc(obj,sub)]"
    $ac.fmt = { , @(("{0}.{1}.{2}" -f $_[2].trim(), $_[3], $_[4].trim()).trimEnd('.'), $_[10], $_[9], $_[5], $_[11], $_[12], $_[6], $_[7]) }
    # Get Msg Form
    $ac.msg = ConvertFrom-Celin.AIS.Ui.Prompt (getLayout error-msg)
    # Get a base Grid Form
    $ac.accFrm = ConvertFrom-Celin.AIS.Ui.GridForm (getLayout base-grid)
    # Set Title and Color
    $ac.accFrm.title = "Accounts"
    $ac.accFrm.color = "high"
    # Set Keys
    $ac.accFrm.statusbar.add("Esc - Back to BU's")
    $ac.accFrm.statusbar.add("To Excel", "Alt-X")
    # Set the Header
    $ac.accFrm.header.format = "{0,-16} {1, 17:N2} {2,3} {3,-30} {4,6} {5,4} {6,3} {7,3}"
    $ac.accFrm.header.data = @("Account", "Balance", "CUR", "Description", "Trx", "Accs", "LOD", "PEC")
    # Set the Body
    $ac.accFrm.body.format = "{0,-16} {1, 17:N2} {2,3} {3,-30} {4,6} {5,4} {6,3} {7,3}"

    # Get Helpers
    getScript ac-from-to-q
    getScript sum-ac
}

function go {
    try {
        # Fetch BU Master
        $ac.rs = Submit-Celin.AIS.Query "f0006 -max no (mcu,styl,ldm,co,dl01)"
        # Store the Grid
        $ac.mcus = $ac.rs.data.grid
        # Fetch the BU Account Stats
        $ac.rs = Submit-Celin.AIS.Query "f0901 [group(co,mcu) min(lda) max(lda) count(aid) asc(co,mcu)]"
        # Store the Grid
        $ac.g = $ac.rs.data.grid
        # Create a Joined Grid (using CO,MCU)
        $ac.j = $ac.mcus.join($ac.g, @("CO", "MCU"))
        # Display the Heading
        $ac.j.header
        # Use the Joined Detail
        $ac.mcuFrm.set($ac.j.detail)
        # Loop until Esc
        do {
            # Show Form
            $ac.mcu = Show-Celin.AIS.Ui.GridForm $ac.mcuFrm
            if ($ac.mcu) {
                $ac.lastR2 = @($ac.mcu.data.row[3], $null, $ac.mcu.data.row[0], "XXXX", "")
                $ac.mcuq = "mcu=$($ac.mcu.data.row[0].trim())"
                # Fetch the First Level
                $ac.lod = Submit-Celin.AIS.Query "$($ac.f0901) all($($ac.mcuq) lda=$($ac.mcu.data.row[7]) obj!blank)"
                # Sum the Level
                $ac.lodRows = sumAc $ac.lod.data.grid.detail $ac.lastR2
                $ac.rows = @($ac.lodRows | foreach-object $ac.fmt) 
                $ac.accFrm.set($ac.rows)
                # Set the Title
                $ac.accFrm.title = "$($ac.mcu.data.row[0]) $($ac.mcu.data.row[4])"
                # Show Form
                do {
                    # Loop until Esc
                    $ac.next = Show-Celin.AIS.Ui.GridForm $ac.accFrm
                    if ($ac.next) {
                        # Get the Original Row
                        $ac.r = $ac.lodRows[$ac.next.data.index]
                        # Find next Row (use last r2 as default)
                        $ac.r2 = $ac.lastR2
                        for ($ndx = $ac.next.data.index; $ndx -lt $ac.lodRows.length; $ndx++) {
                            if ($ac.r[3] -ne $ac.lodRows[$ndx][3] -or $ac.r[4] -ne $ac.lodRows[$ndx][4]) {
                                $ac.r2 = $ac.lodRows[$ndx]
                                $ac.lastR2 = $ac.r2
                                break
                            }
                        }
                        # Build the Query String
                        $fixed = "lda=$([int]$ac.r[6] + 1) mcu=$($ac.mcu.data.row[0].trim())"
                        if ($ac.r2) {
                            $ac.q = acFromToQ $fixed  $ac.r[3].trim() $ac.r[4].trim() $ac.r2[3].trim() $ac.r2[4].trim()
                        }
                        else {
                            $ac.q = acFromToQ $fixed $ac.r[3].trim() $ac.r[4].trim()
                        }
                        $rs = Submit-Celin.AIS.Query "$($ac.f0901) $($ac.q)"
                        if ($rs.data.grid.detail.count() -gt 0) {
                            $ac.lod = $rs
                            # Sum the Level
                            $ac.lodRows = sumAc $ac.lod.data.grid.detail $ac.lastR2
                            $ac.rows = @($ac.lodRows | foreach-object $ac.fmt) 
                            $ac.accFrm.set($ac.rows)
                            $ac.accFrm.title = "$($ac.mcu.data.row[0]) $($ac.mcu.data.row[4]) - $($ac.next.data.row[0]) $($ac.next.data.row[3])"
                        }
                        else {
                            $ac.msg.Message.Text = "No records returned!"
                            Show-Celin.AIS.Ui.Prompt $ac.msg | Out-Null
                        }
                    }
                } until (-not $ac.next)
            }
        } until (-not $ac.mcu)        
    }
    catch {
        Write-Host $_ -ForegroundColor Red
    }
}
