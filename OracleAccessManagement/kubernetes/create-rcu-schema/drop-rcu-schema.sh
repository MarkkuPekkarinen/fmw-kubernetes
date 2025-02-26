#!/bin/bash
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# Drop the RCU schema based on schemaPreifix and Database URL

script="${BASH_SOURCE[0]}"
scriptDir="$( cd "$( dirname "${script}" )" && pwd )"
source ${scriptDir}/../common/utility.sh

usage() {
  echo "usage: ${script} -s <schemaPrefix> [-t <schemaType>] [-d <dburl>] [-n <namespace>] [-c <credentialsSecretName>] [-p <docker-store>] [-i <image>] [-u <imagePullPolicy>] [-o <rcuOutputDir>] [-r <customVariables>] [-h]"
  echo "  -s RCU Schema Prefix (required)"
  echo "  -t RCU Schema Type (optional)"
  echo "      (supported values: oam) "
  echo "  -d RCU Oracle Database URL (optional) "
  echo "      (default: oracle-db.default.svc.cluster.local:1521/devpdb.k8s) "
  echo "  -n Namespace for RCU pod (optional)"
  echo "      (default: default)"
  echo "  -c Name of credentials secret (optional)."
  echo "       (default: oracle-rcu-secret)"
  echo "       Must contain SYSDBA username at key 'sys_username',"
  echo "       SYSDBA password at key 'sys_password',"
  echo "       and RCU schema owner password at key 'password'."
  echo "  -p OracleAccessManagement ImagePullSecret (optional) "
  echo "      (default: none) "
  echo "  -i OracleAccessManagement Image (optional) "
  echo "      (default: oracle/oam:12.2.1.4.0) "
  echo "  -u OracleAccessManagement ImagePullPolicy (optional) "
  echo "      (default: IfNotPresent) "
  echo "  -o Output directory for the generated YAML file. (optional)"
  echo "      (default: rcuoutput)"
  echo "  -r Comma-separated custom variables in the format variablename=value. (optional)."
  echo "      (default: none)"
  echo "  -h Help"
  echo ""
  echo "NOTE: The c, p, i, u, and o arguments are ignored if an rcu pod is already running in the namespace."
  echo ""
  exit $1
}

dburl="oracle-db.default.svc.cluster.local:1521/devpdb.k8s"
rcuType="${rcuType}"
namespace="default"
createPodArgs=""

while getopts ":s:t:d:n:c:p:i:u:o:v:h:" opt; do
  case $opt in
    s) schemaPrefix="${OPTARG}"
    ;;
    t) rcuType="${OPTARG}"
    ;;
    d) dburl="${OPTARG}"
    ;;
    n) namespace="${OPTARG}"
    ;;
    c|p|i|u|o) createPodArgs+=" -${opt} ${OPTARG}"
    ;;
    v) customVariables="${OPTARG}"
    ;;
    h) usage 0
    ;;
    *) usage 1
    ;;
  esac
done

if [ -z "${schemaPrefix}" ]; then
  echo "${script}: -s <schemaPrefix> must be specified."
  usage 1
fi

# this creates the rcu pod if it doesn't already exist
echo "[INFO] Calling '${scriptDir}/common/create-rcu-pod.sh -n $namespace $createPodArgs'"
${scriptDir}/common/create-rcu-pod.sh -n $namespace $createPodArgs || exit -4

#fmwimage=`${KUBERNETES_CLI:-kubectl} get pod/rcu  -o jsonpath="{..image}"`
echo "DB Connection String [$dbUrl], schemaPrefix [${schemaPrefix}] rcuType [${rcuType}] schemaProfileType [${customVariables}]"

${KUBERNETES_CLI:-kubectl} exec -n $namespace -i rcu -- /bin/bash /u01/oracle/dropRepository.sh ${dburl} ${schemaPrefix} ${rcuType} ${customVariables}
if [ $? != 0  ]; then
 echo "######################";
 echo "[ERROR] Could not drop the RCU Repository based on dburl[${dburl}] schemaPrefix[${schemaPrefix}]  ";
 echo "######################";
 exit -3;
fi

