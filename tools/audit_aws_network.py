"""Check the deployed game's actual AWS exposure without reading secret values."""
import json
from pathlib import Path

import boto3

ROOT = Path(__file__).resolve().parents[1]


def main():
    state = json.loads((ROOT / "artifacts/aws-direct/state.json").read_text())
    session = boto3.Session(region_name="us-east-1")
    ecs, ec2, elb, s3, cf, rds, cache = [
        session.client(name) for name in
        ["ecs", "ec2", "elbv2", "s3", "cloudfront", "rds", "elasticache"]
    ]
    report = {"services": []}
    services = ecs.describe_services(cluster=state["cluster"], services=["api", "solo", "duo"])
    assert not services["failures"] and len(services["services"]) == 3
    task_arns = []
    for service in services["services"]:
        network = service["networkConfiguration"]["awsvpcConfiguration"]
        assert network["assignPublicIp"] == "DISABLED"
        assert service["runningCount"] == service["desiredCount"] == 1
        report["services"].append({"name": service["serviceName"], "public_ip": False})
        for page in ecs.get_paginator("list_tasks").paginate(
            cluster=state["cluster"], serviceName=service["serviceName"]
        ):
            task_arns.extend(page["taskArns"])
    tasks = ecs.describe_tasks(cluster=state["cluster"], tasks=task_arns)
    assert not tasks["failures"]
    enis = [
        detail["value"]
        for task in tasks["tasks"] for attachment in task["attachments"]
        for detail in attachment["details"] if detail["name"] == "networkInterfaceId"
    ]
    assert len(enis) == 3
    interfaces = ec2.describe_network_interfaces(NetworkInterfaceIds=enis)["NetworkInterfaces"]
    assert all(not interface.get("Association", {}).get("PublicIp") for interface in interfaces)
    report["task_private_ips"] = [interface["PrivateIpAddress"] for interface in interfaces]
    balancers = elb.describe_load_balancers(LoadBalancerArns=[
        state["alb"]["LoadBalancerArn"], state["nlb"]["LoadBalancerArn"]
    ])["LoadBalancers"]
    assert all(b["Scheme"] == "internal" for b in balancers if b["Type"] == "application")
    origin_group = ec2.describe_security_groups(Filters=[
        {"Name": "vpc-id", "Values": [state["vpc"]]},
        {"Name": "group-name", "Values": ["CloudFront-VPCOrigins-Service-SG"]},
    ])["SecurityGroups"][0]["GroupId"]
    alb_rules = ec2.describe_security_groups(GroupIds=[state["sg_alb"]])["SecurityGroups"][0]["IpPermissions"]
    assert len(alb_rules) == 1
    rule = alb_rules[0]
    assert rule["IpProtocol"] == "tcp" and rule["FromPort"] == rule["ToPort"] == 80
    assert not rule.get("IpRanges") and not rule.get("Ipv6Ranges")
    assert {item["GroupId"] for item in rule["UserIdGroupPairs"]} == {origin_group}
    listeners = elb.describe_listeners(LoadBalancerArn=state["nlb"]["LoadBalancerArn"])["Listeners"]
    assert {(x["Protocol"], x["Port"]) for x in listeners} == {("UDP", 27015), ("UDP", 27022)}
    report["public_game_listeners"] = ["UDP/27015", "UDP/27022"]
    for key in ["download_bucket", "backup_bucket"]:
        assert all(s3.get_public_access_block(Bucket=state[key])["PublicAccessBlockConfiguration"].values())
        assert not s3.get_bucket_policy_status(Bucket=state[key])["PolicyStatus"]["IsPublic"]
    distribution = cf.get_distribution(Id=state["distribution"]["Id"])["Distribution"]
    assert distribution["Status"] == "Deployed"
    origins = {x["Id"]: x for x in distribution["DistributionConfig"]["Origins"]["Items"]}
    assert origins["downloads"]["OriginAccessControlId"] == state["oac"]
    assert origins["api"]["VpcOriginConfig"]["VpcOriginId"] == state["vpc_origin"]
    report["private_s3_oac"] = report["api_internal_alb_vpc_origin"] = True
    db = rds.describe_db_instances(DBInstanceIdentifier=state["db"])["DBInstances"][0]
    assert not db["PubliclyAccessible"] and db["StorageEncrypted"] and db["DeletionProtection"]
    redis = cache.describe_replication_groups(ReplicationGroupId=state["cache"])["ReplicationGroups"][0]
    assert redis["AtRestEncryptionEnabled"] and redis["TransitEncryptionEnabled"] and redis["AuthTokenEnabled"]
    report["private_database"] = report["redis_tls_auth"] = True
    report["status"] = "passed"
    destination = ROOT / "artifacts/aws-public-verification/network-audit.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
