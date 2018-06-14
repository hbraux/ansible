curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox/credentials/kdc.admin.credential
curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox/artifacts/kerberos_descriptor
curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox/hosts/hdp1.hostonly.com/host_components/KERBEROS_CLIENT
curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox/services/KERBEROS/components/KERBEROS_CLIENT
curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox/services/KERBEROS

exit

curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/blueprints/ansible
curl -v -u admin:admin -H "X-Requested-By: ambari" -XDELETE http://hdp1.hostonly.com:8080/api/v1/clusters/sandbox

