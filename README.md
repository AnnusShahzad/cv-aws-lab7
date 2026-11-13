# Lab 7 - Host Your CV on AWS

**Name:** Muhammad Annus Shahzad  
**Roll No:** 23L_3004  
**EC2 address:** http://13.232.87.45  
**Lambda address:** https://qw7x2k9p4m6n3b8v5c1z0l2a4s6.lambda-url.ap-southeast-1.on.aws/

My CV lives in one private S3 bucket (`cv-23l-3004`) and is served twice: by Apache on an EC2 instance and by a Python Lambda function.

## Architecture

```
                    +-------------------------------+
                    |  S3 bucket cv-23l-3004        |
                    |  private, versioned           |
                    |  site/index.html              |
                    |  site/style.css               |
                    |  site/cv.pdf                  |
                    +-----+-----------------+-------+
                          |                 |
                 GetObject|ListBucket   GetObject
                (EC2 role) |                 | (Lambda role)
                          |                 |
          HTTP :80         |                 |  HTTPS function URL
                          v                 v
                    +-----------+   +------------------+
                    | EC2+httpd |   | Lambda function  |
                    | sync every|   | auth NONE        |
                    | 2 min     |   +------------------+
                    +-----------+
                          ^
                          | direct S3 URL -> 403 Access Denied
```

- **Path A (EC2):** the visitor opens the instance's public IPv4 on port 80 and Apache serves the files that `sync-cv.sh` copied from `s3://cv-23l-3004/site/` with the instance role, rewriting `{{HOSTED_ON}}` to `EC2 i-0f8e7d6c5b4a39281`. The sync runs every 2 minutes, so a change in S3 shows up on the site within a few minutes without anyone logging in.
- **Path B (Lambda):** the visitor opens the HTTPS function URL and the function reads the requested object from S3 with its own role, rewriting `{{HOSTED_ON}}` to `Lambda cv-func-23l-3004`, and returns it (the PDF base64-encoded). The URL is public and needs no signature, so the visitor's browser can call it directly.

## Access denied from the instance (section 4)

```
$ aws s3 rm s3://cv-23l-3004/site/index.html
An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied

$ echo test > /tmp/x && aws s3 cp /tmp/x s3://cv-23l-3004/site/index.html
upload failed: /tmp/x to s3://cv-23l-3004/site/index.html An error occurred (AccessDenied) when calling the PutObject operation: Access Denied
```

## Last 10 lines of /var/log/cv-sync.log

```
2026-11-13T17:28:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:30:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:32:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:34:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:36:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:38:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:40:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:42:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:44:00Z sync OK instance=i-0f8e7d6c5b4a39281
2026-11-13T17:46:00Z sync OK instance=i-0f8e7d6c5b4a39281
```

## Written answers

**1. Why roles instead of access keys? What could go wrong with keys in user data?**
A role gives the instance or function temporary credentials that AWS creates, delivers and rotates automatically, so nothing secret is stored anywhere. User data can be read by anyone who can log in to the instance or describe it, it is kept with the instance configuration, and it is easy to copy into a public repository. A leaked access key does not expire and works from anywhere until someone notices and deactivates it, so a stranger could read or delete my bucket.

**2. Someone pastes the S3 address of index.html into a browser. What do they see, and which setting causes that?**
They see an XML "Access Denied" (HTTP 403) page and not my CV. This is caused by the bucket setting Block Public Access (all four options on), together with the fact that the bucket has no public policy or ACL, so only the two IAM roles may read the objects.

**3. Explain the permission on the function URL that lets anyone call it. Why is that acceptable for the function but not for the bucket?**
With auth type NONE, Lambda adds a resource-based policy statement to the function that allows principal `*` to perform `lambda:InvokeFunctionUrl`, so no AWS signature is needed to call the URL. This is acceptable because the function is a controlled front door: the visitor can only ask for the three paths my code knows, and the code decides what is returned. Making the bucket public would give the whole internet direct access to every object and its settings instead of going through my code, which is why the bucket stays private.

**4. Compare the two paths. What do you pay for when nobody visits the site? What happens if the traffic grows a hundred times?**
When nobody visits, EC2 still costs money for the running instance, its EBS volume and its public IPv4 address, while Lambda costs almost nothing because I pay only per request and per millisecond of run time (plus tiny log storage). If traffic grows a hundred times, one small EC2 instance would become slow or fall over unless I add a bigger instance, auto scaling and a load balancer. Lambda scales out automatically within the account concurrency limit, and the cost grows roughly in line with the number of requests.

**5. You delete the EC2 instance. What do you lose and what do you still have?**
I lose the instance, its root volume, its public IP address (so the EC2 address stops working and a new instance gets a new one) and the local file `/var/log/cv-sync.log`. I still have the S3 bucket with all its versions, both IAM roles, the Lambda site, the security group and the repository, so I can launch a new instance from `ec2/user-data.sh` and have the site back within a few minutes.


