#!/bin/bash

rm_all_log_dirs () {
	rm -rf /tmp/kraft-combined-logs*
	rm -rf ../logs
}

start_broker_from_clus_prop(){
	./kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c $SERVER_PROP_PATH && \
	./kafka-server-start.sh $SERVER_PROP_PATH &
}

create_new_server_prop_by_id()
{	
	cp $SERVER_PROP_PATH $new_server_prop_path

	sed -i "s/kraft-combined-logs-1/kraft-combined-logs-${id}/g" $new_server_prop_path
	sed -i "s/node.id=1/node.id=${id}/g" $new_server_prop_path

	port=$((9092+id)) #9092 for the first broker, 9093 for a controller
	sed -i "s|9092,CONTROLLER://:9093|$port|g" $new_server_prop_path

	sed -i 's/broker,controller/broker/g' $new_server_prop_path
	sed -i 's/advertised.listeners/#advertised.listeners/g' $new_server_prop_path
}

start_broker_in_clus_by_id(){
	new_server_prop_path=${SERVER_PROP_PATH/.properties/${id}.properties} #https://stackoverflow.com/questions/8903180/how-to-use-sed-without-a-file-with-an-env-var
	#echo $new_server_prop_path

	create_new_server_prop_by_id $SERVER_PROP_PATH $new_server_prop_path $id

	./kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c $new_server_prop_path && \
	./kafka-server-start.sh $new_server_prop_path &

	showListener=`grep listeners=PLAINTEXT://: $new_server_prop_path`
	echo broker$id on $showListener
}


###############################################################################################
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

rm_all_log_dirs

readonly nbrokers=$1
readonly SERVER_PROP_PATH="../config/kraft/server.properties"
readonly KAFKA_CLUSTER_ID="$(./kafka-storage.sh random-uuid)"
echo "cluster_id: ${KAFKA_CLUSTER_ID} , #broker: ${nbrokers}"

start_broker_from_clus_prop $KAFKA_CLUSTER_ID $SERVER_PROP_PATH

for (( i = 0; i < $nbrokers; i++ ))
do
	id=$((i+2))
	start_broker_in_clus_by_id $KAFKA_CLUSTER_ID $SERVER_PROP_PATH $id
done
