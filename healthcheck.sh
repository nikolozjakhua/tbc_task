#!/bin/bash

ping_health_check() {
    if ping -c 1 ${ACTIVE_INSTANCE_IP} >/dev/null; then
        return 0  
    else
        return 1  
    fi
}

main() {
    while true; do
        if ! ping_health_check; then
            CURRENT_ASSOCIATION_ID=$(aws ec2 --region ${REGION} describe-addresses --query 'Addresses[?AllocationId==`'"${ALLOCATION_ID}"'`].AssociationId' --output text)
            aws ec2 disassociate-address --region ${REGION} --association-id $${CURRENT_ASSOCIATION_ID}
            INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
            aws ec2 associate-address --region ${REGION} --allocation-id ${ALLOCATION_ID} --instance-id $${INSTANCE_ID}
            echo "Health check failed. Elastic IP associated with the standby instance."
            exit
        else
            echo "Health check passed."
        fi
        
        sleep 15
    done
}

# Execute the main function
main