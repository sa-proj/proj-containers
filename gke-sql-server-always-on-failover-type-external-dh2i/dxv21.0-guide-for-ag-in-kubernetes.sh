#---------------------------------------------------
#On Primary POD sql-1-0
#---------------------------------------------------
#1. Activate the DxEnterprise license using the command
kubectl exec sql-1-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX

#2. Add a Vhost to the cluster
kubectl exec sql-1-0 -- dxcli cluster-add-vhost vhost1 *127.0.0.1 sql-1-0

#3. Encrypt the SQL Server sysadmin password . The encrypted password will be used to create the availability group in the next step.
kubectl exec sql-1-0 -- dxcli encrypt-text P@ssw0rd
#Note: Output of above command: OAfe63v3+APrmqyDdnSnhQ==
#Note: Don't push senstive information to github.

#4. Add an availability group to the Vhost. The SQL Server sysadmin password must be encrypted.
kubectl exec sql-1-0 -- dxcli add-ags vhost1 ags1 "sql-1-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40001"

#5. Set a One-Time PassKey (OTPK). The output from this command will be used to join the other nodes to the DxEnterprise cluster.
kubectl exec sql-1-0 -- dxcli set-otpk
#OTPK: ****************************************  Good Until: 2021-09-18T10:47:13

#---------------------------------------------------
#On Secondary 1 POD sql-2-0
#---------------------------------------------------
#1. Activate the DxEnterprise license using the command
kubectl exec sql-2-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX

#2. Join the second node to the DxEnterprise cluster. Use the default NAT proxy of match.dh2i.com.
kubectl exec sql-2-0 -- dxcli join-cluster-ex match.dh2i.com **************************************** true

#3. Add the second node to the existing availability group. The SQL Server sysadmin password must be encrypted.
kubectl exec sql-2-0 -- dxcli add-ags-node vhost1 ags1 "sql-2-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40002"

#---------------------------------------------------
#On Secondary 2 POD sql-3-0
#---------------------------------------------------
#1. Activate the DxEnterprise license using the command
kubectl exec sql-3-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX

#2. Join the third node to the DxEnterprise cluster. Use the default NAT proxy of match.dh2i.com.
kubectl exec sql-3-0 -- dxcli join-cluster-ex match.dh2i.com **************************************** true

#3. Add the third node to the existing availability group. The SQL Server sysadmin password must be encrypted.
kubectl exec sql-3-0 -- dxcli add-ags-node vhost1 ags1 "sql-3-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40003"

#---------------------------------------------------
#Back On Primary POD sql-1-0
#---------------------------------------------------
#1. Add databases to the availability group
kubectl exec sql-1-0 -- dxcli add-ags-databases vhost1 ags1 sample
#2. Add a listener to the availability group
kubectl exec sql-1-0 -- dxcli add-ags-listener vhost1 ags1 44444


#Official documentation Link - docs.dh2i.com
