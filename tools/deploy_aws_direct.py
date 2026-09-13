"""Deploy private ECS services and an OAC download site directly through AWS APIs.

No CloudFormation/CDK/Terraform calls. Resource IDs are checkpointed locally.
Generated secret material stays in mode-0600 files and Secrets Manager.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
import uuid

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts/aws-direct"
REGION = "us-east-1"
ART.mkdir(exist_ok=True)


def private_write(path, data):
    temporary = path.with_suffix(".tmp")
    with os.fdopen(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as file:
        json.dump(data, file, indent=2, default=str)
    temporary.replace(path)


STATE_FILE = ART / "state.json"
state = json.loads(STATE_FILE.read_text()) if STATE_FILE.exists() else {"run": uuid.uuid4().hex[:8]}
private_write(STATE_FILE, state)
session = boto3.Session(region_name=REGION)
config = Config(retries={"mode": "standard", "max_attempts": 8}, connect_timeout=10, read_timeout=60)
clients = {}


def aws(service):
    if service not in clients:
        clients[service] = session.client(service, config=config)
    return clients[service]


def save(key, value):
    state[key] = value
    private_write(STATE_FILE, state)
    return value


def ensure(key, create):
    if key not in state:
        print("Creating " + key, flush=True)
        save(key, create())
    return state[key]


def wait(label, probe, predicate, timeout=1800):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = probe()
        if predicate(value):
            print(label + " ready", flush=True)
            return value
        time.sleep(15)
    raise TimeoutError(label + " did not become ready")


def tags():
    return [{"Key": "Project", "Value": "IronMeridian"}, {"Key": "Deployment", "Value": state["run"]},
            {"Key": "ManagedBy", "Value": "DirectAWSAPI"}]


def tagged(kind):
    return [{"ResourceType": kind, "Tags": tags()}]


def ingress(group, protocol, port, source_group=None, cidr=None):
    rule = {"IpProtocol": protocol, "FromPort": port, "ToPort": port}
    rule["UserIdGroupPairs" if source_group else "IpRanges"] = (
        [{"GroupId": source_group}] if source_group else [{"CidrIp": cidr}])
    try:
        aws("ec2").authorize_security_group_ingress(GroupId=group, IpPermissions=[rule])
    except ClientError as error:
        if error.response["Error"]["Code"] != "InvalidPermission.Duplicate":
            raise


def bucket(name):
    s3 = aws("s3")
    s3.create_bucket(Bucket=name)
    s3.put_public_access_block(Bucket=name, PublicAccessBlockConfiguration={
        "BlockPublicAcls": True, "IgnorePublicAcls": True, "BlockPublicPolicy": True, "RestrictPublicBuckets": True})
    s3.put_bucket_encryption(Bucket=name, ServerSideEncryptionConfiguration={
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]})
    s3.put_bucket_versioning(Bucket=name, VersioningConfiguration={"Status": "Enabled"})
    s3.put_bucket_tagging(Bucket=name, Tagging={"TagSet": tags()})
    s3.put_bucket_policy(Bucket=name, Policy=json.dumps({"Version": "2012-10-17", "Statement": [
        {"Effect": "Deny", "Principal": "*", "Action": "s3:*",
         "Resource": [f"arn:aws:s3:::{name}", f"arn:aws:s3:::{name}/*"],
         "Condition": {"Bool": {"aws:SecureTransport": "false"}}}]}))
    return name


def iam_role(name, service):
    role = aws("iam").create_role(RoleName=name, AssumeRolePolicyDocument=json.dumps({
        "Version": "2012-10-17", "Statement": [{"Effect": "Allow",
        "Principal": {"Service": service}, "Action": "sts:AssumeRole"}]}), Tags=tags())["Role"]
    return role["Arn"]


def policy(role_arn, name, statements):
    aws("iam").put_role_policy(RoleName=role_arn.rsplit("/", 1)[-1], PolicyName=name,
                              PolicyDocument=json.dumps({"Version": "2012-10-17", "Statement": statements}))


def secret_arn(key, prefix):
    seeds_file = ART / "generated-secrets.json"
    seeds = json.loads(seeds_file.read_text()) if seeds_file.exists() else {}
    if key not in seeds:
        seeds[key] = secrets.token_hex(32)
        private_write(seeds_file, seeds)
    arn = ensure(key + "_secret", lambda: aws("secretsmanager").create_secret(
        Name=prefix + "/" + key, SecretString=seeds[key], Tags=tags())["ARN"])
    return arn, seeds[key]


def image(kind, account):
    if "image_" + kind in state:
        return state["image_" + kind]
    ecr = aws("ecr")
    name = "iron-meridian-" + kind
    try:
        repo = ecr.describe_repositories(repositoryNames=[name])["repositories"][0]
    except ecr.exceptions.RepositoryNotFoundException:
        repo = ecr.create_repository(repositoryName=name, imageScanningConfiguration={"scanOnPush": True},
                                     tags=[{"Key": x["Key"], "Value": x["Value"]} for x in tags()])["repository"]
    uri = repo["repositoryUri"] + ":aws-0.38-" + state["run"]
    token = ecr.get_authorization_token()["authorizationData"][0]
    username, password = base64.b64decode(token["authorizationToken"]).decode().split(":", 1)
    subprocess.run(["docker", "login", "--username", username, "--password-stdin", token["proxyEndpoint"]],
                   input=password.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    with (ART / f"image-{kind}.log").open("w") as log:
        subprocess.run(["docker", "build", "-t", uri, str(ROOT / "infra/aws" / kind)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run(["docker", "push", uri], stdout=log, stderr=subprocess.STDOUT, check=True)
    digest = ecr.describe_images(repositoryName=name, imageIds=[{"imageTag": uri.split(":")[-1]}])["imageDetails"][0]["imageDigest"]
    return save("image_" + kind, repo["repositoryUri"] + "@" + digest)


def main():
    windows_archive = ROOT / "artifacts/IronMeridian-Windows-x86_64.zip"
    windows_build = json.loads((ROOT / "artifacts/windows-build/build.json").read_text())
    windows_tests = json.loads((ROOT / "artifacts/windows-verification/verification.json").read_text())
    assert windows_tests["status"] == "passed"
    assert hashlib.sha256(windows_archive.read_bytes()).hexdigest() == windows_build["sha256"] == windows_tests["archive_sha256"]
    account = aws("sts").get_caller_identity()["Account"]
    prefix = "im-" + state["run"]
    ec2 = aws("ec2")
    vpc = ensure("vpc", lambda: ec2.create_vpc(CidrBlock="10.88.0.0/16", TagSpecifications=tagged("vpc"))["Vpc"]["VpcId"])
    ec2.modify_vpc_attribute(VpcId=vpc, EnableDnsSupport={"Value": True})
    ec2.modify_vpc_attribute(VpcId=vpc, EnableDnsHostnames={"Value": True})
    azs = sorted(x["ZoneName"] for x in ec2.describe_availability_zones(
        Filters=[{"Name": "state", "Values": ["available"]}])["AvailabilityZones"])[:2]
    subnets = {}
    for kind, offset in [("public", 0), ("app", 10), ("data", 20)]:
        subnets[kind] = [ensure(f"subnet_{kind}_{i}", lambda i=i, kind=kind, offset=offset:
            ec2.create_subnet(VpcId=vpc, CidrBlock=f"10.88.{offset+i}.0/24", AvailabilityZone=azs[i],
                              TagSpecifications=tagged("subnet"))["Subnet"]["SubnetId"]) for i in range(2)]
    igw = ensure("igw", lambda: ec2.create_internet_gateway(TagSpecifications=tagged("internet-gateway"))["InternetGateway"]["InternetGatewayId"])
    if not state.get("igw_attached"):
        ec2.attach_internet_gateway(InternetGatewayId=igw, VpcId=vpc)
        save("igw_attached", True)
    public_rt = ensure("public_route_table", lambda: ec2.create_route_table(VpcId=vpc, TagSpecifications=tagged("route-table"))["RouteTable"]["RouteTableId"])
    if not state.get("public_routes"):
        ec2.create_route(RouteTableId=public_rt, DestinationCidrBlock="0.0.0.0/0", GatewayId=igw)
        for subnet in subnets["public"]:
            ec2.associate_route_table(RouteTableId=public_rt, SubnetId=subnet)
        save("public_routes", True)
    allocation = ensure("nat_eip", lambda: ec2.allocate_address(Domain="vpc", TagSpecifications=tagged("elastic-ip"))["AllocationId"])
    nat = ensure("nat", lambda: ec2.create_nat_gateway(SubnetId=subnets["public"][0], AllocationId=allocation,
                    ClientToken=prefix, TagSpecifications=tagged("natgateway"))["NatGateway"]["NatGatewayId"])
    wait("NAT", lambda: ec2.describe_nat_gateways(NatGatewayIds=[nat])["NatGateways"][0],
         lambda x: x["State"] == "available", 900)
    app_rt = ensure("app_route_table", lambda: ec2.create_route_table(VpcId=vpc, TagSpecifications=tagged("route-table"))["RouteTable"]["RouteTableId"])
    if not state.get("app_routes"):
        ec2.create_route(RouteTableId=app_rt, DestinationCidrBlock="0.0.0.0/0", NatGatewayId=nat)
        for subnet in subnets["app"]:
            ec2.associate_route_table(RouteTableId=app_rt, SubnetId=subnet)
        save("app_routes", True)
    groups = {name: ensure("sg_" + name, lambda name=name: ec2.create_security_group(
        GroupName=prefix + "-" + name, Description="Iron Meridian " + name, VpcId=vpc,
        TagSpecifications=tagged("security-group"))["GroupId"]) for name in ["api", "game", "alb", "nlb", "db", "cache", "efs"]}
    for target, source, port in [("api", "alb", 8000), ("api", "game", 8000), ("db", "api", 5432),
                                  ("cache", "api", 6379), ("efs", "game", 2049), ("game", "nlb", 8765)]:
        ingress(groups[target], "tcp", port, source_group=groups[source])
    ingress(groups["alb"], "tcp", 80, cidr="10.88.0.0/16")
    for port in [27015, 27022]:
        ingress(groups["nlb"], "udp", port, cidr="0.0.0.0/0")
        ingress(groups["game"], "udp", port, source_group=groups["nlb"])
    cache_secret, cache_password = secret_arn("cache", prefix)
    jwt_secret, _ = secret_arn("jwt", prefix)
    server_secret, _ = secret_arn("server", prefix)
    rds = aws("rds")
    ensure("db_subnets", lambda: rds.create_db_subnet_group(DBSubnetGroupName=prefix,
        DBSubnetGroupDescription="Private game database", SubnetIds=subnets["data"], Tags=tags())["DBSubnetGroup"]["DBSubnetGroupName"])
    ensure("db_parameters", lambda: rds.create_db_parameter_group(DBParameterGroupName=prefix,
        DBParameterGroupFamily="postgres16", Description="TLS required", Tags=tags())["DBParameterGroup"]["DBParameterGroupName"])
    rds.modify_db_parameter_group(DBParameterGroupName=prefix,
        Parameters=[{"ParameterName": "rds.force_ssl", "ParameterValue": "1", "ApplyMethod": "pending-reboot"}])
    db_id = ensure("db", lambda: rds.create_db_instance(
        DBInstanceIdentifier=prefix, DBInstanceClass="db.t4g.small", Engine="postgres", EngineVersion="16.15",
        DBName="iron", MasterUsername="ironapp", ManageMasterUserPassword=True,
        AllocatedStorage=20, MaxAllocatedStorage=100, StorageType="gp3", StorageEncrypted=True,
        MultiAZ=True, PubliclyAccessible=False, DBSubnetGroupName=prefix,
        DBParameterGroupName=prefix, VpcSecurityGroupIds=[groups["db"]],
        BackupRetentionPeriod=7, DeletionProtection=True, Tags=tags())["DBInstance"]["DBInstanceIdentifier"])
    elasticache = aws("elasticache")
    ensure("cache_subnets", lambda: elasticache.create_cache_subnet_group(CacheSubnetGroupName=prefix,
        CacheSubnetGroupDescription="Private room leases", SubnetIds=subnets["data"])["CacheSubnetGroup"]["CacheSubnetGroupName"])
    cache_id = ensure("cache", lambda: elasticache.create_replication_group(
        ReplicationGroupId=prefix, ReplicationGroupDescription="Iron Meridian private cache",
        Engine="redis", EngineVersion="7.1", CacheNodeType="cache.t4g.micro", NumCacheClusters=1,
        AutomaticFailoverEnabled=False, AtRestEncryptionEnabled=True, TransitEncryptionEnabled=True,
        AuthToken=cache_password, CacheSubnetGroupName=prefix, SecurityGroupIds=[groups["cache"]],
        Tags=tags())["ReplicationGroup"]["ReplicationGroupId"])
    api_image, game_image = image("api", account), image("game", account)
    logs = aws("logs")
    if not state.get("logs"):
        logs.create_log_group(logGroupName="/iron-meridian/" + prefix, tags={x["Key"]: x["Value"] for x in tags()})
        logs.put_retention_policy(logGroupName="/iron-meridian/" + prefix, retentionInDays=30)
        save("logs", "/iron-meridian/" + prefix)
    cluster = ensure("cluster", lambda: aws("ecs").create_cluster(clusterName=prefix,
        tags=[{"key": x["Key"], "value": x["Value"]} for x in tags()])["cluster"]["clusterArn"])
    discovery = aws("servicediscovery")
    operation = ensure("namespace_operation", lambda: discovery.create_private_dns_namespace(
        Name=prefix + ".internal", Vpc=vpc, CreatorRequestId=prefix, Tags=tags())["OperationId"])
    namespace = ensure("namespace", lambda: wait("Private DNS", lambda: discovery.get_operation(OperationId=operation)["Operation"],
        lambda x: x["Status"] == "SUCCESS", 600)["Targets"]["NAMESPACE"])
    registry = ensure("api_registry", lambda: discovery.create_service(Name="api", NamespaceId=namespace,
        DnsConfig={"NamespaceId": namespace, "RoutingPolicy": "MULTIVALUE", "DnsRecords": [{"Type": "A", "TTL": 10}]},
        HealthCheckCustomConfig={"FailureThreshold": 1}, Tags=tags())["Service"]["Arn"])
    efs = aws("efs")
    filesystem = ensure("efs", lambda: efs.create_file_system(CreationToken=prefix, Encrypted=True,
        PerformanceMode="generalPurpose", ThroughputMode="bursting", Tags=tags())["FileSystemId"])
    wait("EFS", lambda: efs.describe_file_systems(FileSystemId=filesystem)["FileSystems"][0],
         lambda x: x["LifeCycleState"] == "available", 300)
    access_points = {}
    for i, subnet in enumerate(subnets["data"]):
        ensure("efs_mount_" + str(i), lambda subnet=subnet: efs.create_mount_target(
            FileSystemId=filesystem, SubnetId=subnet, SecurityGroups=[groups["efs"]])["MountTargetId"])
    for mode in ["solo", "duo"]:
        access_points[mode] = ensure("efs_access_" + mode, lambda mode=mode: efs.create_access_point(
            ClientToken=prefix + mode, FileSystemId=filesystem, PosixUser={"Uid": 10001, "Gid": 10001},
            RootDirectory={"Path": "/" + mode, "CreationInfo": {"OwnerUid": 10001, "OwnerGid": 10001, "Permissions": "750"}},
            Tags=tags())["AccessPointId"])
    loadbalancers = aws("elbv2")
    alb = ensure("alb", lambda: loadbalancers.create_load_balancer(Name=prefix + "-api", Subnets=subnets["app"],
        SecurityGroups=[groups["alb"]], Scheme="internal", Type="application", Tags=tags())["LoadBalancers"][0])
    nlb = ensure("nlb", lambda: loadbalancers.create_load_balancer(Name=prefix + "-game", Subnets=subnets["public"],
        SecurityGroups=[groups["nlb"]], Scheme="internet-facing", Type="network", Tags=tags())["LoadBalancers"][0])
    loadbalancers.modify_load_balancer_attributes(LoadBalancerArn=nlb["LoadBalancerArn"],
        Attributes=[{"Key": "load_balancing.cross_zone.enabled", "Value": "true"}])
    targets = {}
    for name, port, proto, health_port in [("api", 8000, "HTTP", "traffic-port"),
                                          ("solo", 27015, "UDP", "8765"), ("duo", 27022, "UDP", "8765")]:
        targets[name] = ensure("target_" + name, lambda name=name, port=port, proto=proto, health_port=health_port:
            loadbalancers.create_target_group(Name=prefix + "-" + name, VpcId=vpc, TargetType="ip",
                Protocol=proto, Port=port, HealthCheckProtocol="HTTP", HealthCheckPort=health_port,
                HealthCheckPath="/health", HealthCheckIntervalSeconds=15, HealthyThresholdCount=2, Tags=tags())["TargetGroups"][0]["TargetGroupArn"])
        loadbalancers.modify_target_group_attributes(TargetGroupArn=targets[name],
            Attributes=[{"Key": "deregistration_delay.timeout_seconds", "Value": "10"}])
        ensure("listener_" + name, lambda name=name, port=port, proto=proto: loadbalancers.create_listener(
            LoadBalancerArn=(alb if name == "api" else nlb)["LoadBalancerArn"], Port=80 if name == "api" else port,
            Protocol=proto, DefaultActions=[{"Type": "forward", "TargetGroupArn": targets[name]}])["Listeners"][0]["ListenerArn"])
    ensure("private_routes_rule", lambda: loadbalancers.create_rule(ListenerArn=state["listener_api"], Priority=1,
        Conditions=[{"Field": "path-pattern", "Values": ["/internal/*", "/docs*", "/redoc*", "/openapi.json"]}],
        Actions=[{"Type": "fixed-response", "FixedResponseConfig": {
            "StatusCode": "404", "ContentType": "application/json", "MessageBody": '{"detail":"Not found"}'}}])["Rules"][0]["RuleArn"])
    wait("Internal ALB", lambda: loadbalancers.describe_load_balancers(LoadBalancerArns=[alb["LoadBalancerArn"]])["LoadBalancers"][0],
         lambda x: x["State"]["Code"] == "active", 600)
    download_bucket = ensure("download_bucket", lambda: bucket("iron-meridian-downloads-" + account + "-" + state["run"]))
    backup_bucket = ensure("backup_bucket", lambda: bucket("iron-meridian-data-" + account + "-" + state["run"]))
    raw = (ROOT / "artifacts/aws-migration.json").read_bytes()
    snapshot_hash = hashlib.sha256(raw).hexdigest()
    snapshot_key = "migration/" + snapshot_hash + ".json"
    aws("s3").put_object(Bucket=backup_bucket, Key=snapshot_key, Body=raw, ContentType="application/json")
    cf = aws("cloudfront")
    oac = ensure("oac", lambda: cf.create_origin_access_control(OriginAccessControlConfig={
        "Name": prefix, "SigningProtocol": "sigv4", "SigningBehavior": "always",
        "OriginAccessControlOriginType": "s3"})["OriginAccessControl"]["Id"])
    origin = ensure("vpc_origin", lambda: cf.create_vpc_origin(VpcOriginEndpointConfig={
        "Name": prefix, "Arn": alb["LoadBalancerArn"], "HTTPPort": 80, "HTTPSPort": 443,
        "OriginProtocolPolicy": "http-only", "OriginSslProtocols": {"Quantity": 1, "Items": ["TLSv1.2"]}})["VpcOrigin"]["Id"])
    wait("CloudFront private origin", lambda: cf.get_vpc_origin(Id=origin)["VpcOrigin"],
         lambda x: x["Status"] == "Deployed", 1200)
    origin_groups = ec2.describe_security_groups(Filters=[
        {"Name": "vpc-id", "Values": [vpc]},
        {"Name": "group-name", "Values": ["CloudFront-VPCOrigins-Service-SG"]},
    ])["SecurityGroups"]
    assert len(origin_groups) == 1, "Expected the CloudFront VPC origin service security group"
    ingress(groups["alb"], "tcp", 80, source_group=origin_groups[0]["GroupId"])
    ec2.revoke_security_group_ingress(GroupId=groups["alb"], IpPermissions=[{
        "IpProtocol": "tcp", "FromPort": 80, "ToPort": 80,
        "IpRanges": [{"CidrIp": "10.88.0.0/16"}],
    }])
    if "function_arn" not in state:
        function = cf.create_function(Name=prefix, FunctionConfig={"Comment": "Public JSON API allowlist; no login pages",
                    "Runtime": "cloudfront-js-2.0"}, FunctionCode=(ROOT / "infra/aws/public_api.js").read_bytes())
        cf.publish_function(Name=prefix, IfMatch=function["ETag"])
        save("function_arn", function["FunctionSummary"]["FunctionMetadata"]["FunctionARN"])
    cache_policies = {x["CachePolicy"]["CachePolicyConfig"]["Name"]: x["CachePolicy"]["Id"]
                      for x in cf.list_cache_policies(Type="managed")["CachePolicyList"]["Items"]}
    request_policies = {x["OriginRequestPolicy"]["OriginRequestPolicyConfig"]["Name"]: x["OriginRequestPolicy"]["Id"]
                        for x in cf.list_origin_request_policies(Type="managed")["OriginRequestPolicyList"]["Items"]}
    common = {"Compress": True, "TrustedSigners": {"Enabled": False, "Quantity": 0}}
    distribution = ensure("distribution", lambda: cf.create_distribution(DistributionConfig={
        "CallerReference": prefix, "Comment": "Iron Meridian downloads and private API; no web login",
        "Enabled": True, "DefaultRootObject": "index.html", "HttpVersion": "http2", "IsIPV6Enabled": True,
        "Origins": {"Quantity": 2, "Items": [
            {"Id": "downloads", "DomainName": download_bucket + ".s3.us-east-1.amazonaws.com",
             "OriginAccessControlId": oac, "S3OriginConfig": {"OriginAccessIdentity": ""}},
            {"Id": "api", "DomainName": alb["DNSName"], "VpcOriginConfig": {"VpcOriginId": origin,
             "OriginReadTimeout": 30, "OriginKeepaliveTimeout": 5}}]},
        "DefaultCacheBehavior": {**common, "TargetOriginId": "downloads", "ViewerProtocolPolicy": "redirect-to-https",
             "CachePolicyId": cache_policies["Managed-CachingOptimized"],
             "AllowedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}}},
        "CacheBehaviors": {"Quantity": 1, "Items": [{**common, "PathPattern": "api/*", "TargetOriginId": "api",
             "ViewerProtocolPolicy": "https-only", "CachePolicyId": cache_policies["Managed-CachingDisabled"],
             "OriginRequestPolicyId": request_policies["Managed-AllViewerExceptHostHeader"],
             "AllowedMethods": {"Quantity": 7, "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
                                "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}},
             "FunctionAssociations": {"Quantity": 1, "Items": [{"FunctionARN": state["function_arn"], "EventType": "viewer-request"}]}}]},
        "ViewerCertificate": {"CloudFrontDefaultCertificate": True},
    })["Distribution"])
    domain = "https://" + distribution["DomainName"]
    aws("s3").put_bucket_policy(Bucket=download_bucket, Policy=json.dumps({"Version": "2012-10-17", "Statement": [
        {"Effect": "Allow", "Principal": {"Service": "cloudfront.amazonaws.com"}, "Action": "s3:GetObject",
         "Resource": f"arn:aws:s3:::{download_bucket}/*",
         "Condition": {"StringEquals": {"AWS:SourceArn": distribution["ARN"], "AWS:SourceAccount": account}}},
        {"Effect": "Deny", "Principal": "*", "Action": "s3:*",
         "Resource": [f"arn:aws:s3:::{download_bucket}", f"arn:aws:s3:::{download_bucket}/*"],
         "Condition": {"Bool": {"aws:SecureTransport": "false"}}}]}))
    for file, content_type in [("index.html", "text/html; charset=utf-8"), ("style.css", "text/css"), ("site.js", "application/javascript")]:
        aws("s3").put_object(Bucket=download_bucket, Key=file, Body=(ROOT / "infra/aws/site" / file).read_bytes(),
                            ContentType=content_type, CacheControl="no-cache")
    aws("s3").put_object(Bucket=download_bucket, Key="config.json", Body=json.dumps({"api": domain + "/api"}).encode(),
                        ContentType="application/json", CacheControl="no-store")
    archive = ROOT / "artifacts/IronMeridian-Linux-x86_64.tar.gz"
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == "e2a94bca580253e22f4df38d9fc3ec145d4d8fc139e874ece5aa9297212bcb69"
    aws("s3").upload_file(str(archive), download_bucket, "downloads/" + archive.name,
                         ExtraArgs={"ContentType": "application/gzip", "CacheControl": "public,max-age=31536000,immutable"})
    aws("s3").upload_file(str(windows_archive), download_bucket, "downloads/" + windows_archive.name,
                         ExtraArgs={"ContentType": "application/zip", "CacheControl": "no-cache"})
    db = wait("PostgreSQL", lambda: rds.describe_db_instances(DBInstanceIdentifier=db_id)["DBInstances"][0],
              lambda x: x["DBInstanceStatus"] == "available")
    redis = wait("Redis", lambda: elasticache.describe_replication_groups(ReplicationGroupId=cache_id)["ReplicationGroups"][0],
                 lambda x: x["Status"] == "available")
    execution = ensure("execution_role", lambda: iam_role(prefix + "-execution", "ecs-tasks.amazonaws.com"))
    api_role = ensure("api_role", lambda: iam_role(prefix + "-api", "ecs-tasks.amazonaws.com"))
    game_role = ensure("game_role", lambda: iam_role(prefix + "-game", "ecs-tasks.amazonaws.com"))
    aws("iam").attach_role_policy(RoleName=execution.rsplit("/", 1)[-1],
        PolicyArn="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy")
    db_secret = db["MasterUserSecret"]["SecretArn"]
    policy(execution, "RuntimeSecrets", [{"Effect": "Allow", "Action": "secretsmanager:GetSecretValue",
        "Resource": [db_secret, cache_secret, jwt_secret, server_secret]}])
    policy(api_role, "PrivateDataImport", [{"Effect": "Allow", "Action": "s3:GetObject",
        "Resource": f"arn:aws:s3:::{backup_bucket}/{snapshot_key}"}])
    policy(game_role, "PersistentResults", [{"Effect": "Allow", "Action": ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"],
        "Resource": f"arn:aws:elasticfilesystem:{REGION}:{account}:file-system/{filesystem}"}])
    efs.put_file_system_policy(FileSystemId=filesystem, Policy=json.dumps({"Version": "2012-10-17", "Statement": [
        {"Effect": "Deny", "Principal": "*", "Action": "*", "Resource": "*",
         "Condition": {"Bool": {"aws:SecureTransport": "false"}}}]}))
    def log_options(name):
        return {"logDriver": "awslogs", "options": {"awslogs-group": state["logs"], "awslogs-region": REGION, "awslogs-stream-prefix": name}}
    def secret(name, arn):
        return {"name": name, "valueFrom": arn}
    api_task = ensure("api_task", lambda: aws("ecs").register_task_definition(
        family=prefix + "-api", requiresCompatibilities=["FARGATE"], networkMode="awsvpc",
        cpu="512", memory="1024", executionRoleArn=execution, taskRoleArn=api_role,
        containerDefinitions=[{"name": "api", "image": api_image, "essential": True,
            "portMappings": [{"containerPort": 8000}], "logConfiguration": log_options("api"),
            "environment": [{"name": k, "value": v} for k, v in {
                "DB_HOST": db["Endpoint"]["Address"], "CACHE_HOST": redis["NodeGroups"][0]["PrimaryEndpoint"]["Address"],
                "DATA_SNAPSHOT_BUCKET": backup_bucket, "DATA_SNAPSHOT_KEY": snapshot_key, "DATA_SNAPSHOT_SHA256": snapshot_hash}.items()],
            "secrets": [secret("DB_PASSWORD", db_secret + ":password::"), secret("CACHE_PASSWORD", cache_secret),
                        secret("JWT_SECRET", jwt_secret), secret("SERVER_SECRET", server_secret)],
            "healthCheck": {"command": ["CMD-SHELL", "python -c \"import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=3)\""],
                            "interval": 15, "timeout": 5, "retries": 5, "startPeriod": 60}}])["taskDefinition"]["taskDefinitionArn"])
    network = lambda group: {"awsvpcConfiguration": {"subnets": subnets["app"], "securityGroups": [group], "assignPublicIp": "DISABLED"}}
    ensure("api_service", lambda: aws("ecs").create_service(cluster=cluster, serviceName="api", taskDefinition=api_task,
        desiredCount=1, launchType="FARGATE", networkConfiguration=network(groups["api"]),
        loadBalancers=[{"targetGroupArn": targets["api"], "containerName": "api", "containerPort": 8000}],
        serviceRegistries=[{"registryArn": registry}], healthCheckGracePeriodSeconds=120,
        deploymentConfiguration={"minimumHealthyPercent": 100, "maximumPercent": 200})["service"]["serviceArn"])
    wait("API service", lambda: aws("ecs").describe_services(cluster=cluster, services=["api"])["services"][0],
         lambda x: x["runningCount"] == 1 and x["deployments"][0].get("rolloutState") == "COMPLETED", 1200)
    if not state.get("data_imported"):
        task = ensure("import_task", lambda: aws("ecs").run_task(cluster=cluster, taskDefinition=api_task,
            launchType="FARGATE", networkConfiguration=network(groups["api"]),
            overrides={"containerOverrides": [{"name": "api", "command": ["python", "/app/migrate_data.py"]}]})["tasks"][0]["taskArn"])
        result = wait("Data import", lambda: aws("ecs").describe_tasks(cluster=cluster, tasks=[task])["tasks"][0],
                      lambda x: x["lastStatus"] == "STOPPED", 600)
        assert result["containers"][0].get("exitCode") == 0, "Data import failed; inspect its private log"
        save("data_imported", True)
    for mode, port in [("solo", 27015), ("duo", 27022)]:
        task = ensure(mode + "_task", lambda mode=mode, port=port: aws("ecs").register_task_definition(
            family=prefix + "-" + mode, requiresCompatibilities=["FARGATE"], networkMode="awsvpc",
            cpu="1024", memory="2048", executionRoleArn=execution, taskRoleArn=game_role,
            volumes=[{"name": "data", "efsVolumeConfiguration": {"fileSystemId": filesystem, "transitEncryption": "ENABLED",
                "authorizationConfig": {"accessPointId": access_points[mode], "iam": "ENABLED"}}}],
            containerDefinitions=[{"name": "game", "image": game_image, "essential": True, "stopTimeout": 60,
                "portMappings": [{"containerPort": port, "protocol": "udp"}, {"containerPort": 8765}],
                "mountPoints": [{"sourceVolume": "data", "containerPath": "/home/game/.local/share/godot/app_userdata", "readOnly": False}],
                "logConfiguration": log_options(mode), "secrets": [secret("SERVER_SECRET", server_secret)],
                "environment": [{"name": k, "value": v} for k, v in {
                    "API_URL": "http://api." + prefix + ".internal:8000", "GAME_PUBLIC_HOST": nlb["DNSName"],
                    "GAME_MODE": mode, "GAME_PORT": str(port)}.items()],
                "healthCheck": {"command": ["CMD-SHELL", "python3 -c \"import urllib.request;urllib.request.urlopen('http://127.0.0.1:8765/health',timeout=3)\""],
                                "interval": 15, "timeout": 5, "retries": 5, "startPeriod": 60}}])["taskDefinition"]["taskDefinitionArn"])
        ensure(mode + "_service", lambda mode=mode, port=port, task=task: aws("ecs").create_service(
            cluster=cluster, serviceName=mode, taskDefinition=task, desiredCount=1, launchType="FARGATE",
            networkConfiguration=network(groups["game"]), healthCheckGracePeriodSeconds=180,
            loadBalancers=[{"targetGroupArn": targets[mode], "containerName": "game", "containerPort": port}],
            deploymentConfiguration={"minimumHealthyPercent": 0, "maximumPercent": 100})["service"]["serviceArn"])
    for name in ["solo", "duo"]:
        wait(name + " service", lambda name=name: aws("ecs").describe_services(cluster=cluster, services=[name])["services"][0],
             lambda x: x["runningCount"] == 1 and x["deployments"][0].get("rolloutState") == "COMPLETED", 1200)
    wait("CloudFront", lambda: cf.get_distribution(Id=distribution["Id"])["Distribution"],
         lambda x: x["Status"] == "Deployed", 1200)
    outputs = {"Website": domain, "ApiUrl": domain + "/api", "DownloadUrl": domain + "/downloads/" + archive.name,
        "GameHost": nlb["DNSName"], "ClusterName": cluster, "DownloadsBucket": download_bucket, "VpcId": vpc,
        "LogGroup": state["logs"], "ApiServiceName": "api", "soloServiceName": "solo", "duoServiceName": "duo"}
    private_write(ROOT / "infra/aws/deployment-outputs.json", {"IronMeridian": outputs})
    save("status", "deployed")
    print("AWS_DIRECT_DEPLOYED " + json.dumps(outputs), flush=True)


if __name__ == "__main__":
    main()
