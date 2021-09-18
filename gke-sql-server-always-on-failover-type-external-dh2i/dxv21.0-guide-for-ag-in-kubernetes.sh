#On Primary
kubectl exec sql-1-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX
kubectl exec sql-1-0 -- dxcli cluster-add-vhost vhost1 *127.0.0.1 sql-1-0
kubectl exec sql-1-0 -- dxcli encrypt-text P@ssw0rd
#OAfe63v3+APrmqyDdnSnhQ==
kubectl exec sql-1-0 -- dxcli add-ags vhost1 ags1 "sql-1-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40001"
kubectl exec sql-1-0 -- dxcli set-otpk
#OTPK: ****************************************  Good Until: 2021-09-18T10:47:13

#On Secondary #1
kubectl exec sql-2-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX
kubectl exec sql-2-0 -- dxcli join-cluster-ex match.dh2i.com **************************************** true
kubectl exec sql-2-0 -- dxcli add-ags-node vhost1 ags1 "sql-2-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40002"

#On Secondary #2
kubectl exec sql-3-0 -- dxcli activate-server XXXX-XXXX-XXXX-XXXX
kubectl exec sql-3-0 -- dxcli join-cluster-ex match.dh2i.com **************************************** true
kubectl exec sql-3-0 -- dxcli add-ags-node vhost1 ags1 "sql-3-0|mssqlserver|sa|OAfe63v3+APrmqyDdnSnhQ==|5022|synchronous_commit|40003"

#On Primary
kubectl exec sql-1-0 -- dxcli add-ags-databases vhost1 ags1 sample
kubectl exec sql-1-0 -- dxcli add-ags-listener vhost1 ags1 44444



