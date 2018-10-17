###################################
#
# ps_AD_GetUserLastPwdChange.ps1
#
# Retrieves the last date a user changed their password from Active Directory
# Requires RSAT with permission to access Active Directory data
#
# MVogwell 17/10/18 - Version 1
#
###################################

<#

.SYNOPSIS
This Powershell script returns a csv file containing information about the last time a user's password was reset from Active Directory.

.DESCRIPTION
The script can either check all Active Directory users, all users under a specific Organizational Unit or specific users listed in a text file and will export the results to a CSV file. See help ps_AD_GetUserLastPwdChange.ps1 -Detailed for more information.

To return data for a specific list of users add a list of Usernames or Display Names to <script-root-path>\GetUserLastPwdChange_UserList.txt (or you can specific a custom location for this file by using the UserlistTextFilePath paramater )

.PARAMETER UserlistTextFilePath
    The location of a text file containing a list of users. The default location is the same folder as the script in a file called GetUserLastPwdChange_UserList.txt

.PARAMETER ScanAllUsers
    Boolean option to scan all users in the Active Directory. Must be used if LDAPSearchBase parameter is used

.PARAMETER ExportFilePath
    The location of where the export file should be saved to. Default is the same folder as the script in a file called GetUserLastPwdChange_Results.csv

.PARAMETER LDAPSearchBase
    Use in conjunction with ScanAllUsers. This requires an LDAP path and is used to limit the root Organizational Unit from where to search for users.

.EXAMPLE

Without using any parameters the default UserlistTextFilePath (<script-root-path>\GetUserLastPwdChange_UserList.txt) and ExportFilePath (<script-root-path>\GetUserLastPwdChange_Results.csv) parameters and search for users listed in the UserlistTextFilePath text file
./ps_AD_GetUserLastPwdChange.ps1

.EXAMPLE

Specify the UserlistTextFilePath and ExportFilePath to use files in locations other than the defaults
./ps_AD_GetUserLastPwdChange.ps1 -UserlistTextFilePath c:\temp\MyCustomUserListLocation.txt -ExportFilePath c:\temp\MyCustomUserExport.csv

.EXAMPLE

Return details for all users in the Active Directory by using the ScanAllUsers paramater
./ps_AD_GetUserLastPwdChange.ps1 -ScanAllUsers:$True

.EXAMPLE

... And limit the users returned by specifying a Search Base LDAP Path
./ps_AD_GetUserLastPwdChange.ps1 -ScanAllUsers:$True -LDAPSearchBase "CN=Users,DC=contoso,DC=com"


.NOTES
MVogwell - October 2017

.LINK
https://github.com/mvogwell

#>

[CmdLetBinding()]
param (
    [Parameter(Mandatory=$false)][string]$UserlistTextFilePath = $PSScriptRoot + "\GetUserLastPwdChange_UserList.txt",
    [Parameter(Mandatory=$false)][boolean]$ScanAllUsers = $False,
    [Parameter(Mandatory=$false)][string]$ExportFilePath = $PSScriptRoot + "\GetUserLastPwdChange_Results.csv",
    [Parameter(Mandatory=$false)][string]$LDAPSearchBase = ""
)

Function CreateResultsFile {
    Param (
        [Parameter(Mandatory=$true)][string]$OutputFile,
        [Parameter(Mandatory=$true)][ref]$ErrorMsg,
        [Parameter(Mandatory=$true)][bool]$AllowAppend
    )

    ##############################
    #
    # Function to create a results file for a given path. Returns True if successful and False if it fails
    # MVogwell - 04-06-18 - v1.1
    #
    # Change log:
    #	v1: Working function
    #	v1.1: Changed params to mandatory. Added method to Append log file rather than create overwrite
    #
    ##############################

    $ErrorActionPreference = "Stop"
    $arrAnswers = @("yes","y","no","n")

    $bResultsFileCreationSuccess = $True

    if ($OutputFile.length -eq 0) {
        $bResultsFileCreationSuccess = $False
    }
    Else {
        if (Test-Path($OutputFile)) {	# Run only if the file already exists to check if it should be overwritten
            If ($AllowAppend -eq $False) {
                write-verbose "File already exists. Checking with user if it should be replaced`n"

                write-host "The results output file $OutputFile already exists!" -fore yellow

                Do {
                    write-host "Do you want to overwrite it? yes/no" -fore yellow -noNewLine
                    $sOverwriteResultsFile = read-host " "
                    write-verbose "User answer: $sOverwriteResultsFile `n"
                }
                While (!($arrAnswers.Contains($sOverwriteResultsFile.toLower())))

                if (($sOverwriteResultsFile -eq "n") -or ($sOverwriteResultsFile -eq "no")) {
                    write-verbose "User selected no"
                    $bResultsFileCreationSuccess = $False
                    $ErrorMsg.value = "User has decided not to overwrite the existing results file"
                }
            }
            Else { # Test open file if AllowAppend has been set to True
                Try {
                    [io.file]::OpenWrite($OutputFile).close()
                }
                Catch {
                    $bResultsFileCreationSuccess = $False
                    $ErrorMsg.value = "Unable to append the file"
                }
            }
        }

        # Create the results file - unless allow append has been set to true
        if (($bResultsFileCreationSuccess) -and (!($AllowAppend))) {

            write-verbose "Attempting to create the results file"

            Try {
                New-Item $OutputFile -Force | out-null

            }
            Catch {
                write-verbose "Error creating new file $($Error[0])"

                $bResultsFileCreationSuccess = $False
                $ErrorMsg.value = $Error[0].exception -replace ("`n"," ") -replace ("`r"," ")
            }
        }
    }

    return $bResultsFileCreationSuccess
}


write-host "`n`n*****************************************************************************"
Write-Host "ps_AD_GetUserLastPwdChange.ps1 - MVogwell - v1"
Write-Host "Retrieve the last date a user changed their password from Active Directory"
Write-Host "Returns 0 if the password is set to never expire"
write-host "*****************************************************************************`n`n"

$bErrorLoadingADModule = $false
$bSuccessEnumeratingUsers = $True

Try { write-verbose "Attempting to import Powershell Module 'Active Directory'" ; import-module "ActiveDirectory" } catch { $bErrorLoadingADModule = $True ; write-host "Unable to load ActiveDirectory Powershell Module. The script will not exit`n`n" -fore red }

If(!($bErrorLoadingADModule)) {
    # Create the results file
    $ErrorMsg = ""
    $bCreatedResultsFileSuccess = CreateResultsFile -OutputFile $ExportFilePath -ErrorMsg ([ref]$ErrorMsg) -AllowAppend $False

    If($bCreatedResultsFileSuccess -eq $False) {
        write-host "It was not possible to create the results file $ExportFilePath :"
        Write-Host "Error: $ErrorMsg"
    }
    Else {          # Results file created successfully
        If($ScanAllUsers -eq $True) {
            Try {
                If($LDAPSearchBase.length -gt 0) {  # Use an LDAP Search Base if requested
                    write-verbose "Attempting to retrieve all users from the base OU $LDAPSearchBase"
                    $objADResults = Get-ADUser -Filter * -SearchBase $LDAPSearchBase -Properties pwdLastSet | Select Name, pwdLastSet
                }
                Else {
                    write-verbose "Attempting to retrieve all users from the AD"
                    $objADResults = Get-ADUser -Filter * -Properties pwdLastSet | Select Name, pwdLastSet
                }
            }
            Catch {
                write-host "`nUnable to enumerate the requested Active Directory information. Error:" -fore red
                write-host "$($Error[0])"
                write-host "`nThe script will now exit`n`n" -fore red
                $bSuccessEnumeratingUsers = $False
            }
        }
        Else {      # Startup args selected to scan users in the UserlistTextFilePath
            $objADResults = @()

            write-verbose "Attempting to access user list in  $UserlistTextFilePath"

            If(Test-Path($UserlistTextFilePath)) {
                Try {
                    Write-Verbose "Getting user list from file now"
                    $arrUserList = Get-Content $UserlistTextFilePath
                }
                Catch {
                    write-host "Unable to access the file contents of $UserlistTextFilePath" -fore red
                    Write-Host "The script will now exit `n`n" -fore red
                    $bSuccessEnumeratingUsers = $False
                }

                If($arrUserList -eq $Null) {
                    write-host "No data has been found in $UserlistTextFilePath" -fore red
                    Write-Host "The script will now exit `n`n" -fore red
                    $bSuccessEnumeratingUsers = $False
                }
                Else {
                    Write-Verbose "Attempting to access AD info"

                    Foreach($objUserName in $arrUserList) {
                        $objUserResult = New-Object -TypeName PSObject

                        Try {
                            $i64 = (get-aduser -Filter "Name -eq '$objUserName'" -Properties pwdLastSet | select pwdLastSet).pwdLastSet
                            write-verbose "... $objUserName - Found"
                            $objUserResult | Add-Member -MemberType NoteProperty -Name "Name" -Value $objUserName
                            $objUserResult | Add-Member -MemberType NoteProperty -Name "pwdLastSet" -Value $i64
                        }
                        Catch {
                            [string]$uNameNotFoundMsg = "USER NOT FOUND - " + $objUserName
                            write-verbose "... $objUserName - NOT Found"
                            $objUserResult | Add-Member -MemberType NoteProperty -Name "Name" -Value $uNameNotFoundMsg
                            $objUserResult | Add-Member -MemberType NoteProperty -Name "pwdLastSet" -Value 0
                        }

                        $objADResults += $objUserResult

                        $i64 = $null
                    }
                }
            }
            Else {  # Unable to access the source file containing the list of users
                write-host "Unable to access the file $UserlistTextFilePath" -fore red
                Write-Host "The script will now exit `n`n" -fore red
                $bSuccessEnumeratingUsers = $False
            }
        }

        If($objADResults -eq $Null) {
            $bSuccessEnumeratingUsers = $False
            write-host "The search did not return any users from the Active Directory. The script will now exit `n`n" -fore red
        }

        if($bSuccessEnumeratingUsers -eq $True) { # Only continue if a list of users if discovered
            If($objADResults.Length -le 0) {
                write-host "The serach did not return any users. The script will now exit `n`n" -fore red
            }
            Else {
                write-verbose "Converting Int64 to Date and exporting data to csv file"

                $arrFormattedResults = @()

                Foreach($objUser in $objADResults) {
                    $i64PwdLastSet = $objUser.pwdLastSet
                    If($i64PwdLastSet -gt 0) {
                        [string]$sPwdLastSet = ([DateTime]::FromFileTimeutc($i64PwdLastSet)).toString()
                    }
                    Else {
                        [string]$sPwdLastSet = "0"
                    }

                    $objUserData = New-Object -TypeName psobject
                    $objUserData | Add-Member -MemberType NoteProperty -Name "Name" -Value $($objUser.Name)
                    $objUserData | Add-Member -MemberType NoteProperty -Name "PwdLastSet" -Value $sPwdLastSet

                    $arrFormattedResults += $objUserData
                }

                # Export the results
                write-host "`nExporting the information to $ExportFilePath`n`n" -fore green
                Try {
                    $arrFormattedResults | Export-Csv $ExportFilePath -NoTypeInformation
                }
                Catch {
                    write-host "It has not been possible to export to $ExportFilePath. " -fore Red
                    Write-Host "Please check the file isn't open in another application and try again`n`n" -fore red
                }

            }
        }
    }
}

# End
