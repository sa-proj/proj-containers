function Write-Status ($message) {Write-Host -NoNewline ("[$(get-date -Format 'HH:mm:ss')] $message").PadRight(75) -ForegroundColor "Yellow"}
function Update-Status ($status = "OK") {Write-Host "[$status]" -ForegroundColor "Green" } 
function Exit-Fail ($message) {
	Write-Host "`nERROR: $message" -ForegroundColor "Red"
	Write-Host "Result:Failed." -ForegroundColor "Red"
	exit 0x1
}
#Create Master Key
function createmasterkey($instance, $masterkeypass)
{
	$query = @"
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$masterkeypass';
"@
	$ErrorActionPreference = "Stop"
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$instance;Database=master;User ID = $uid; Password = $sapassword;Connection Timeout=30;"
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $query
	$SqlCmd.CommandTimeout = 0
	$SqlCmd.Connection = $SqlConnection
	Try{
		Write-Status "Creating Master Key for Encryption on $instance."
		$SqlCmd.ExecuteNonQuery() | Out-Null
		Update-Status
	}
	Catch{
		Exit-Fail "Failed to create Master Key for Encryption on $instance : $_.Exception.Message"
	}
	$ErrorActionPreference = "Continue"
	$SqlConnection.Close()
}
#Create certificate
function createcertificate($instance)
{
    $instancestring = $instance -replace "-", "_"
	$query = @"
	CREATE CERTIFICATE $($instancestring)_cert WITH SUBJECT = '$($instance) ag certificate';
"@
	$ErrorActionPreference = "Stop"
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$instance;Database=master;User ID = $uid; Password = $sapassword;Connection Timeout=30;"
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $query
	$SqlCmd.CommandTimeout = 0
	$SqlCmd.Connection = $SqlConnection
	Try{
		Write-Status "Creating Certificate on $instance."
		$SqlCmd.ExecuteNonQuery() | Out-Null
		Update-Status
	}
	Catch{
		Exit-Fail "Failed to create certificate on $instance : $_.Exception.Message"
	}
	$ErrorActionPreference = "Continue"
	$SqlConnection.Close()
}
#Backup certificate
function backupcertificate($instance)
{
    $instancestring = $instance -replace "-", "_"
	$query = @"
	BACKUP CERTIFICATE $($instancestring)_cert TO FILE = '/var/opt/mssql/backup/$($instancestring)_cert.cer';
"@
	$ErrorActionPreference = "Stop"
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$instance;Database=master;User ID = $uid; Password = $sapassword;Connection Timeout=30;"
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $query
	$SqlCmd.CommandTimeout = 0
	$SqlCmd.Connection = $SqlConnection
	Try{
		Write-Status "Backing up certificate on $instance to /var/opt/mssql/backup/$($instancestring)_cert.cer."
		$SqlCmd.ExecuteNonQuery() | Out-Null
		Update-Status
	}
	Catch{
		Exit-Fail "Failed to backup certificate $($instancestring)_cert on $instance : $_.Exception.Message"
	}
	$ErrorActionPreference = "Continue"
	$SqlConnection.Close()
}
#Create HADR Endpoint
function createhadrendpoint($instance)
{
    $instancestring = $instance -replace "-", "_"
	$query = @"
	CREATE ENDPOINT hadr
    STATE = STARTED
    AS TCP (
        LISTENER_PORT = 5022,
        LISTENER_IP = ALL)
    FOR DATABASE_MIRRORING (
        AUTHENTICATION = CERTIFICATE $($instancestring)_cert,
        ROLE = ALL);
"@
	$ErrorActionPreference = "Stop"
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$instance;Database=master;User ID = $uid; Password = $sapassword;Connection Timeout=30;"
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $query
	$SqlCmd.CommandTimeout = 0
	$SqlCmd.Connection = $SqlConnection
	Try{
		Write-Status "Creating HADR Endpoint on $instance."
		$SqlCmd.ExecuteNonQuery() | Out-Null
		Update-Status
	}
	Catch{
		Exit-Fail "Failed to create HADR endpoint on $instance : $_.Exception.Message"
	}
	$ErrorActionPreference = "Continue"
	$SqlConnection.Close()
}
#Create HADR user and authroize that user to connect to endpoint
function createhadruser($primaryinstance, $secondaryinstance, $userpass)
{
    $secondaryinstancestring = $secondaryinstance -replace "-", "_"
	$query = @"
	CREATE LOGIN $($secondaryinstancestring)_login WITH PASSWORD = '$userpass';
    CREATE USER $($secondaryinstancestring)_user FOR LOGIN $($secondaryinstancestring)_login;
    CREATE CERTIFICATE $($secondaryinstancestring)_cert
    AUTHORIZATION $($secondaryinstancestring)_user
    FROM FILE = '/var/opt/mssql/backup/$($secondaryinstancestring)_cert.cer';
    GRANT CONNECT ON ENDPOINT::hadr TO $($secondaryinstancestring)_login;

"@
	$ErrorActionPreference = "Stop"
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$primaryinstance;Database=master;User ID = $uid; Password = $sapassword;Connection Timeout=30;"
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $query
	$SqlCmd.CommandTimeout = 0
	$SqlCmd.Connection = $SqlConnection
	Try{
		Write-Status "Creating HADR login and grant is permissions on $primaryinstance."
		$SqlCmd.ExecuteNonQuery() | Out-Null
		Update-Status
	}
	Catch{
		Exit-Fail "Failed to create HADR login on $primaryinstance : $_.Exception.Message"
	}
	$ErrorActionPreference = "Continue"
	$SqlConnection.Close()
}

#Main
$uid = 'sa'
$sapassword = 'P@ssw0rd'
$master_key_password = 'P@ssw0rd'
$new_login_password = 'P@ssw0rd'
$primary_sql_server = 'sql-1'
$secondary_sql_server = 'sql-2'

#Create Master key on sql-1
createmasterkey $primary_sql_server $master_key_password
#Create Master key on sql-2
createmasterkey $secondary_sql_server $master_key_password
#Create certificate on sql-1
createcertificate $primary_sql_server
#Create certificate on sql-2
createcertificate $secondary_sql_server
#Backup the certificate to common locaion from sql-1
backupcertificate $primary_sql_server
#Backup the certificate to common locaion from sql-2
backupcertificate $secondary_sql_server
#Create hadr endpoint for sql-1
createhadrendpoint $primary_sql_server
#Create hadr endpoint for sql-2
createhadrendpoint $secondary_sql_server
#Create the instance-level logins and users +  restore other replicas' certificates for AG communication and security
createhadruser $primary_sql_server $secondary_sql_server $new_login_password
createhadruser $secondary_sql_server $primary_sql_server $new_login_password