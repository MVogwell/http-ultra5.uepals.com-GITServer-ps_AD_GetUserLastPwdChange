## SYNOPSIS
This Powershell script returns a csv file containing information about the last time a user's password was reset from Active Directory.

## DESCRIPTION
The script can either check all Active Directory users, all users under a specific Organizational Unit or specific users listed in a text file and will export the results to a CSV file. See help ps_AD_GetUserLastPwdChange.ps1 -Detailed for more information.

To return data for a specific list of users add a list of Usernames or Display Names to <script-root-path>\GetUserLastPwdChange_UserList.txt (or you can specific a custom location for this file by using the UserlistTextFilePath paramater )

## Parameters

### PARAMETER UserlistTextFilePath
The location of a text file containing a list of users. The default location is the same folder as the script in a file called GetUserLastPwdChange_UserList.txt

### PARAMETER ScanAllUsers
Boolean option to scan all users in the Active Directory. Must be used if LDAPSearchBase parameter is used

### PARAMETER ExportFilePath
The location of where the export file should be saved to. Default is the same folder as the script in a file called GetUserLastPwdChange_Results.csv

### PARAMETER LDAPSearchBase
Use in conjunction with ScanAllUsers. This requires an LDAP path and is used to limit the root Organizational Unit from where to search for users.


## Examples 	

### EXAMPLE

Without using any parameters the default UserlistTextFilePath (<script-root-path>\GetUserLastPwdChange_UserList.txt) and ExportFilePath (<script-root-path>\GetUserLastPwdChange_Results.csv) parameters and search for users listed in the UserlistTextFilePath text file
./ps_AD_GetUserLastPwdChange.ps1

### EXAMPLE

Specify the UserlistTextFilePath and ExportFilePath to use files in locations other than the defaults
./ps_AD_GetUserLastPwdChange.ps1 -UserlistTextFilePath c:\temp\MyCustomUserListLocation.txt -ExportFilePath c:\temp\MyCustomUserExport.csv

### EXAMPLE

Return details for all users in the Active Directory by using the ScanAllUsers paramater
./ps_AD_GetUserLastPwdChange.ps1 -ScanAllUsers:$True

### EXAMPLE

... And limit the users returned by specifying a Search Base LDAP Path
./ps_AD_GetUserLastPwdChange.ps1 -ScanAllUsers:$True -LDAPSearchBase "CN=Users,DC=contoso,DC=com"


## NOTES
MVogwell - October 2017